import AXorcist // Import AXorcist module
@preconcurrency import Combine
import Diagnostics
import SwiftUI

// MARK: - axorc Output Structures (Element is provided by AXorcist, so these might be simplified or removed)

// We'll rely on AXorcist.Element for success cases.
// Error handling will be based on HandlerResponse.error.

@MainActor
class CursorInputWatcherViewModel: ObservableObject {
    // MARK: Lifecycle

    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") { // Default for dev
        self.projectRoot = projectRoot
        loadAndParseAllQueries()
        setupWindowsSubscription()
    }

    deinit {
        timerSubscription?.cancel()
        windowsSubscription?.cancel()
    }

    // MARK: Internal

    @Published var watchedInputs: [CursorWindowInfo] = [
        CursorWindowInfo(id: "main-ai-slash-input", name: "AI Slash Input", queryFile: "query_cursor_input.json"),
        CursorWindowInfo(id: "sidebar-text-area", name: "Sidebar Text Content", queryFile: "query_cursor_sidebar.json"),
    ]
    @Published var statusMessage: String = "Watcher is disabled."
    @Published var cursorWindows: [MonitoredWindowInfo] = []

    @Published var isWatchingEnabled: Bool = false {
        didSet {
            if isWatchingEnabled {
                startWatching()
            } else {
                stopWatching()
            }
        }
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
                if let cursorApp = apps.first {
                    self.cursorWindows = cursorApp.windows
                } else {
                    self.cursorWindows = []
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
}

// Removed placeholder GlobalAXLogger as Diagnostics is now imported.
