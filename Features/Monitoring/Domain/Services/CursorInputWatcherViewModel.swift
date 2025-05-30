import AppKit
import AXorcist
@preconcurrency import Combine
import Defaults
import Diagnostics
@preconcurrency import Foundation
import SwiftUI

/// Central coordinator for Cursor input monitoring and JavaScript hook management.
///
/// CursorInputWatcherViewModel serves as the primary ViewModel for monitoring functionality:
/// - Orchestrates JavaScript hook injection and management across Cursor windows
/// - Coordinates with port management for WebSocket connection allocation
/// - Manages heartbeat monitoring to ensure hook responsiveness
/// - Integrates with AI analysis for window state detection
/// - Provides UI state management for monitoring views and debugging
/// - Handles query execution and response processing
///
/// This ViewModel acts as the central nervous system for CodeLooper's monitoring
/// capabilities, coordinating between multiple services to provide comprehensive
/// Cursor supervision and automated intervention.
@MainActor
class CursorInputWatcherViewModel: ObservableObject, Loggable {
    // MARK: Lifecycle

    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") {
        self.projectRoot = projectRoot
        self.queryManager = QueryManager(projectRoot: projectRoot)
        self.jsHookService = JSHookService.shared
        self.portManager = PortManager()
        self.heartbeatMonitor = HeartbeatMonitor()
        self.aiAnalyzer = AIWindowAnalyzer()

        queryManager.loadAndParseAllQueries()
        // Port mappings are handled automatically by the new ConnectionManager
        setupWindowsSubscription()
        heartbeatMonitor.delegate = self
        heartbeatMonitor.setupHeartbeatListener()

