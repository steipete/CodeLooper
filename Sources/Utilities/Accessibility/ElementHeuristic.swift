import AXorcist
import Foundation

// Define LocatorType based on the string keys used in LocatorManager
// This makes it more type-safe when mapping heuristics.
public enum LocatorType: String, CaseIterable, Codable {
    case connectionErrorIndicator
    case errorMessagePopup
    case forceStopResumeLink
    case mainInputField
    case resumeConnectionButton
    case generatingIndicatorText
    case sidebarActivityArea
    case stopGeneratingButton

    // MARK: Internal

    var heuristic: AXElementHeuristic {
        switch self {
        case .connectionErrorIndicator: ConnectionErrorIndicatorHeuristic()
        case .errorMessagePopup: ErrorMessagePopupHeuristic()
        case .forceStopResumeLink: ForceStopResumeLinkHeuristic()
        case .mainInputField: MainInputFieldHeuristic()
        case .resumeConnectionButton: ResumeConnectionButtonHeuristic()
        case .generatingIndicatorText: GeneratingIndicatorTextHeuristic()
        case .sidebarActivityArea: SidebarActivityAreaHeuristic()
        case .stopGeneratingButton: StopGeneratingButtonHeuristic()
        }
    }

    // Default locators are defined here as part of the enum
    var defaultLocator: Locator? {
        switch self {
        case .connectionErrorIndicator:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXStaticText",
                    "computed_name_contains_any": "offline,network error,connection failed",
                ]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .errorMessagePopup:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXWindow",
                    "subrole_exact": "AXDialog",
                    "description_contains_any": "error,failed,unable",
                ]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .forceStopResumeLink:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXLink",
                    "title_contains_any": "Force Stop,Resume",
                ]),
                rootElementPathHint: nil,
                requireAction: "AXPressAction"
            )
        case .mainInputField:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXTextArea",
                    "placeholder_value_contains": "message",
                ]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .resumeConnectionButton:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXButton",
                    "title_contains_any": "Resume,Try Again,Reload",
                ]),
                rootElementPathHint: nil,
                requireAction: "AXPressAction"
            )
        case .generatingIndicatorText:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXStaticText",
                    "computedName_contains": "generating",
                ]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .sidebarActivityArea:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray(["role": "AXScrollArea"]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .stopGeneratingButton:
            Locator(
                criteria: GeneratingIndicatorTextHeuristic.convertDictionaryToCriteriaArray([
                    "role": "AXButton",
                    "computedName_contains": "Stop",
                ]),
                rootElementPathHint: nil,
                requireAction: nil
            )
        }
    }
}

/// A protocol for heuristics that attempt to discover specific accessibility elements.
protocol AXElementHeuristic {
    /// The type of locator this heuristic tries to discover.
    var locatorType: LocatorType { get }

    /// Attempts to discover the element and return a working Locator for it.
    /// - Parameters:
    ///   - pid: The process ID of the application to inspect.
    ///   - axorcist: An instance of `AXorcist` to perform queries.
    /// - Returns: An `Locator` if discovery is successful, otherwise `nil`.
    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator?
}

// MARK: - Shared Utilities

extension AXElementHeuristic {
    /// Converts a dictionary with keys like "attribute_matchType" to an array of Criterion objects
    static func convertDictionaryToCriteriaArray(_ dict: [String: String]) -> [Criterion] {
        var criteriaArray: [Criterion] = []
        for (key, value) in dict {
            let keyParts = key.split(separator: "_", maxSplits: 1)
            let attributeName = String(keyParts[0])
            var matchType: JSONPathHintComponent.MatchType = .exact // Default

            if keyParts.count > 1 {
                let matchTypeString = String(keyParts[1])
                if matchTypeString == "contains" { matchType = .contains }
                else if matchTypeString == "contains_any" { matchType = .containsAny }
                else if matchTypeString == "prefix" { matchType = .prefix }
                else if matchTypeString == "suffix" { matchType = .suffix }
                else if matchTypeString == "regex" { matchType = .regex }
                else { matchType = JSONPathHintComponent.MatchType(rawValue: matchTypeString) ?? .exact }
            }
            criteriaArray.append(Criterion(attribute: attributeName, value: value, matchType: matchType))
        }
        return criteriaArray
    }
}

// End of file, nothing should follow
