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

    var heuristic: AXElementHeuristic {
        switch self {
        case .connectionErrorIndicator: return ConnectionErrorIndicatorHeuristic()
        case .errorMessagePopup: return ErrorMessagePopupHeuristic()
        case .forceStopResumeLink: return ForceStopResumeLinkHeuristic()
        case .mainInputField: return MainInputFieldHeuristic()
        case .resumeConnectionButton: return ResumeConnectionButtonHeuristic()
        case .generatingIndicatorText: return GeneratingIndicatorTextHeuristic()
        case .sidebarActivityArea: return SidebarActivityAreaHeuristic()
        case .stopGeneratingButton: return StopGeneratingButtonHeuristic()
        }
    }

    // Default locators are defined here as part of the enum
    var defaultLocator: Locator? {
        switch self {
        case .connectionErrorIndicator:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXStaticText", "computed_name_contains_any": "offline,network error,connection failed"],
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .errorMessagePopup:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXWindow", "subrole": "AXDialog", "description_contains_any": "error,failed,unable"],
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .forceStopResumeLink:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXLink", "title_contains_any": "Force Stop,Resume"],
                rootElementPathHint: nil,
                requireAction: "AXPressAction"
            )
        case .mainInputField:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXTextArea", "placeholder_value_contains": "message"],
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .resumeConnectionButton:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXButton", "title_contains_any": "Resume,Try Again,Reload"],
                rootElementPathHint: nil,
                requireAction: "AXPressAction"
            )
        case .generatingIndicatorText:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXStaticText"],
                rootElementPathHint: nil,
                requireAction: nil,
                computedNameContains: "generating"
            )
        case .sidebarActivityArea:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXScrollArea"],
                rootElementPathHint: nil,
                requireAction: nil
            )
        case .stopGeneratingButton:
            return Locator(
                matchAll: false,
                criteria: ["role": "AXButton"],
                rootElementPathHint: nil,
                requireAction: nil,
                computedNameContains: "Stop"
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

// End of file, nothing should follow