        // Observe Defaults[.isGlobalMonitoringEnabled] to start/stop JS hooks
        Defaults.publisher(.isGlobalMonitoringEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                if change.newValue {
                    self.logger.info("Global monitoring enabled.")
                } else {
                    self.logger.info("Global monitoring disabled. Stopping all JS Hooks.")
                    self.jsHookService.stopAllHooks()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        timerSubscription?.cancel()
        windowsSubscription?.cancel()
        // heartbeatMonitor will be cleaned up by ARC
    }

    // MARK: Internal

    @Published var watchedInputs: [WatchedInputInfo] = [
        WatchedInputInfo(id: "main-ai-slash-input", name: "AI Slash Input", queryFile: "query_cursor_input.json"),
        WatchedInputInfo(id: "sidebar-text-area", name: "Sidebar Text Content", queryFile: "query_cursor_sidebar.json"),
    ]
    @Published var statusMessage: String = "Watcher is disabled."
    @Published var cursorWindows: [MonitoredWindowInfo] = []
    @Published var windowHeartbeatStatus: [String: HeartbeatStatus] = [:]
    @Published var windowAIAnalysis: [String: WindowAIStatus] = [:]

    // MARK: - Injection State

    @Published var windowInjectionStates: [String: InjectionState] = [:]

    let jsHookService: JSHookService

    var hookedWindows: Set<String> {
        Set(cursorWindows.compactMap { window in
            jsHookService.isWindowHooked(window.id) ? window.id : nil
        })
    }

    var isWatchingEnabled: Bool {
        Defaults[.isGlobalMonitoringEnabled]
    }

    // MARK: - View Lifecycle

    func handleViewAppear() {
        logger.info("CursorInputWatcher view appeared - refreshing connection states")
        // Refresh UI state to match actual connection status
        Task {
            // Update window list
            await updateWindows()

            // Refresh hook statuses for all windows
            for window in cursorWindows {
                if jsHookService.isWindowHooked(window.id) {
                    windowInjectionStates[window.id] = .hooked

                    // Ensure heartbeat monitor knows about this window
                    if let port = jsHookService.getPort(for: window.id) {
                        heartbeatMonitor.registerWindowPort(window.id, port: port)
                    }
                } else {
                    windowInjectionStates[window.id] = .idle
                }
            }

            updateHookStatuses()
            updateWatcherStatus()
        }
    }

    func handleViewDisappear() {
        logger.info("CursorInputWatcher view disappearing - connections persist via singleton")
        // Connections are maintained by the singleton JSHookService
        // No cleanup needed here
    }

    // MARK: - JS Hook Management

    func injectJSHook(into window: MonitoredWindowInfo) async {
        let windowId = window.id

        // Check if already hooked
        if jsHookService.isWindowHooked(windowId) {
            windowInjectionStates[windowId] = .hooked
            return
        }

        // Check if already working on this window
        if windowInjectionStates[windowId]?.isWorking == true {
            logger.warning("Already working on window \(windowId), skipping")
            return
        }

        logger.info("🔨 Starting injection process for window: \(window.windowTitle ?? "Unknown")")

        // Start with probing state
        windowInjectionStates[windowId] = .probing

        // Check if hook already exists (managed by connection manager)
        if jsHookService.isWindowHooked(windowId) {
            logger.info("✅ Hook already exists for window: \(windowId)")
            windowInjectionStates[windowId] = .hooked
            updateWatcherStatus()
            return
        }

        // Move to injection state
        windowInjectionStates[windowId] = .injecting

        // Perform actual injection
        do {
            try await jsHookService.installHook(for: window)
            logger.info("✅ Successfully injected hook for window: \(windowId)")
            windowInjectionStates[windowId] = .hooked

            // Register the window port with HeartbeatMonitor
            if let port = jsHookService.getPort(for: windowId) {
                heartbeatMonitor.registerWindowPort(windowId, port: port)
                logger.debug("Registered window \(windowId) with heartbeat monitor on port \(port)")
            }

            // Force UI update by triggering objectWillChange
            Task { @MainActor in
                self.objectWillChange.send()
            }
        } catch {
            logger.error("❌ Failed to inject hook for window \(windowId): \(error)")
            windowInjectionStates[windowId] = .failed(error.localizedDescription)
        }

        updateWatcherStatus()
    }

    func getInjectionState(for windowId: String) -> InjectionState {
        if jsHookService.isWindowHooked(windowId) {
            return .hooked
        }
        return windowInjectionStates[windowId] ?? .idle
    }

    func checkHookStatus(for window: MonitoredWindowInfo) -> Bool {
        jsHookService.isWindowHooked(window.id)
    }

    func getPort(for windowId: String) -> UInt16? {
        // First check if we have a hook with a port from ConnectionManager
        if let port = jsHookService.getPort(for: windowId) {
            return port
        }
        // Fallback to old port manager (for backward compatibility)
        return portManager.getPort(for: windowId)
    }

    // MARK: - Query Management

    func queryInputText(forInputIndex index: Int) {
        guard index < watchedInputs.count else { return }

        Task {
            let inputInfo = watchedInputs[index]
            guard let queryData = validateAndGetQueryData(for: inputInfo, at: index) else { return }
            await performQuery(queryData: queryData, inputInfo: inputInfo, index: index)
        }
    }

    // MARK: - AI Analysis

    func analyzeWindowWithAI(window: MonitoredWindowInfo) async {
        await aiAnalyzer.analyzeWindow(window) { [weak self] windowId, status in
            self?.windowAIAnalysis[windowId] = status
        }
    }

    func getWindowAIStatus(for windowId: String) -> WindowAIStatus? {
        windowAIAnalysis[windowId]
    }

    // MARK: - Heartbeat Status

    func getHeartbeatStatus(for windowId: String) -> HeartbeatStatus? {
        windowHeartbeatStatus[windowId]
    }

    // MARK: Private

    private let projectRoot: String
    private let queryManager: QueryManager
    private let portManager: PortManager
    private let heartbeatMonitor: HeartbeatMonitor
    private let aiAnalyzer: AIWindowAnalyzer

    private var timerSubscription: AnyCancellable?
    private var windowsSubscription: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Window Management

    private func updateWindows() async {
        // Force refresh of window list from CursorMonitor
        let apps = CursorMonitor.shared.monitoredApps
        let allWindows = apps.flatMap(\.windows)
        self.cursorWindows = allWindows

        // Let JSHookCoordinator know about current windows
        await jsHookService.updateWindows(allWindows)
    }

    private func setupWindowsSubscription() {
        windowsSubscription = CursorMonitor.shared.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                let allWindows = apps.flatMap(\.windows)
                let previousWindowIds = Set(self.cursorWindows.map(\.id))
                let currentWindowIds = Set(allWindows.map(\.id))
                let newWindows = allWindows.filter { !previousWindowIds.contains($0.id) }
                let removedWindowIds = previousWindowIds.subtracting(currentWindowIds)

                self.cursorWindows = allWindows
                self.updateHookStatuses()

                // Clean up injection states for removed windows
                for removedId in removedWindowIds {
                    self.windowInjectionStates.removeValue(forKey: removedId)
                    // Unregister port from heartbeat monitor
                    if let port = self.getPort(for: removedId) {
                        self.heartbeatMonitor.unregisterWindowPort(port)
                    }
                }

                // Handle new windows with fast probing
                for newWindow in newWindows {
                    self.logger
                        .info("📝 New window detected: '\(newWindow.windowTitle ?? "Unknown")' - starting fast probe")
                    self.windowInjectionStates[newWindow.id] = .probing
                    Task { await self.jsHookService.updateWindows([newWindow]) }

                    // Check probe results after a short delay
                    Task {
                        try? await Task.sleep(for: .seconds(TimingConfiguration.probeDelay))
                        if self.jsHookService.isWindowHooked(newWindow.id) {
                            self.windowInjectionStates[newWindow.id] = .hooked
                        } else {
                            self.windowInjectionStates[newWindow.id] = .idle
                        }
                    }
                }

                self.updateWatcherStatus()
            }
    }

