import AXorcist
import Diagnostics
import Foundation

/// Manages query file loading, parsing, and conversion to AXorcist format
@MainActor
class QueryManager {
    // MARK: Lifecycle

    init(projectRoot: String) {
        self.projectRoot = projectRoot
    }

    // MARK: Internal

    // MARK: - Public Properties

    private(set) var parsedQueries: [String: Locator] = [:]
    private(set) var queryAppIdentifiers: [String: String] = [:]
    private(set) var queryAttributes: [String: [String]] = [:]
    private(set) var queryMaxDepth: [String: Int] = [:]

    // MARK: - Public Methods

    func loadAndParseAllQueries() {
        let queryFileNames = ["query_cursor_input.json", "query_cursor_sidebar.json"]

        for queryFileName in queryFileNames {
            guard let queryData = loadQueryFile(named: queryFileName) else { continue }

            do {
                let decoder = JSONDecoder()
                let rawQuery = try decoder.decode(RawQueryFile.self, from: queryData)

                let locator = convertRawLocatorToAXLocator(from: rawQuery.locator)
                parsedQueries[queryFileName] = locator
                queryAppIdentifiers[queryFileName] = rawQuery.applicationIdentifier
                queryAttributes[queryFileName] = rawQuery.locator.attributesToFetch
                queryMaxDepth[queryFileName] = rawQuery.locator.maxDepthForSearch ??
                    AXMiscConstants.defaultMaxDepthSearch

                logger
                    .info(
                        "Successfully loaded and parsed query: \(queryFileName) for app \(rawQuery.applicationIdentifier)"
                    )
            } catch {
                logger.error("Failed to load or parse query file \(queryFileName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: Private

    private let projectRoot: String
    private let logger = Logger(category: .settings)

    // MARK: - Private Methods

    private func loadQueryFile(named fileName: String) -> Data? {
        let queryFilePath = "\(projectRoot)/\(fileName)"
        guard let queryData = FileManager.default.contents(atPath: queryFilePath) else {
            logger.warning("Query file not found at \(queryFilePath)")
            return nil
        }
        return queryData
    }

    private func convertRawLocatorToAXLocator(from rawLocator: RawLocator) -> Locator {
        var criteriaArray: [Criterion] = []

        for (key, value) in rawLocator.criteria {
            let (attributeName, rawMatchType) = parseKeyCriterion(key)
            let matchTypeEnum = JSONPathHintComponent.MatchType(rawValue: rawMatchType) ?? .exact

            criteriaArray.append(Criterion(
                attribute: attributeName,
                value: value,
                matchType: matchTypeEnum
            ))
        }

        var pathHints: [JSONPathHintComponent]?
        if let rawHints = rawLocator.rootElementPathHint {
            pathHints = rawHints.map { rawPathComponent -> JSONPathHintComponent in
                let hintMatchType = JSONPathHintComponent
                    .MatchType(rawValue: rawPathComponent.matchType ?? "") ?? .exact

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
            requireAction: rawLocator.requireAction.map { $0 ? "true" : "false" }
        )
    }

    private func parseKeyCriterion(_ key: String) -> (String, String) {
        let components = key.split(separator: "_", maxSplits: 1)
        if components.count == 2 {
            return (String(components[0]), String(components[1]))
        } else {
            return (key, "exact")
        }
    }

    private func mapJsonAttributeToAXAttribute(_ jsonAttribute: String) -> String? {
        switch jsonAttribute.uppercased() {
        case "AXROLE", "ROLE": return AXAttributeNames.kAXRoleAttribute
        case "AXTITLE", "TITLE": return AXAttributeNames.kAXTitleAttribute
        case "AXLABEL", "LABEL": return AXAttributeNames.kAXDescriptionAttribute // Label is often mapped to description
        case "AXDESCRIPTION", "DESCRIPTION": return AXAttributeNames.kAXDescriptionAttribute
        case "AXHELP", "HELP": return AXAttributeNames.kAXHelpAttribute
        case "AXVALUEDESCRIPTION", "VALUEDESCRIPTION": return AXAttributeNames.kAXValueDescriptionAttribute
        case "AXVALUE", "VALUE": return AXAttributeNames.kAXValueAttribute
        case "AXPLACEHOLDERVALUE", "PLACEHOLDER",
             "PLACEHOLDERVALUE": return AXAttributeNames.kAXPlaceholderValueAttribute
        case "AXENABLED", "ENABLED": return AXAttributeNames.kAXEnabledAttribute
        case "AXFOCUSEDWINDOW":
            return AXAttributeNames.kAXFocusedWindowAttribute
        case "AXMAIN", "MAIN": return AXAttributeNames.kAXMainAttribute
        default:
            logger.warning("Unknown JSON attribute: \(jsonAttribute)")
            return jsonAttribute
        }
    }
}

// MARK: - Data Models

private struct RawQueryFile: Codable {
    enum CodingKeys: String, CodingKey {
        case applicationIdentifier = "application_identifier"
        case locator
    }

    let applicationIdentifier: String
    let locator: RawLocator
}

private struct RawLocator: Codable {
    enum CodingKeys: String, CodingKey {
        case criteria
        case rootElementPathHint = "root_element_path_hint"
        case attributesToFetch = "attributes_to_fetch"
        case maxDepthForSearch = "max_depth_for_search"
        case requireAction = "require_action"
    }

    let criteria: [String: String]
    let rootElementPathHint: [RawPathHintComponent]?
    let attributesToFetch: [String]
    let maxDepthForSearch: Int?
    let requireAction: Bool?
}

private struct RawPathHintComponent: Codable {
    enum CodingKeys: String, CodingKey {
        case attribute, value, depth
        case matchType = "match_type"
    }

    let attribute: String
    let value: String
    let depth: Int?
    let matchType: String?
}
