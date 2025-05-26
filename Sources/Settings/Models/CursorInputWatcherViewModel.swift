import SwiftUI
import Combine
import Diagnostics
import AXorcist // Import AXorcist module

// MARK: - axorc Output Structures (AXElement is provided by AXorcist, so these might be simplified or removed)
// We'll rely on AXorcist.AXElement for success cases.
// Error handling will be based on HandlerResponse.error.

@MainActor
class CursorInputWatcherViewModel: ObservableObject {
    @Published var isWatchingEnabled: Bool = false {
        didSet {
            if isWatchingEnabled {
                startWatching()
            } else {
                stopWatching()
            }
        }
    }
    @Published var watchedInputs: [CursorWindowInfo] = [
        CursorWindowInfo(id: "main-ai-slash-input", name: "AI Slash Input", queryFile: "query_cursor_input.json"),
        CursorWindowInfo(id: "sidebar-text-area", name: "Sidebar Text Content", queryFile: "query_cursor_sidebar.json")
    ]
    @Published var statusMessage: String = "Watcher is disabled."

    private var timerSubscription: AnyCancellable?
    private let axorcist = AXorcist() // AXorcist instance
    private var projectRoot: String = "" 

    // Store for pre-loaded and parsed queries
    private var parsedQueries: [String: AXorcist.Locator] = [:]
    private var queryAppIdentifiers: [String: String] = [:] // To store app_identifier for each query file
    private var queryAttributes: [String: [String]] = [:] // To store attributes_to_fetch
    private var queryMaxDepth: [String: Int] = [:]