    private func startWatching() {
        guard timerSubscription == nil else { return }

        logger.info("Starting input watcher")
        statusMessage = "Watching for input changes..."

        queryInputText(forInputIndex: 0)
        queryInputText(forInputIndex: 1)

        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.queryInputText(forInputIndex: 0)
                self?.queryInputText(forInputIndex: 1)
            }
    }

    private func stopWatching() {
        logger.info("Stopping input watcher")
        timerSubscription?.cancel()
        timerSubscription = nil
        statusMessage = "Watcher is disabled."
    }

    private func updateWatcherStatus() {
        if isWatchingEnabled {
            if timerSubscription == nil {
                startWatching()
            }
        } else {
            stopWatching()
        }
    }

    private func updateHookStatuses() {
        for window in cursorWindows {
            if jsHookService.isWindowHooked(window.id) {
                let port = getPort(for: window.id) ?? 0
                watchedInputs[0].lastValue = "✅ Hooked (Port: \(port))"

                // Register the window port with HeartbeatMonitor if not already registered
                if port > 0 {
                    heartbeatMonitor.registerWindowPort(window.id, port: port)
                }

                // Update injection state to reflect current hook status
                if case .hooked = windowInjectionStates[window.id] {
                    // Already hooked, no change needed
                } else {
                    windowInjectionStates[window.id] = .hooked
                }
            } else {
                // If hook is no longer present, reset injection state
                if case .hooked = windowInjectionStates[window.id] {
                    windowInjectionStates[window.id] = .idle
                }
            }
        }

        // Trigger UI update
        objectWillChange.send()
    }

    // Query-related methods
    private func validateAndGetQueryData(for inputInfo: WatchedInputInfo, at _: Int) -> QueryData? {
        // For now, return a stub query data
        // swiftlint:disable:next todo
        // TODO: Implement proper query loading from JSON files
        QueryData(
            name: inputInfo.queryFile,
            command: "query",
            params: QueryParams(includeAttributes: nil, excludeAttributes: nil, maxDepth: nil),
            response: ResponseConfig(attributes: [AttributeConfig(name: "AXValue", type: "string")])
        )
    }

    private func performQuery(queryData: QueryData, inputInfo: WatchedInputInfo, index: Int) async {
        guard !cursorWindows.isEmpty else {
            watchedInputs[index].lastValue = "No Cursor windows found"
            return
        }

        // Use first window for query
        // swiftlint:disable:next todo
        // TODO: Implement proper window selection
        // swiftlint:disable:next todo
        // TODO: Implement actual query execution
        let response = HandlerResponse.success(data: nil)
        await processQueryResponse(response, queryData: queryData, inputInfo: inputInfo, at: index)
    }

    private func processQueryResponse(
        _ response: HandlerResponse,
        queryData: QueryData,
        inputInfo: WatchedInputInfo,
        at index: Int
    ) async {
        if let error = response.error {
            handleQueryError(error, inputInfo: inputInfo, queryFile: queryData.name, index: index)
        } else if let data = response.data {
            await processSuccessfulResponse(data, queryData: queryData, inputInfo: inputInfo, at: index)
        }
    }

    private func processSuccessfulResponse(
        _ data: AnyCodable,
        queryData: QueryData,
        inputInfo: WatchedInputInfo,
        at index: Int
    ) async {
        // Extract elements from AnyCodable if possible
        if let elementsData = data.value as? [[String: Any]] {
            let extractedTexts = extractTextFromRawElements(elementsData, queryData: queryData)
            let displayText = extractedTexts.joined(separator: " | ")
            watchedInputs[index].lastValue = displayText.isEmpty ? inputInfo.emptyValue : displayText
        } else {
            handleEmptyResponse(inputInfo: inputInfo, queryFile: queryData.name, index: index)
        }
    }

    private func extractTextFromRawElements(_ elementsData: [[String: Any]], queryData: QueryData) -> [String] {
        var texts: [String] = []
        for elementData in elementsData {
            for attribute in queryData.response.attributes {
                if let value = elementData[attribute.name] as? String, !value.isEmpty {
                    texts.append(value)
                    break
                }
            }
        }
        return texts
    }

    private func handleQueryError(_ errorMsg: String, inputInfo _: WatchedInputInfo, queryFile: String, index: Int) {
        logger.error("Query '\(queryFile)' error: \(errorMsg)")
        watchedInputs[index].lastValue = "Error: \(errorMsg)"
    }

    private func handleEmptyResponse(inputInfo: WatchedInputInfo, queryFile: String, index: Int) {
        logger.debug("Query '\(queryFile)' returned empty result")
        watchedInputs[index].lastValue = inputInfo.emptyValue
    }
}

