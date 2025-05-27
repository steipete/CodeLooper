import AXorcist // Import AXorcist module
@preconcurrency import Combine
import Diagnostics
import SwiftUI
import AppKit

// MARK: - axorc Output Structures (Element is provided by AXorcist, so these might be simplified or removed)

// We'll rely on AXorcist.Element for success cases.
// Error handling will be based on HandlerResponse.error.

@MainActor
class CursorInputWatcherViewModel: ObservableObject {
    // MARK: Lifecycle

    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") { // Default for dev
        self.projectRoot = projectRoot
        loadAndParseAllQueries()
        loadPortMappings()
        setupWindowsSubscription()
        
        // Port probing for pre-existing windows now happens automatically
        // when windows are first detected in setupWindowsSubscription()
    }

    deinit {
        timerSubscription?.cancel()
        windowsSubscription?.cancel()
        // Clean up JS hooks
        for _ in jsHooks.values {
            // CursorJSHook doesn't have explicit cleanup, but we'll clear our references
        }
        jsHooks.removeAll()
    }

    // MARK: Internal

    @Published var watchedInputs: [CursorWindowInfo] = [
        CursorWindowInfo(id: "main-ai-slash-input", name: "AI Slash Input", queryFile: "query_cursor_input.json"),
        CursorWindowInfo(id: "sidebar-text-area", name: "Sidebar Text Content", queryFile: "query_cursor_sidebar.json"),
    ]
    @Published var statusMessage: String = "Watcher is disabled."
    @Published var cursorWindows: [MonitoredWindowInfo] = []
    @Published var hookedWindows: Set<String> = [] // Track which windows have JS hooks installed
    @Published var isInjectingHook: Bool = false // Track injection state

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

        // First, probe for existing hooks
        statusMessage = "Probing for existing hook in \(window.windowTitle ?? "window")..."

        // Try to probe using the existing port for this window, if any
        if let existingPort = windowPorts[window.id] {
            if await probePort(existingPort, for: window) {
                return // Hook already exists
            }
        }

        // Try common ports in parallel to see if a hook exists from a previous session
        let portsToProbe = Array(stride(from: basePort, to: basePort + 10, by: 1))
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
        
        // Check if any probe was successful
        if probeResults.contains(where: { $0.1 }) {
            return // Found existing hook
        }

        // No existing hook found, inject a new one
        do {
            let port = getOrAssignPort(for: window.id)
            statusMessage = "Installing CodeLooper hook on port \(port)..."

            // Create a new JS hook instance with specific port
            let hook = try await CursorJSHook(applicationName: "Cursor", port: port)

            // Store the hook and mark the window as hooked
            jsHooks[window.id] = hook
            hookedWindows.insert(window.id)

            // Test the hook by running a simple JS command
            let testResult = try await hook.runJS("'Hook installed successfully on port \(port)'")
            Logger(category: .settings)
                .info("JS Hook installed for window \(window.windowTitle ?? "Unknown") on port \(port): \(testResult)")

            statusMessage = "JS Hook installed in \(window.windowTitle ?? "window") on port \(port)"

            // Save port mapping
            savePortMappings()
        } catch {
            Logger(category: .settings)
                .error(
                    "Failed to inject JS hook into window \(window.windowTitle ?? "Unknown"): \(error.localizedDescription)"
                )
            
            // Extract the underlying error from HookError
            var underlyingError: NSError?
            if case let CursorJSHook.HookError.injectionFailed(innerError) = error,
               let nsError = innerError as NSError? {
                underlyingError = nsError
            } else if let nsError = error as NSError? {
                underlyingError = nsError
            }
            
            // Log the specific error code for debugging
            if let nsError = underlyingError {
                Logger(category: .settings)
                    .error("JS Hook injection error code: \(nsError.code), domain: \(nsError.domain)")
            }
            
            // Provide more specific error messages based on the error
            if let nsError = underlyingError {
                switch nsError.code {
                case -1743:
                    statusMessage = "Automation permission denied. Grant permission in System Settings > Privacy & Security > Automation"
                    // Show the permission alert on main thread
                    Task { @MainActor in
                        showAutomationPermissionAlert()
                    }
                case -600:
                    statusMessage = "Cursor is not running. Please start Cursor first."
                case -10004:
                    statusMessage = "Privilege violation. Check accessibility permissions."
                default:
                    statusMessage = "Failed: \(error.localizedDescription)"
                }
            } else {
                statusMessage = "Failed to inject JS hook: \(error.localizedDescription)"
            }

            // Remove from hooked windows if injection failed
            hookedWindows.remove(window.id)
            jsHooks.removeValue(forKey: window.id)
            windowPorts.removeValue(forKey: window.id)
        }
    }

    func checkHookStatus(for window: MonitoredWindowInfo) -> Bool {
        guard let hook = jsHooks[window.id] else { return false }
        return hook.isHooked
    }

    func getPort(for windowId: String) -> UInt16? {
        windowPorts[windowId]
    }

    // MARK: Private

    // Temporary struct to match the JSON query file structure for decoding
    private struct RawQueryFile: Codable {
        let application_identifier: String
        let locator: RawLocator
    }

    private struct RawLocator: Codable {
        let criteria: [String: String] // Key might be "attributeName_matchType" or just "attributeName"
        let root_element_path_hint: [RawPathHintComponent]?
        // descendant_criteria and descendant_criteria_exclusions are not directly used by AXorcist.Locator
        // but could be used to build more complex queries if needed in the future.
        // let descendant_criteria: [String: String]?
        // let descendant_criteria_exclusions: [String: String]?
        let attributes_to_fetch: [String]
        let max_depth_for_search: Int?
        // let match_all: Bool? // Not part of AXorcist.Locator, handled by Criterion array logic
        let require_action: String?
    }

    private struct RawPathHintComponent: Codable {
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
        let match_type: String? // Optional match type string (e.g., "contains", "exact")
    }

    private var jsHooks: [String: CursorJSHook] = [:] // Store JS hooks by window ID
    private var windowPorts: [String: UInt16] = [:] // Store port assignments by window ID
    private let basePort: UInt16 = 9001
    private var nextPort: UInt16 = 9001

    private var timerSubscription: AnyCancellable?
    private let axorcist = AXorcist() // AXorcist instance
    private var projectRoot: String = ""
    private let cursorMonitor = CursorMonitor.shared
    private var windowsSubscription: AnyCancellable?

    // Store for pre-loaded and parsed queries
    private var parsedQueries: [String: Locator] = [:]
    private var queryAppIdentifiers: [String: String] = [:] // To store app_identifier for each query file
    private var queryAttributes: [String: [String]] = [:] // To store attributes_to_fetch
    private var queryMaxDepth: [String: Int] = [:]

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
                if previousWindowCount == 0 && !self.cursorWindows.isEmpty {
                    Task {
                        await self.probeAllWindowsForExistingHooks()
                    }
                }
                
                // For new windows that appear during runtime, we can optimize by not probing
                // since they likely don't have hooks yet
                if previousWindowCount > 0 && self.cursorWindows.count > previousWindowCount {
                    // New windows detected during runtime - these are fresh and won't have hooks
                    Logger(category: .settings).info("New windows detected during runtime, skipping probe")
                }
            }
    }

    private func loadAndParseAllQueries() {
        for inputInfo in watchedInputs {
            if let queryFileName = inputInfo.queryFile {
                let fullQueryPath = "\(projectRoot)/\(queryFileName)"
                do {
                    let queryData = try Data(contentsOf: URL(fileURLWithPath: fullQueryPath))
                    let decoder = JSONDecoder()
                    let rawQuery = try decoder.decode(RawQueryFile.self, from: queryData)

                    let locator = convertRawLocatorToAXLocator(from: rawQuery.locator)
                    parsedQueries[queryFileName] = locator
                    queryAppIdentifiers[queryFileName] = rawQuery.application_identifier
                    queryAttributes[queryFileName] = rawQuery.locator.attributes_to_fetch
                    queryMaxDepth[queryFileName] = rawQuery.locator.max_depth_for_search ?? AXMiscConstants
                        .defaultMaxDepthSearch

                    Logger(category: .settings)
                        .info(
                            "Successfully loaded and parsed query: \(queryFileName) for app \(rawQuery.application_identifier)"
                        )
                } catch {
                    Logger(category: .settings)
                        .error("Failed to load or parse query file \(queryFileName): \(error.localizedDescription)")
                }
            }
        }
    }

    private func convertRawLocatorToAXLocator(from rawLocator: RawLocator) -> Locator {
        var criteriaArray: [Criterion] = []
        for (key, value) in rawLocator.criteria {
            // Simple split for "attribute_matchtype" like "title_contains"
            let parts = key.split(separator: "_", maxSplits: 1)
            let attributeName = String(parts[0])
            var matchTypeEnum: JSONPathHintComponent.MatchType = .exact // Default, changed from .equals

            if parts.count > 1 {
                matchTypeEnum = JSONPathHintComponent
                    .MatchType(rawValue: String(parts[1])) ?? .exact // changed from .equals
            }
            criteriaArray.append(Criterion(
                attribute: attributeName,
                value: value,
                matchType: matchTypeEnum
            )) // value directly, not AnyCodable(value)
        }

        var pathHints: [JSONPathHintComponent]? = nil
        if let rawHints = rawLocator.root_element_path_hint {
            pathHints = rawHints.map { rawPathComponent -> JSONPathHintComponent in
                // The mapJsonAttributeToAXAttribute might be overly complex here if JSON uses standard AX names.
                // Determine matchType based on rawPathComponent.match_type or infer it.
                let hintMatchType = JSONPathHintComponent
                    .MatchType(rawValue: rawPathComponent.match_type ?? "") ?? .exact // changed from .equals

                return JSONPathHintComponent(
                    attribute: mapJsonAttributeToAXAttribute(rawPathComponent.attribute) ?? rawPathComponent.attribute,
                    value: rawPathComponent.value,
                    depth: rawPathComponent.depth,
                    matchType: hintMatchType
                )
            }
        }

        return Locator(
            criteria: criteriaArray,
            rootElementPathHint: pathHints,
            requireAction: rawLocator.require_action
        )
    }

    // This function might be too simplistic or not needed if JSON directly provides match types.
    // private func determineMatchType(forValue value: String) -> JSONPathHintComponent.MatchType { ... }

    // mapJsonAttributeToAXAttribute might not be necessary if JSON uses official AX attribute names.
    // It can be kept for flexibility if JSON uses aliases.
    private func mapJsonAttributeToAXAttribute(_ jsonKey: String) -> String? {
        // (Implementation from before, seems reasonable for alias mapping)
        let upperJsonKey = jsonKey.uppercased()
        switch upperJsonKey {
        case "AXROLE", "ROLE": return AXAttributeNames.kAXRoleAttribute
        case "AXSUBROLE", "SUBROLE": return AXAttributeNames.kAXSubroleAttribute
        case "AXROLEDESCRIPTION", "ROLEDESCRIPTION": return AXAttributeNames.kAXRoleDescriptionAttribute
        case "AXTITLE", "TITLE": return AXAttributeNames.kAXTitleAttribute
        case "AXIDENTIFIER", "ID", "IDENTIFIER": return AXAttributeNames.kAXIdentifierAttribute
        case "AXDESCRIPTION", "DESCRIPTION": return AXAttributeNames.kAXDescriptionAttribute
        case "AXHELP", "HELP": return AXAttributeNames.kAXHelpAttribute
        case "AXVALUEDESCRIPTION", "VALUEDESCRIPTION": return AXAttributeNames.kAXValueDescriptionAttribute
        case "AXVALUE", "VALUE": return AXAttributeNames.kAXValueAttribute
        case "AXPLACEHOLDERVALUE", "PLACEHOLDER",
             "PLACEHOLDERVALUE": return AXAttributeNames.kAXPlaceholderValueAttribute
        case "AXENABLED", "ENABLED": return AXAttributeNames.kAXEnabledAttribute
        case "AXFOCUSED", "FOCUSED": return AXAttributeNames.kAXFocusedAttribute
        case "AXELEMENTBUSY", "BUSY": return AXAttributeNames.kAXElementBusyAttribute
        case "AXPOSITION", "POSITION": return AXAttributeNames.kAXPositionAttribute
        case "AXSIZE", "SIZE": return AXAttributeNames.kAXSizeAttribute
        case "AXDOMCLASSLIST", "DOMCLASSLIST", "DOMCLASS": return AXAttributeNames.kAXDOMClassListAttribute
        case "AXDOMIDENTIFIER", "DOMID", "DOMIDENTIFIER": return AXAttributeNames.kAXDOMIdentifierAttribute
        case "AXURL", "URL": return AXAttributeNames.kAXURLAttribute
        case "AXDOCUMENT", "DOCUMENT": return AXAttributeNames.kAXDocumentAttribute
        case "AXMAINWINDOW": return AXAttributeNames.kAXMainWindowAttribute
        case "AXFOCUSEDWINDOW": return AXAttributeNames.kAXFocusedWindowAttribute
        case "AXMAIN", "MAIN": return AXAttributeNames.kAXMainAttribute
        default:
            Logger(category: .accessibility)
                .warning(
                    "Unmapped JSON attribute key '\(jsonKey)' used in query path hint. Falling back to using key directly."
                )
            return jsonKey
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
        guard let currentQueryFile = inputInfo.queryFile, // Used for fetching parsed data
              let appIdentifier = queryAppIdentifiers[currentQueryFile],
              let locator = parsedQueries[currentQueryFile],
              let attributesToFetch = queryAttributes[currentQueryFile]
        else {
            let errorMsg =
                "Query not loaded, parsed, or appID missing for \(inputInfo.name). QueryFile: \(inputInfo.queryFile ?? "nil")"
            self.watchedInputs[index].lastError = errorMsg
            self.statusMessage = "Configuration error for \(inputInfo.name)."
            // Use inputInfo.queryFile in the logger call
            Logger(category: .settings)
                .error(
                    "Missing parsed query for \(inputInfo.queryFile ?? "<unknown file>") for input \(inputInfo.name): \(errorMsg)"
                )
            return
        }
        let maxDepth = queryMaxDepth[currentQueryFile] ?? AXMiscConstants.defaultMaxDepthSearch

        // Update status before starting the async Task
        // statusMessage = "Querying text for: \(inputInfo.name)..." // This will rapidly change; consider a general
        // status.

        Task { // Perform AXorcist call in a background Task
            let queryCommand = QueryCommand(
                appIdentifier: appIdentifier,
                locator: locator,
                attributesToReturn: attributesToFetch,
                maxDepthForSearch: maxDepth
            )
            let response = axorcist
                .handleQuery(command: queryCommand,
                             maxDepth: maxDepth) // outputFormat is not part of QueryCommand, handleQuery is not async

            // Process the response on the MainActor
            await MainActor.run {
                if let errorMsg = response.error {
                    self.watchedInputs[index].lastError = "AXorcist Error: \(errorMsg.message)"
                    self.statusMessage = "Error querying \(inputInfo.name)."
                    Logger(category: .accessibility)
                        .error("AXorcist error for \(inputInfo.name) (query: \(currentQueryFile)): \(errorMsg.message)")
                } else if case let .success(payload, _) = response,
                          let responseData = payload
                { // responseData is AnyCodable
                    var foundText: String? = nil
                    var foundElements: [Element] = []

                    if let singleElement = responseData.value as? Element {
                        foundElements = [singleElement]
                    } else if let multipleElements = responseData.value as? [Element] {
                        foundElements = multipleElements
                    } else {
                        let desc = String(describing: responseData.value)
                        Logger(category: .accessibility)
                            .warning(
                                "AXorcist response data for \(inputInfo.name) (query: \(currentQueryFile)) was not a single Element or [Element]. Type: \(type(of: responseData.value)), Description: \(desc.prefix(200))"
                            )
                        self.watchedInputs[index].lastError = "Unexpected data format from AXorcist."
                        self.statusMessage = "Format error for \(inputInfo.name)."
                        return // Exit if data is not in expected Element format
                    }

                    if foundElements.isEmpty {
                        self.watchedInputs[index].lastError = "No elements found by AXorcist."
                        Logger(category: .accessibility)
                            .info("No elements found for \(inputInfo.name) (query: \(currentQueryFile))")
                    } else {
                        let firstElement = foundElements[0]

                        if let attributes = firstElement.attributes,
                           let value = attributes[AXAttributeNames.kAXValueAttribute]?.value as? String
                        {
                            foundText = value
                        } else if let attributes = firstElement.attributes,
                                  let firstRequestedAttrKey = attributesToFetch.first,
                                  let attrValueAny = attributes[firstRequestedAttrKey]?.value
                        {
                            if let strValue = attrValueAny as? String {
                                foundText = strValue
                            } else {
                                // If not a string, represent it as a description.
                                // This might be noisy if attributes like AXPosition are fetched.
                                foundText = String(describing: attrValueAny)
                                Logger(category: .accessibility)
                                    .info(
                                        "Attribute \(firstRequestedAttrKey) for \(inputInfo.name) was not String, using description: \(foundText ?? "nil")"
                                    )
                            }
                        } else {
                            // If neither AXValue nor the first requested attribute is a string.
                            foundText = "<\(attributesToFetch.first ?? "Attribute") not string or found>"
                            Logger(category: .accessibility)
                                .warning(
                                    "Could not extract primary text attribute (AXValue or \(attributesToFetch.first ?? "N/A")) as String for \(inputInfo.name). Element dump: \(firstElement.briefDescription(option: .stringified))"
                                )
                        }

                        self.watchedInputs[index].lastKnownText = foundText ?? "<No text extractable>"
                        self.watchedInputs[index].lastError = nil // Clear previous error
                        // Update general status message less frequently, or make it more general.
                        // self.statusMessage = "Updated: \(inputInfo.name)"
                        Logger(category: .accessibility)
                            .info(
                                "Successfully queried \(inputInfo.name) (query: \(currentQueryFile)): \(foundText ?? "<nil>")"
                            )

                        if foundElements.count > 1 {
                            Logger(category: .accessibility)
                                .info(
                                    "Query for \(inputInfo.name) (query: \(currentQueryFile)) returned \(foundElements.count) elements. Processed the first."
                                )
                        }
                    }
                } else {
                    self.watchedInputs[index].lastError = "AXorcist returned no data and no error."
                    // self.watchedInputs[index].lastKnownText = "" // Or "No data"
                    Logger(category: .accessibility)
                        .warning(
                            "AXorcist returned no data and no error for \(inputInfo.name) (query: \(currentQueryFile))."
                        )
                }
                // Update general status perhaps after all queries in a cycle, or a more stable message.
                if self.isWatchingEnabled { // Check if still watching before updating status
                    let activeErrorCount = self.watchedInputs.count(where: { $0.lastError != nil })
                    if activeErrorCount > 0 {
                        self.statusMessage = "Watcher active with \(activeErrorCount) error(s)."
                    } else {
                        self.statusMessage = "Watcher active. All inputs OK."
                    }
                }
            }
        }
    }

    // Periodically check hook status and update UI
    private func updateHookStatuses() {
        for windowId in hookedWindows {
            if let window = cursorWindows.first(where: { $0.id == windowId }),
               let hook = jsHooks[windowId]
            {
                if !hook.isHooked {
                    // Hook was lost, remove it
                    hookedWindows.remove(windowId)
                    jsHooks.removeValue(forKey: windowId)
                    Logger(category: .settings)
                        .warning("JS Hook lost for window \(window.windowTitle ?? "Unknown")")
                }
            }
        }
    }

    // MARK: - Port Management

    private func getOrAssignPort(for windowId: String) -> UInt16 {
        if let existingPort = windowPorts[windowId] {
            return existingPort
        }

        // Find next available port
        while windowPorts.values.contains(nextPort) {
            nextPort += 1
        }

        let assignedPort = nextPort
        windowPorts[windowId] = assignedPort
        nextPort += 1

        return assignedPort
    }

    private func probePort(_ port: UInt16, for window: MonitoredWindowInfo) async -> Bool {
        do {
            // Create a hook in probe mode (no injection)
            let probeHook = try await CursorJSHook(applicationName: "Cursor", port: port, skipInjection: true)

            // Wait for existing hook to connect (longer timeout since we probe in parallel)
            if await probeHook.probeForExistingHook(timeout: 2.0) {
                // Hook exists! Store it
                jsHooks[window.id] = probeHook
                hookedWindows.insert(window.id)
                windowPorts[window.id] = port

                // Test the existing hook
                if let testResult = try? await probeHook.runJS("'Existing hook found on port \(port)'") {
                    Logger(category: .settings)
                        .info(
                            "Found existing JS Hook for window \(window.windowTitle ?? "Unknown") on port \(port): \(testResult)"
                        )
                    statusMessage = "Found existing hook in \(window.windowTitle ?? "window") on port \(port)"
                } else {
                    statusMessage = "Found existing hook on port \(port) (no response)"
                }

                savePortMappings()
                return true
            }
        } catch {
            // Port probe failed, continue to next
        }

        return false
    }

    // MARK: - Persistence

    private func probeAllWindowsForExistingHooks() async {
        statusMessage = "Probing for existing hooks..."

        // Filter windows that need probing
        let windowsToProbe = cursorWindows.filter { window in
            !hookedWindows.contains(window.id) && windowPorts[window.id] != nil
        }

        // Probe all windows in parallel
        await withTaskGroup(of: Void.self) { group in
            for window in windowsToProbe {
                if let existingPort = windowPorts[window.id] {
                    group.addTask {
                        _ = await self.probePort(existingPort, for: window)
                    }
                }
            }
        }

        if hookedWindows.isEmpty {
            statusMessage = "No existing hooks found"
        } else {
            statusMessage = "Found \(hookedWindows.count) existing hook(s)"
        }
    }

    private func loadPortMappings() {
        if let data = UserDefaults.standard.data(forKey: "CursorJSHookPortMappings"),
           let mappings = try? JSONDecoder().decode([String: UInt16].self, from: data)
        {
            windowPorts = mappings

            // Update nextPort to avoid conflicts
            if let maxPort = mappings.values.max() {
                nextPort = maxPort + 1
            }

            Logger(category: .settings).info("Loaded port mappings: \(mappings)")
        }
    }

    private func savePortMappings() {
        if let data = try? JSONEncoder().encode(windowPorts) {
            UserDefaults.standard.set(data, forKey: "CursorJSHookPortMappings")
            Logger(category: .settings).info("Saved port mappings: \(windowPorts)")
        }
    }
    
    private func showAutomationPermissionAlert() {
        // Ensure the app is active before showing the alert
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Automation Permission Required"
        alert.informativeText = "CodeLooper needs permission to control Cursor via automation.\n\nPlease grant permission in System Settings > Privacy & Security > Automation, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        // Find the key window to attach the alert to
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Open System Settings to the Automation pane
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
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
}

// Removed placeholder GlobalAXLogger as Diagnostics is now imported.