    init(projectRoot: String = "/Users/steipete/Projects/CodeLooper") { // Default for dev
        self.projectRoot = projectRoot
        loadAndParseAllQueries()
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
                    queryMaxDepth[queryFileName] = rawQuery.locator.max_depth_for_search ?? AXMiscConstants.defaultMaxDepthSearch
                    
                    Logger(category: .settings).info("Successfully loaded and parsed query: \(queryFileName) for app \(rawQuery.application_identifier)")
                } catch {
                    Logger(category: .settings).error("Failed to load or parse query file \(queryFileName): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Temporary struct to match the JSON query file structure for decoding
    private struct RawQueryFile: Codable {
        let application_identifier: String
        let locator: RawLocator
    }

    // RawLocator now more closely matches the reverted AXorcist.Locator
    private struct RawLocator: Codable {
        let criteria: [String: String]
        let root_element_path_hint: [RawPathHintComponent]?
        let descendant_criteria: [String: String]?
        let descendant_criteria_exclusions: [String: String]? // From JSON, currently unhandled by AXorcist.Locator directly
        let attributes_to_fetch: [String]
        let max_depth_for_search: Int?
        let match_all: Bool? // From JSON
    }
    
    private struct RawPathHintComponent: Codable {
        let attribute: String
        let value: String
        let depth: Int?
        // match_type can be added if needed from JSONPathHintComponent.MatchType and present in JSON file
    }

    private func convertRawLocatorToAXLocator(from rawLocator: RawLocator) -> AXorcist.Locator {
        var criteria: [AXorcist.Criterion] = []
        for (key, value) in rawLocator.criteria {
            let mappedKey = mapJsonAttributeToAXAttribute(key) ?? key
            let matchType = determineMatchType(forValue: value) // Helper to determine match type
            criteria.append(AXorcist.Criterion(attribute: mappedKey, value: value, match_type: matchType))
        }

        let pathHints: [AXorcist.JSONPathHintComponent]? = rawLocator.root_element_path_hint?.map { rawHint in
            // Assuming RawPathHintComponent's attribute also needs mapping if it's not a direct AX Name
            let mappedAttribute = mapJsonAttributeToAXAttribute(rawHint.attribute) ?? rawHint.attribute
            // Path hints typically use exact match for simplicity, but could be made flexible
            AXorcist.JSONPathHintComponent(attribute: mappedAttribute, value: rawHint.value, depth: rawHint.depth, matchType: .exact) 
        }
        
        // descendant_criteria_exclusions is still not directly mapped to AXorcist.Locator here.

        return AXorcist.Locator(
            matchAll: rawLocator.match_all,
            criteria: criteria,
            rootElementPathHint: pathHints,
            descendantCriteria: rawLocator.descendant_criteria
            // requireAction, computedNameContains are not in RawLocator, so default in AXorcist.Locator init is used.
        )
    }
    
    private func determineMatchType(forValue value: String) -> AXorcist.JSONPathHintComponent.MatchType {
        if value.hasPrefix("(") && value.hasSuffix(")") && value.contains("|") {
            return .regex
        } else if value.contains("*") || value.contains("?") { // Simple wildcard check for contains, could be more robust
            return .contains // Or a new .wildcard if AXorcist supports it, otherwise use .regex
        }        
        return .exact
    }

    // Placeholder for attribute name mapping
    private func mapJsonAttributeToAXAttribute(_ jsonKey: String) -> String? {
        // Case-insensitive mapping from common JSON keys to AXAttributeNames constants
        let upperJsonKey = jsonKey.uppercased()
        switch upperJsonKey {
        // Role & Subrole
        case "AXROLE", "ROLE": return AXAttributeNames.kAXRoleAttribute
        case "AXSUBROLE", "SUBROLE": return AXAttributeNames.kAXSubroleAttribute
        case "AXROLEDESCRIPTION", "ROLEDESCRIPTION": return AXAttributeNames.kAXRoleDescriptionAttribute

        // Identification & Description
        case "AXTITLE", "TITLE": return AXAttributeNames.kAXTitleAttribute
        case "AXIDENTIFIER", "ID", "IDENTIFIER": return AXAttributeNames.kAXIdentifierAttribute
        case "AXDESCRIPTION", "DESCRIPTION": return AXAttributeNames.kAXDescriptionAttribute
        case "AXHELP", "HELP": return AXAttributeNames.kAXHelpAttribute
        case "AXVALUEDESCRIPTION", "VALUEDESCRIPTION": return AXAttributeNames.kAXValueDescriptionAttribute

        // Value
        case "AXVALUE", "VALUE": return AXAttributeNames.kAXValueAttribute
        case "AXPLACEHOLDERVALUE", "PLACEHOLDER", "PLACEHOLDERVALUE": return AXAttributeNames.kAXPlaceholderValueAttribute

        // State
        case "AXENABLED", "ENABLED": return AXAttributeNames.kAXEnabledAttribute
        case "AXFOCUSED", "FOCUSED": return AXAttributeNames.kAXFocusedAttribute
        case "AXELEMENTBUSY", "BUSY": return AXAttributeNames.kAXElementBusyAttribute

        // Geometry (Note: these return AXValueRef containing CGPoint/CGSize)
        case "AXPOSITION", "POSITION": return AXAttributeNames.kAXPositionAttribute
        case "AXSIZE", "SIZE": return AXAttributeNames.kAXSizeAttribute

        // DOM Attributes (from WebArea)
        case "AXDOMCLASSLIST", "DOMCLASSLIST", "DOMCLASS": return AXAttributeNames.kAXDOMClassListAttribute
        case "AXDOMIDENTIFIER", "DOMID", "DOMIDENTIFIER": return AXAttributeNames.kAXDOMIdentifierAttribute
        case "AXURL", "URL": return AXAttributeNames.kAXURLAttribute
        case "AXDOCUMENT", "DOCUMENT": return AXAttributeNames.kAXDocumentAttribute
            
        // Window specific
        case "AXMAINWINDOW": return AXAttributeNames.kAXMainWindowAttribute
        case "AXFOCUSEDWINDOW": return AXAttributeNames.kAXFocusedWindowAttribute
        case "AXMAIN", "MAIN": return AXAttributeNames.kAXMainAttribute // For window
            
        // Default: if no specific mapping, assume the key might be a direct AX constant name (less likely for JSON usage)
        default:
            // Check if jsonKey itself is a valid known AXAttribute constant (e.g. if user provided full kAX... name)
            // This is a simplification; a full list check would be too long here.
            // Consider logging a warning if a key isn't mapped.
            Logger(category: .accessibility).warning("Unmapped JSON attribute key '\(jsonKey)' used in query. Falling back to using key directly.")
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
        
        for i in watchedInputs.indices {
            queryInputText(forInputIndex: i)
        }

        timerSubscription = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self, self.isWatchingEnabled else { return }
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

    private func stopWatching() {
        timerSubscription?.cancel()
        timerSubscription = nil
        statusMessage = "Watcher is disabled."
    }

    private func queryInputText(forInputIndex index: Int) {
        guard index < watchedInputs.count else { return }
        
        var inputInfo = watchedInputs[index]
        guard let queryFileName = inputInfo.queryFile,
              let appIdentifier = queryAppIdentifiers[queryFileName], // Get stored appID
              let locator = parsedQueries[queryFileName],
              let attributesToFetch = queryAttributes[queryFileName] else {
            self.watchedInputs[index].lastError = "Query not loaded, parsed, or appID missing for \(inputInfo.name)."
            self.statusMessage = "Configuration error for \(inputInfo.name)."
            Logger(category: .settings).error("Missing parsed query for \(queryFileName) for input \(inputInfo.name)")
            return
        }
        let maxDepth = queryMaxDepth[queryFileName] ?? AXMiscConstants.defaultMaxDepthSearch

        statusMessage = "Querying text for: \(inputInfo.name) using AXorcist library..."

        Task { // Perform AXorcist call in a background Task
            // App identifier is now fetched from stored values for the specific query
            let response = await axorcist.handleQuery(
                for: appIdentifier, // Use fetched appIdentifier
                locator: locator,
                maxDepth: maxDepth,
                requestedAttributes: attributesToFetch,
                outputFormat: .json // Or .smart, depending on how we want to parse
            )

            // Process the response on the main thread
            await MainActor.run {
                if let errorMsg = response.error {
                    self.watchedInputs[index].lastError = "AXorcist Error: \(errorMsg)"
                    self.statusMessage = "Error querying \(inputInfo.name)."
                    Logger(category: .accessibility).error("AXorcist error for \(inputInfo.name): \(errorMsg). Logs: \(response.logs?.joined(separator: "\n") ?? "N/A")")
                } else if let responseData = response.data {
                    do {
                        // Assuming response.data is AnyCodable wrapping AXElement
                        let axElement = try responseData.decode(AXorcist.AXElement.self)
                        if let axValue = axElement.attributes[AXAttributeNames.kAXValueAttribute] as? String {
                            self.watchedInputs[index].lastKnownText = axValue
                            self.watchedInputs[index].lastError = nil
                            self.statusMessage = "Updated \(self.watchedInputs[index].name): \(Date().formatted(date: .omitted, time: .standard))"
                        } else {
                            self.watchedInputs[index].lastError = "AXValue not found in attributes."
                            self.statusMessage = "Attribute missing for \(self.watchedInputs[index].name)."
                            Logger(category: .accessibility).warning("AXValue missing for \(inputInfo.name). Attributes: \(axElement.attributes)")
                        }
                    } catch {
                        self.watchedInputs[index].lastError = "Failed to decode AXElement: \(error.localizedDescription)"
                        self.statusMessage = "Decoding error for \(self.watchedInputs[index].name)."
                        Logger(category: .accessibility).error("Failed to decode AXElement for \(inputInfo.name): \(error.localizedDescription). Raw data: \(String(describing: responseData))")
                    }
                } else {
                    self.watchedInputs[index].lastError = "AXorcist returned no data and no error."
                    self.statusMessage = "Empty response for \(self.watchedInputs[index].name)."
                     Logger(category: .accessibility).warning("Empty response from AXorcist for \(inputInfo.name).")
                }
            }
        }
    }
    
    deinit {
        stopWatching()
    }
}

// Make sure CursorWindowInfo has a queryFile property
// This should be done in CursorWindowInfo.swift, but I'll note it here.
// Assuming change is:
// struct CursorWindowInfo: Identifiable, Hashable {
//     let id: String 
//     var name: String 
//     var queryFile: String? // ADDED
//     var lastKnownText: String = ""
//     var lastError: String?
// }

// Removed placeholder GlobalAXLogger as Diagnostics is now imported. 