// MARK: - HeartbeatMonitorDelegate

extension CursorInputWatcherViewModel: HeartbeatMonitorDelegate {
    nonisolated func heartbeatMonitor(
        _: HeartbeatMonitor,
        didUpdateStatus status: HeartbeatStatus,
        for windowId: String
    ) {
        Task { @MainActor in
            windowHeartbeatStatus[windowId] = status
        }
    }
}

// MARK: - Data Models

enum InjectionState: Equatable {
    case idle
    case probing
    case injecting
    case hooked
    case failed(String)

    // MARK: Internal

    var displayText: String {
        switch self {
        case .idle:
            "Ready"
        case .probing:
            "Probing..."
        case .injecting:
            "Injecting..."
        case .hooked:
            "Hooked"
        case let .failed(error):
            "Failed: \(error)"
        }
    }

    var isWorking: Bool {
        switch self {
        case .probing, .injecting:
            true
        default:
            false
        }
    }
}

struct WatchedInputInfo: Identifiable {
    let id: String
    let name: String
    let queryFile: String
    var lastValue: String = "Not found"
    var lastUpdate: Date = .init()

    var emptyValue: String {
        switch id {
        case "main-ai-slash-input":
            "Empty"
        case "sidebar-text-area":
            "No content"
        default:
            "—"
        }
    }
}

struct HeartbeatStatus {
    var lastHeartbeat: Date?
    var isAlive: Bool = false
    var resumeNeeded: Bool = false
    var hookVersion: String?
    var location: String?
}

struct WindowAIStatus {
    var isAnalyzing: Bool = false
    var lastAnalysis: Date?
    var status: String?
    var error: String?
}
