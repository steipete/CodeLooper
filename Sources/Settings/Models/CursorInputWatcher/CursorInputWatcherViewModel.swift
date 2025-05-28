import AppKit
import AXorcist
@preconcurrency import Combine
import Defaults
import Diagnostics
@preconcurrency import Foundation
import SwiftUI

@MainActor
class CursorInputWatcherViewModel: ObservableObject {
    // MARK: Lifecycle

    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") {
        self.projectRoot = projectRoot
        self.queryManager = QueryManager(projectRoot: projectRoot)
        self.jsHookManager = JSHookService()
        self.portManager = PortManager()
        self.heartbeatMonitor = HeartbeatMonitor()
        self.aiAnalyzer = AIWindowAnalyzer()

        queryManager.loadAndParseAllQueries()
        jsHookManager.loadPortMappings()
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
                    self.jsHookManager.stopAllHooks()
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
    @Published var isInjectingHook: Bool = false
    @Published var windowHeartbeatStatus: [String: HeartbeatStatus] = [:]
    @Published var windowAIAnalysis: [String: WindowAIStatus] = [:]

    var hookedWindows: Set<String> {
        jsHookManager.hookedWindows
    }

    var isWatchingEnabled: Bool {
        Defaults[.isGlobalMonitoringEnabled]
    }

    // MARK: - JS Hook Management

    func injectJSHook(into window: MonitoredWindowInfo) async {
        guard !isInjectingHook else {
            logger.warning("Already injecting hook, skipping")
            return
        }

        isInjectingHook = true
        defer { isInjectingHook = false }

        await jsHookManager.injectHook(into: window, portManager: portManager)
        updateWatcherStatus()
    }

    func checkHookStatus(for window: MonitoredWindowInfo) -> Bool {
        jsHookManager.isWindowHooked(window.id)
    }

    func getPort(for windowId: String) -> UInt16? {
        portManager.getPort(for: windowId)
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
    private let jsHookManager: JSHookService
    private let portManager: PortManager
    private let heartbeatMonitor: HeartbeatMonitor
    private let aiAnalyzer: AIWindowAnalyzer
    private let logger = Logger(category: .supervision)

    private var timerSubscription: AnyCancellable?
    private var windowsSubscription: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private func setupWindowsSubscription() {
        windowsSubscription = CursorMonitor.shared.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                let allWindows = apps.flatMap(\.windows)
                self.cursorWindows = allWindows
                self.updateHookStatuses()

                Task {
                    for window in allWindows where !self.jsHookManager.isWindowHooked(window.id) {
                        if await self.jsHookManager.checkForExistingHook(in: window, portManager: self.portManager) {
                            self.logger.info("Found existing hook for window: \(window.id)")
                        }
                    }
                    self.updateWatcherStatus()
                }
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
            if jsHookManager.isWindowHooked(window.id) {
                let port = portManager.getPort(for: window.id) ?? 0
                watchedInputs[0].lastValue = "✅ Hooked (Port: \(port))"
            }
        }
    }

    // Query-related methods
    private func validateAndGetQueryData(for inputInfo: WatchedInputInfo, at _: Int) -> QueryData? {
        // For now, return a stub query data
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

        // Use first window for query - TODO: Implement proper window selection
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
