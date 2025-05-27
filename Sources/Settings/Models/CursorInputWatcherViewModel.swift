// swiftlint:disable file_length

import AppKit
import AXorcist // Import AXorcist module
@preconcurrency import Combine
import Defaults
import Diagnostics
@preconcurrency import Foundation
import Security
import SwiftUI

// MARK: - axorc Output Structures (Element is provided by AXorcist, so these might be simplified or removed)

// We'll rely on AXorcist.Element for success cases.
// Error handling will be based on HandlerResponse.error.

@MainActor
// swiftlint:disable:next type_body_length
class CursorInputWatcherViewModel: ObservableObject {
    // MARK: Lifecycle

    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") { // Default for dev
        self.projectRoot = projectRoot
        self.queryManager = QueryManager(projectRoot: projectRoot)
        self.jsHookManager = JSHookManager()

        queryManager.loadAndParseAllQueries()
        jsHookManager.loadPortMappings()
        setupWindowsSubscription()
        setupHeartbeatListener()

        // Port probing for pre-existing windows now happens automatically
        // when windows are first detected in setupWindowsSubscription()
    }

    deinit {
        // Cancel subscriptions - these are fine since they're non-isolated
        timerSubscription?.cancel()
        windowsSubscription?.cancel()
        heartbeatListenerTask?.cancel()
        // JS hooks cleanup handled by ARC when jsHookManager is deallocated
    }

    // MARK: Internal

    @Published var watchedInputs: [CursorWindowInfo] = [
        CursorWindowInfo(id: "main-ai-slash-input", name: "AI Slash Input", queryFile: "query_cursor_input.json"),
        CursorWindowInfo(id: "sidebar-text-area", name: "Sidebar Text Content", queryFile: "query_cursor_sidebar.json"),
    ]
    @Published var statusMessage: String = "Watcher is disabled."
    @Published var cursorWindows: [MonitoredWindowInfo] = []
    @Published var isInjectingHook: Bool = false // Track injection state
    @Published var windowHeartbeatStatus: [String: HeartbeatStatus] = [:] // Track heartbeat status per window
    @Published var windowAIAnalysis: [String: AIAnalysisStatus] = [:] // Track AI analysis status per window

    var hookedWindows: Set<String> {
        jsHookManager.hookedWindows
    }
    
    struct HeartbeatStatus {
        var lastHeartbeat: Date?
        var isAlive: Bool = false
        var resumeNeeded: Bool = false
        var hookVersion: String?
        var location: String?
    }
    
    struct AIAnalysisStatus {
        var isAnalyzing: Bool = false
        var lastAnalysis: Date?
        var status: String?
        var error: String?
    }

    @Published var isWatchingEnabled: Bool = false {
        didSet {
            if isWatchingEnabled {
                startWatching()
            } else {
                stopWatching()
            }
        }
    }

    // MARK: - JS Hook Management

    func injectJSHook(into window: MonitoredWindowInfo) async {
        isInjectingHook = true
        defer { isInjectingHook = false }

        statusMessage = "Probing for existing hook in \(window.windowTitle ?? "window")..."

        // Check if hook already exists
        if await checkForExistingHook(in: window) {
            return
        }

        // No existing hook found, inject a new one
        await installNewHook(in: window)
    }

    func checkHookStatus(for window: MonitoredWindowInfo) -> Bool {
        guard let hook = jsHookManager.jsHooks[window.id] else { return false }
        return hook.isHooked
    }

    func getPort(for windowId: String) -> UInt16? {
        jsHookManager.windowPorts[windowId]
    }

    // MARK: Private

    // Temporary struct to match the JSON query file structure for decoding
    private struct RawQueryFile: Codable {
        // MARK: Internal

        let applicationIdentifier: String
        let locator: RawLocator

        // MARK: Private

        // swiftlint:disable:next nesting
        private enum CodingKeys: String, CodingKey {
            case applicationIdentifier = "application_identifier"
            case locator
        }
    }

    private struct RawLocator: Codable {
        // MARK: Internal

        let criteria: [String: String] // Key might be "attributeName_matchType" or just "attributeName"
        let rootElementPathHint: [RawPathHintComponent]?
        // descendant_criteria and descendant_criteria_exclusions are not directly used by AXorcist.Locator
        // but could be used to build more complex queries if needed in the future.
        // let descendant_criteria: [String: String]?
        // let descendant_criteria_exclusions: [String: String]?
        let attributesToFetch: [String]
        let maxDepthForSearch: Int?
        let requireAction: Bool?

        // MARK: Private

        // swiftlint:disable:next nesting
        private enum CodingKeys: String, CodingKey {
            case criteria
            case rootElementPathHint = "root_element_path_hint"
            case attributesToFetch = "attributes_to_fetch"
            case maxDepthForSearch = "max_depth_for_search"
            case requireAction = "require_action"
        }
    }

    private struct RawPathHintComponent: Codable {
        // MARK: Internal

        // This struct should represent one segment of the path hint as defined in the JSON.
        // It typically has an attribute and a value to match for that segment.
        // For example: { "attribute": "AXRole", "value": "AXWebArea" }
        // Or it could be more complex if the JSON defines criteria within a path hint component.
        // For simplicity, assuming simple attribute-value pairs for now.
        // If JSON has {"criteria": {"AXRole": "AXWebArea"}, "depth": 1}, then that structure needs to be mirrored.
        // Current `JSONPathHintComponent` takes `attribute: String, value: String, depth: Int?, matchType: MatchType`

        let attribute: String // The AX attribute to match for this path segment (e.g., "AXRole")
        let value: String // The value the attribute should have (e.g., "AXWebArea")
        let depth: Int? // Optional depth for this specific hint component
        let matchType: String? // Optional match type string (e.g., "contains", "exact")

        // MARK: Private

        // swiftlint:disable:next nesting
        private enum CodingKeys: String, CodingKey {
            case attribute, value, depth
            case matchType = "match_type"
        }
    }

    private struct QueryData {
        let queryFile: String
        let appIdentifier: String
        let locator: Locator
        let attributesToFetch: [String]
        let maxDepth: Int
    }

    private struct BrowserInfo: Codable {
        let userAgent: String
        let platform: String
        let language: String
        let onLine: Bool
        let cookieEnabled: Bool
        let windowLocation: String
        let timestamp: String
    }

    // MARK: - Managers

    private let queryManager: QueryManager
    private let jsHookManager: JSHookManager

    private var timerSubscription: AnyCancellable?
    private let axorcist = AXorcist() // AXorcist instance
    private let projectRoot: String
    private let cursorMonitor = CursorMonitor.shared
    private var windowsSubscription: AnyCancellable?
    private var heartbeatListenerTask: Task<Void, Never>?

    private func checkForExistingHook(in window: MonitoredWindowInfo) async -> Bool {
        // Try to probe using the existing port for this window
        if let existingPort = jsHookManager.windowPorts[window.id] {
            if await probePort(existingPort, for: window) {
                return true
            }
        }

        // Try common ports in parallel
        return await probeCommonPorts(for: window)
    }

    private func probeCommonPorts(for window: MonitoredWindowInfo) async -> Bool {
        let portsToProbe: [UInt16] = Array(stride(from: 9001, to: 9011, by: 1))
        let probeResults = await withTaskGroup(of: (UInt16, Bool).self) { group in
            for port in portsToProbe {
                group.addTask {
                    let result = await self.probePort(port, for: window)
                    return (port, result)
                }
            }

            var results: [(UInt16, Bool)] = []
            for await result in group {
                results.append(result)
                if result.1 { // If probe was successful
                    group.cancelAll() // Cancel remaining probes
                    return results
                }
            }
            return results
        }

        return probeResults.contains(where: \.1)
    }

    private func installNewHook(in window: MonitoredWindowInfo) async {
        do {
            let port = getOrAssignPort(for: window.id)
            statusMessage = "Installing CodeLooper hook on port \(port)..."

            // Create and install hook
            let hook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                targetWindowTitle: window.windowTitle
            )

            // Store the hook
            jsHookManager.jsHooks[window.id] = hook
            jsHookManager.addHookedWindow(window.id)

            // Test the hook and verify browser info
            let testResult = try await testHookConnection(hook, window: window, port: port)

            if testResult != nil {
                await showConnectionConfirmation(hook, port: port)
            }

            jsHookManager.savePortMappings()
        } catch {
            handleHookInstallationError(error, for: window)
        }
    }

    private func testHookConnection(
        _ hook: CursorJSHook,
        window: MonitoredWindowInfo,
        port: UInt16
    ) async throws -> BrowserInfo?
    {
        // Use the new command-based approach
        let testResult = try await hook.getSystemInfo()
        Logger(category: .settings)
            .info("JS Hook installed for window \(window.windowTitle ?? "Unknown") on port \(port)")

        // Parse and display browser info
        guard let data = testResult.data(using: .utf8),
              let browserInfo = try? JSONDecoder().decode(BrowserInfo.self, from: data)
        else {
            statusMessage = "JS Hook installed on port \(port) (sanity check: \(testResult.prefix(50))...)"
            return nil
        }

        Logger(category: .settings)
            .info("Browser info - UserAgent: \(browserInfo.userAgent), Location: \(browserInfo.windowLocation)")

        // Verify this is actually a Cursor instance
        guard browserInfo.windowLocation.contains("Cursor.app") else {
            Logger(category: .settings)
                .warning("Hook connected but not to Cursor app. Location: \(browserInfo.windowLocation)")
            statusMessage = "Warning: Connected to non-Cursor window on port \(port)"
            return nil
        }

        // Update status with Chrome version if available
        updateStatusWithChromeVersion(browserInfo.userAgent, port: port)
        return browserInfo
    }

    private func updateStatusWithChromeVersion(_ userAgent: String, port: UInt16) {
        if let chromeRange = userAgent.range(of: "Chrome/[0-9.]+", options: .regularExpression),
           let versionRange = userAgent[chromeRange].range(of: "[0-9.]+", options: .regularExpression)
        {
            let chromeVersion = String(userAgent[chromeRange][versionRange])
            statusMessage = "Connected to Cursor (Chrome \(chromeVersion)) on port \(port)"
        } else {
            statusMessage = "Connected to Cursor on port \(port)"
        }
    }

    private func showConnectionConfirmation(_ hook: CursorJSHook, port: UInt16) async {
        try? await Task.sleep(for: .seconds(2))

        // Use the new showNotification command instead of raw JS
        let message = "👋 Hi from CodeLooper!\n\nThis JS is running via our tunnel on port \(port).\n\nYou can now use CodeLooper to monitor and interact with Cursor."
        
        if let notificationResult = try? await hook.showNotification(
            message,
            showToast: true,
            duration: 5000,
            browserNotification: true,
            title: "CodeLooper Connected! 🎉"
        ) {
            Logger(category: .settings)
                .info("Showed connection confirmation: \(notificationResult)")
        }
    }

    private func handleHookInstallationError(_ error: Error, for window: MonitoredWindowInfo) {
        Logger(category: .settings)
            .error(
                "Failed to inject JS hook into window \(window.windowTitle ?? "Unknown"): \(error.localizedDescription)"
            )

        // Check for port in use error
        if case let CursorJSHook.HookError.portInUse(port) = error {
            Logger(category: .settings)
                .error("Port \(port) is already in use. Trying alternative port...")
            statusMessage = "Port \(port) in use, retrying with different port..."

            // Clean up and retry with a different port
            jsHookManager.windowPorts.removeValue(forKey: window.id)
            jsHookManager.incrementPort() // Skip to next port

            // Retry installation with new port
            Task {
                await installNewHook(in: window)
            }
            return
        }

        // Extract and log underlying error
        let nsError = extractNSError(from: error)
        if let nsError {
            Logger(category: .settings)
                .error("JS Hook injection error code: \(nsError.code), domain: \(nsError.domain)")
            handleSpecificError(nsError)
        } else {
            statusMessage = "Failed to inject JS hook: \(error.localizedDescription)"
        }

        // Clean up failed hook
        jsHookManager.removeHookedWindow(window.id)
        jsHookManager.jsHooks.removeValue(forKey: window.id)
        jsHookManager.windowPorts.removeValue(forKey: window.id)
    }

    private func extractNSError(from error: Error) -> NSError? {
        if case let CursorJSHook.HookError.injectionFailed(innerError) = error,
           let nsError = innerError as NSError?
        {
            return nsError
        }
        return error as NSError?
    }

    private func handleSpecificError(_ nsError: NSError) {
        switch nsError.code {
        case -1743:
            statusMessage =
                "Automation permission denied. Grant permission in System Settings > Privacy & Security > Automation"
            Task { @MainActor in
                showAutomationPermissionAlert()
            }
        case -600:
            statusMessage = "Cursor is not running. Please start Cursor first."
        case -10004:
            statusMessage = "Privilege violation. Check accessibility permissions."
        default:
            statusMessage = "Failed: \(nsError.localizedDescription)"
        }
    }

    private func setupWindowsSubscription() {
        windowsSubscription = cursorMonitor.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                let previousWindowCount = self.cursorWindows.count
                if let cursorApp = apps.first {
                    self.cursorWindows = cursorApp.windows
                } else {
                    self.cursorWindows = []
                }

                // If we just got windows for the first time (startup case), probe for existing hooks
                if previousWindowCount == 0, !self.cursorWindows.isEmpty {
                    Task {
                        await self.probeAllWindowsForExistingHooks()
                    }
                }

                // For new windows that appear during runtime, we can optimize by not probing
                // since they likely don't have hooks yet
                if previousWindowCount > 0, self.cursorWindows.count > previousWindowCount {
                    // New windows detected during runtime - these are fresh and won't have hooks
                    Logger(category: .settings).info("New windows detected during runtime, skipping probe")
                }
            }
    }

    private func startWatching() {
        guard !watchedInputs.isEmpty else {
            statusMessage = "No inputs configured to watch."
            isWatchingEnabled = false
            return
        }
        statusMessage = "Watcher enabled. Starting..."

        // Initial query for all inputs
        for i in watchedInputs.indices {
            queryInputText(forInputIndex: i)
        }

        // Setup timer
        timerSubscription = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.isWatchingEnabled else { return }
            for i in self.watchedInputs.indices {
                self.queryInputText(forInputIndex: i)
            }
            // Also check hook statuses periodically
            self.updateHookStatuses()
        }
        if let firstInputName = watchedInputs.first?.name {
            statusMessage = "Watching input(s) including: \(firstInputName)"
        } else {
            statusMessage = "Watching enabled."
        }
    }

    // UI updates are dispatched to MainActor.
    private func stopWatching() {
        // Access to timerSubscription needs to be safe from a nonisolated context.
        // If timerSubscription is itself guarded by an actor, or if its methods are thread-safe.
        // Assuming AnyCancellable.cancel() is thread-safe, and assignment to an optional is atomic enough.
        timerSubscription?.cancel()
        timerSubscription = nil

        // If statusMessage needs update, it must be dispatched to MainActor.
        // For deinit, usually we don't update UI state that might not exist anymore.
        // Task { @MainActor {
        //     self.statusMessage = "Watcher stopped."
        // }}
    }

    private func queryInputText(forInputIndex index: Int) {
        guard index < watchedInputs.count else { return }

        let inputInfo = watchedInputs[index]
        guard let queryData = validateAndGetQueryData(for: inputInfo, at: index) else {
            return
        }

        Task {
            await performQuery(queryData: queryData, inputInfo: inputInfo, index: index)
        }
    }

    private func validateAndGetQueryData(for inputInfo: CursorWindowInfo, at index: Int) -> QueryData? {
        guard let currentQueryFile = inputInfo.queryFile,
              let appIdentifier = queryManager.queryAppIdentifiers[currentQueryFile],
              let locator = queryManager.parsedQueries[currentQueryFile],
              let attributesToFetch = queryManager.queryAttributes[currentQueryFile]
        else {
            let errorMsg = "Query not loaded, parsed, or appID missing for \(inputInfo.name). " +
                "QueryFile: \(inputInfo.queryFile ?? "nil")"
            self.watchedInputs[index].lastError = errorMsg
            self.statusMessage = "Configuration error for \(inputInfo.name)."
            Logger(category: .settings)
                .error(
                    "Missing parsed query for \(inputInfo.queryFile ?? "<unknown file>") for input \(inputInfo.name): \(errorMsg)"
                )
            return nil
        }

        let maxDepth = queryManager.queryMaxDepth[currentQueryFile] ?? AXMiscConstants.defaultMaxDepthSearch
        return QueryData(
            queryFile: currentQueryFile,
            appIdentifier: appIdentifier,
            locator: locator,
            attributesToFetch: attributesToFetch,
            maxDepth: maxDepth
        )
    }

    private func performQuery(queryData: QueryData, inputInfo: CursorWindowInfo, index: Int) async {
        let queryCommand = QueryCommand(
            appIdentifier: queryData.appIdentifier,
            locator: queryData.locator,
            attributesToReturn: queryData.attributesToFetch,
            maxDepthForSearch: queryData.maxDepth
        )

        let response = axorcist.handleQuery(command: queryCommand, maxDepth: queryData.maxDepth)

        await MainActor.run {
            processQueryResponse(response, queryData: queryData, inputInfo: inputInfo, index: index)
        }
    }

    private func processQueryResponse(
        _ response: AXResponse,
        queryData: QueryData,
        inputInfo: CursorWindowInfo,
        index: Int
    ) {
        switch response {
        case let .error(message, code, _):
            handleQueryError(
                "\(code.rawValue): \(message)",
                inputInfo: inputInfo,
                queryFile: queryData.queryFile,
                index: index
            )
        case let .success(payload, _):
            if let responseData = payload {
                processSuccessfulResponse(responseData, queryData: queryData, inputInfo: inputInfo, index: index)
            } else {
                handleEmptyResponse(inputInfo: inputInfo, queryFile: queryData.queryFile, index: index)
            }
        }

        updateWatcherStatus()
    }

    private func handleQueryError(_ errorMsg: String, inputInfo: CursorWindowInfo, queryFile: String, index: Int) {
        self.watchedInputs[index].lastError = "AXorcist Error: \(errorMsg)"
        self.statusMessage = "Error querying \(inputInfo.name)."
        Logger(category: .accessibility)
            .error("AXorcist error for \(inputInfo.name) (query: \(queryFile)): \(errorMsg)")
    }

    private func processSuccessfulResponse(
        _ responseData: AnyCodable,
        queryData: QueryData,
        inputInfo: CursorWindowInfo,
        index: Int
    ) {
        let foundElements = extractElements(
            from: responseData,
            inputInfo: inputInfo,
            queryFile: queryData.queryFile,
            index: index
        )

        guard !foundElements.isEmpty else {
            self.watchedInputs[index].lastError = "No elements found by AXorcist."
            Logger(category: .accessibility)
                .info("No elements found for \(inputInfo.name) (query: \(queryData.queryFile))")
            return
        }

        let foundText = extractTextFromElement(
            foundElements[0],
            attributesToFetch: queryData.attributesToFetch,
            inputInfo: inputInfo
        )
        self.watchedInputs[index].lastKnownText = foundText ?? "<No text extractable>"
        self.watchedInputs[index].lastError = nil

        Logger(category: .accessibility)
            .info("Successfully queried \(inputInfo.name) (query: \(queryData.queryFile)): \(foundText ?? "<nil>")")

        if foundElements.count > 1 {
            Logger(category: .accessibility)
                .info("""
                Query for \(inputInfo.name) (query: \(queryData.queryFile)) returned \(foundElements.count) elements. \
                Processed the first.
                """)
        }
    }

    private func extractElements(
        from responseData: AnyCodable,
        inputInfo: CursorWindowInfo,
        queryFile: String,
        index: Int
    ) -> [Element] {
        if let singleElement = responseData.value as? Element {
            return [singleElement]
        } else if let multipleElements = responseData.value as? [Element] {
            return multipleElements
        } else {
            let desc = String(describing: responseData.value)
            let typeStr = String(describing: type(of: responseData.value))
            let descStr = String(desc.prefix(200))
            Logger(category: .accessibility)
                .warning("""
                AXorcist response data for \(inputInfo.name) (query: \(queryFile)) was not Element/[Element]. \
                Type: \(typeStr), Desc: \(descStr)
                """)
            self.watchedInputs[index].lastError = "Unexpected data format from AXorcist."
            self.statusMessage = "Format error for \(inputInfo.name)."
            return []
        }
    }

    private func extractTextFromElement(
        _ element: Element,
        attributesToFetch: [String],
        inputInfo: CursorWindowInfo
    ) -> String? {
        guard let attributes = element.attributes else { return nil }

        // Try AXValue first
        if let value = attributes[AXAttributeNames.kAXValueAttribute]?.value as? String {
            return value
        }

        // Try first requested attribute
        guard let firstRequestedAttrKey = attributesToFetch.first,
              let attrValueAny = attributes[firstRequestedAttrKey]?.value
        else {
            let attrName = attributesToFetch.first ?? "N/A"
            let elementDesc = element.briefDescription(option: .stringified)
            Logger(category: .accessibility)
                .warning(
                    "Could not extract text attribute (\(attrName)) for \(inputInfo.name). Element: \(elementDesc)"
                )
            return "<\(attributesToFetch.first ?? "Attribute") not string or found>"
        }

        if let strValue = attrValueAny as? String {
            return strValue
        } else {
            let foundText = String(describing: attrValueAny)
            Logger(category: .accessibility)
                .info(
                    "Attribute \(firstRequestedAttrKey) for \(inputInfo.name) was not String, using description: \(foundText)"
                )
            return foundText
        }
    }

    private func handleEmptyResponse(inputInfo: CursorWindowInfo, queryFile: String, index: Int) {
        self.watchedInputs[index].lastError = "AXorcist returned no data and no error."
        Logger(category: .accessibility)
            .warning("AXorcist returned no data and no error for \(inputInfo.name) (query: \(queryFile)).")
    }

    private func updateWatcherStatus() {
        if self.isWatchingEnabled {
            let activeErrorCount = self.watchedInputs.count { $0.lastError != nil }
            if activeErrorCount > 0 {
                self.statusMessage = "Watcher active with \(activeErrorCount) error(s)."
            } else {
                self.statusMessage = "Watcher active. All inputs OK."
            }
        }
    }

    // Periodically check hook status and update UI
    private func updateHookStatuses() {
        for windowId in jsHookManager.hookedWindows {
            if let window = cursorWindows.first(where: { $0.id == windowId }),
               let hook = jsHookManager.jsHooks[windowId]
            {
                // Check if we're still receiving heartbeats
                let heartbeatStatus = windowHeartbeatStatus[windowId]
                let hasRecentHeartbeat = heartbeatStatus?.lastHeartbeat.map { Date().timeIntervalSince($0) < 10 } ?? false
                
                if !hook.isHooked && !hasRecentHeartbeat {
                    // Hook was lost and no recent heartbeats, remove it
                    jsHookManager.removeHookedWindow(windowId)
                    jsHookManager.jsHooks.removeValue(forKey: windowId)
                    Logger(category: .settings)
                        .warning("JS Hook lost for window \(window.windowTitle ?? "Unknown") - no heartbeat")
                } else if !hook.isHooked && hasRecentHeartbeat {
                    // WebSocket disconnected but still receiving heartbeats
                    Logger(category: .settings)
                        .info("JS Hook WebSocket disconnected but still receiving heartbeats for window \(window.windowTitle ?? "Unknown")")
                }
            }
        }
    }

    // MARK: - Port Management

    private func getOrAssignPort(for windowId: String) -> UInt16 {
        if let existingPort = jsHookManager.windowPorts[windowId] {
            return existingPort
        }

        // Find next available port
        while jsHookManager.windowPorts.values.contains(jsHookManager.nextPort) {
            jsHookManager.incrementPort()
        }

        let assignedPort = jsHookManager.nextPort
        jsHookManager.windowPorts[windowId] = assignedPort
        jsHookManager.incrementPort()

        return assignedPort
    }

    private func probePort(_ port: UInt16, for window: MonitoredWindowInfo) async -> Bool {
        // First, let's check if there's already a hook in the browser without starting a listener
        if let existingPort = await checkForExistingHookInBrowser(window: window), existingPort == port {
            return await tryConnectToExistingHook(port: port, window: window)
        }

        // No existing hook found in browser, try the normal probe
        return await probeForHookConnection(port: port, window: window)
    }

    private func tryConnectToExistingHook(port: UInt16, window: MonitoredWindowInfo) async -> Bool {
        do {
            let probeHook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                skipInjection: true,
                targetWindowTitle: window.windowTitle
            )

            if await probeHook.probeForExistingHook(timeout: 2.0) {
                // Successfully connected to existing hook
                jsHookManager.jsHooks[window.id] = probeHook
                jsHookManager.addHookedWindow(window.id)
                jsHookManager.windowPorts[window.id] = port

                Logger(category: .settings)
                    .info("Successfully connected to existing hook on port \(port)")

                return true
            }
        } catch {
            // Port might be in use by something else
            Logger(category: .settings)
                .debug("Failed to connect to port \(port): \(error)")
        }
        return false
    }

    private func probeForHookConnection(port: UInt16, window: MonitoredWindowInfo) async -> Bool {
        do {
            // Create a hook in probe mode (no injection)
            let probeHook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                skipInjection: true,
                targetWindowTitle: window.windowTitle
            )

            // Wait for existing hook to connect (longer timeout since we probe in parallel)
            if await probeHook.probeForExistingHook(timeout: 2.0) {
                // Hook exists! Store it
                jsHookManager.jsHooks[window.id] = probeHook
                jsHookManager.addHookedWindow(window.id)
                jsHookManager.windowPorts[window.id] = port

                // Verify it's a valid Cursor hook
                if await verifyHookIsForCursor(probeHook, window: window, port: port) {
                    await showReconnectionMessage(probeHook, port: port)
                    return true
                }
                return false
            }
        } catch {
            // Failed to create probe hook
            Logger(category: .settings)
                .debug("Failed to probe port \(port): \(error)")
        }
        return false
    }

    private func verifyHookIsForCursor(_ hook: CursorJSHook, window: MonitoredWindowInfo, port: UInt16) async -> Bool {
        // Test the existing hook with browser info check
        // Use the new command-based approach to verify the hook
        guard let testResult = try? await hook.getSystemInfo(),
              let data = testResult.data(using: .utf8),
              let browserInfo = try? JSONDecoder().decode(BrowserInfo.self, from: data)
        else {
            return false
        }

        // Verify this is actually a Cursor instance
        guard browserInfo.windowLocation.contains("Cursor.app") else {
            Logger(category: .settings)
                .warning("Found hook but not for Cursor app. Location: \(browserInfo.windowLocation)")
            return false // Not a valid Cursor hook
        }

        Logger(category: .settings)
            .info(
                "Found existing JS Hook for Cursor window \(window.windowTitle ?? "Unknown") on port \(port)"
            )

        // Update status with Chrome version
        updateStatusWithChromeVersion(browserInfo.userAgent, port: port)
        return true
    }

    private func showReconnectionMessage(_ hook: CursorJSHook, port: UInt16) async {
        statusMessage = "Reconnected to Cursor on port \(port)"

        // Show a reconnection message
        try? await Task.sleep(for: .seconds(1))

        // Use the new notification command
        let message = "🔄 CodeLooper Reconnected!\n\nFound existing JS tunnel on port \(port)."
        
        if let result = try? await hook.showNotification(
            message,
            showToast: true,
            duration: 4000,
            browserNotification: false
        ) {
            Logger(category: .settings)
                .info("Showed reconnection confirmation: \(result)")
        }
    }

    // MARK: - Persistence

    private func probeAllWindowsForExistingHooks() async {
        statusMessage = "Probing for existing hooks..."

        // Filter windows that need probing
        let windowsToProbe = cursorWindows.filter { window in
            !jsHookManager.hookedWindows.contains(window.id) && jsHookManager.windowPorts[window.id] != nil
        }

        // Probe all windows in parallel
        await withTaskGroup(of: Void.self) { group in
            for window in windowsToProbe {
                if let existingPort = jsHookManager.windowPorts[window.id] {
                    group.addTask {
                        _ = await self.probePort(existingPort, for: window)
                    }
                }
            }
        }

        if jsHookManager.hookedWindows.isEmpty {
            statusMessage = "No existing hooks found"
        } else {
            statusMessage = "Found \(jsHookManager.hookedWindows.count) existing hook(s)"
        }
    }

    private func checkForExistingHookInBrowser(window _: MonitoredWindowInfo) async -> UInt16? {
        // Currently we can't easily check for existing hooks via AppleScript
        // The hook will auto-reconnect if CodeLooper restarts within the reconnect window
        nil
    }

    private func showAutomationPermissionAlert() {
        // Ensure the app is active before showing the alert
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Automation Permission Required"
        alert.informativeText = "CodeLooper needs permission to control Cursor via automation.\n\n" +
            "Please grant permission in System Settings > Privacy & Security > Automation, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        // Find the key window to attach the alert to
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Open System Settings to the Automation pane
                    if let url =
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            // Fallback to modal if no window is available
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to the Automation pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    // MARK: - Heartbeat Monitoring
    
    private func setupHeartbeatListener() {
        heartbeatListenerTask = Task { [weak self] in
            await self?.startHeartbeatMonitoring()
        }
    }
    
    private func startHeartbeatMonitoring() async {
        // Set up notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("CursorHeartbeat"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let port = userInfo["port"] as? UInt16,
                      let location = userInfo["location"] as? String,
                      let version = userInfo["version"] as? String,
                      let resumeNeeded = userInfo["resumeNeeded"] as? Bool else {
                    return
                }
                
                // Find window ID by port
                if let windowId = self.jsHookManager.windowPorts.first(where: { $0.value == port })?.key {
                    self.updateHeartbeatStatus(
                        for: windowId,
                        resumeNeeded: resumeNeeded,
                        location: location,
                        hookVersion: version
                    )
                }
            }
        }
        
        // Keep task alive until cancelled
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
        }
        
        // Clean up when done
        await MainActor.run {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateHeartbeatStatus(
        for windowId: String,
        resumeNeeded: Bool,
        location: String? = nil,
        hookVersion: String? = nil
    ) {
        var status = windowHeartbeatStatus[windowId] ?? HeartbeatStatus()
        status.lastHeartbeat = Date()
        status.isAlive = true
        status.resumeNeeded = resumeNeeded
        if let location = location {
            status.location = location
        }
        if let hookVersion = hookVersion {
            status.hookVersion = hookVersion
        }
        windowHeartbeatStatus[windowId] = status
        
        // Mark stale heartbeats after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            if let lastHeartbeat = windowHeartbeatStatus[windowId]?.lastHeartbeat,
               Date().timeIntervalSince(lastHeartbeat) >= 5 {
                windowHeartbeatStatus[windowId]?.isAlive = false
            }
        }
    }
    
    func getHeartbeatStatus(for windowId: String) -> HeartbeatStatus? {
        windowHeartbeatStatus[windowId]
    }
    
    func getAIAnalysisStatus(for windowId: String) -> AIAnalysisStatus? {
        windowAIAnalysis[windowId]
    }
    
    // MARK: - AI Analysis
    
    func analyzeWindowWithAI(window: MonitoredWindowInfo) async {
        // Set analyzing state
        windowAIAnalysis[window.id] = AIAnalysisStatus(isAnalyzing: true)
        
        do {
            // Take screenshot
            guard let screenshot = captureWindowScreenshot(window: window) else {
                throw NSError(domain: "Screenshot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screenshot"])
            }
            
            // Save screenshot temporarily
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cursor_window_\(window.id).png")
            guard let tiffData = screenshot.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "Screenshot", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert screenshot to PNG"])
            }
            try pngData.write(to: tempURL)
            
            // Analyze with AI
            let analysisResult = await analyzeScreenshotWithAI(screenshotPath: tempURL.path)
            
            // Update status
            windowAIAnalysis[window.id] = AIAnalysisStatus(
                isAnalyzing: false,
                lastAnalysis: Date(),
                status: analysisResult,
                error: nil
            )
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
        } catch {
            windowAIAnalysis[window.id] = AIAnalysisStatus(
                isAnalyzing: false,
                lastAnalysis: Date(),
                status: nil,
                error: error.localizedDescription
            )
        }
    }
    
    @MainActor
    private func captureWindowScreenshot(window: MonitoredWindowInfo) -> NSImage? {
        guard let axElement = window.windowAXElement else { return nil }
        
        // Get window bounds
        guard let position = axElement.position(),
              let size = axElement.size() else { return nil }
        
        let windowRect = CGRect(
            x: CGFloat(position.x),
            y: CGFloat(position.y),
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
        
        // Capture the window area
        // Use .optionOnScreenAboveWindow to capture everything in the rect
        guard let screenshot = CGWindowListCreateImage(
            windowRect,
            .optionOnScreenAboveWindow,
            CGWindowID(0), // 0 means capture all windows
            .bestResolution
        ) else { return nil }
        
        return NSImage(cgImage: screenshot, size: windowRect.size)
    }
    
    private func analyzeScreenshotWithAI(screenshotPath: String) async -> String {
        do {
            // Load the screenshot
            guard let screenshot = NSImage(contentsOfFile: screenshotPath) else {
                return "❌ Failed to load screenshot"
            }
            
            // Initialize AI manager
            let aiManager = AIServiceManager()
            
            // Configure AI service based on defaults
            let provider = Defaults[.aiProvider]
            switch provider {
            case .openAI:
                let apiKey = loadAPIKeyFromKeychain()
                if apiKey.isEmpty {
                    return "❌ OpenAI API key not configured. Please set it in Settings > AI"
                }
                aiManager.configure(provider: .openAI, apiKey: apiKey)
            case .ollama:
                let baseURLString = Defaults[.ollamaBaseURL]
                if let url = URL(string: baseURLString) {
                    aiManager.configure(provider: .ollama, baseURL: url)
                } else {
                    aiManager.configure(provider: .ollama)
                }
            }
            
            // Check if service is available
            guard await aiManager.isServiceAvailable() else {
                return "❌ AI service is not available. Check your settings."
            }
            
            // Prepare the analysis request
            let prompt = """
            What do you see here? Especially take a look at the text sidebar and check if you see "Generating..." meaning Cursor is working or if it appears idle.
            
            Please respond with one of these statuses:
            - 🟢 Idle: If Cursor appears idle with no generation happening
            - 🟡 Generating: If you see "Generating..." or similar text indicating AI is working
            - 🔴 Error: If you see any error messages or connection issues
            - 🔵 Other: For any other notable status
            
            Follow with a brief description of what you observe.
            """
            
            let model = Defaults[.aiModel]
            let request = ImageAnalysisRequest(
                image: screenshot,
                prompt: prompt,
                model: model
            )
            
            // Analyze the image
            let response = try await aiManager.analyzeImage(request)
            return response.text
            
        } catch let error as AIServiceError {
            return "❌ AI Error: \(error.localizedDescription)"
        } catch {
            return "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func loadAPIKeyFromKeychain() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CODELOOPER_OPENAI_API_KEY",
            kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return ""
    }
}

// Removed placeholder GlobalAXLogger as Diagnostics is now imported.
