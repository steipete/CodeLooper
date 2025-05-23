import AXorcistLib
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
    var defaultLocator: AXorcistLib.Locator? {
        switch self {
        case .connectionErrorIndicator:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXStaticText", "computed_name_contains_any": "offline,network error,connection failed"],
                root_element_path_hint: nil,
                requireAction: nil
            )
        case .errorMessagePopup:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXWindow", "subrole": "AXDialog", "description_contains_any": "error,failed,unable"],
                root_element_path_hint: nil,
                requireAction: nil
            )
        case .forceStopResumeLink:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXLink", "title_contains_any": "Force Stop,Resume"],
                root_element_path_hint: nil,
                requireAction: "AXPressAction"
            )
        case .mainInputField:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXTextArea", "placeholder_value_contains": "message"],
                root_element_path_hint: nil,
                requireAction: nil
            )
        case .resumeConnectionButton:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXButton", "title_contains_any": "Resume,Try Again,Reload"],
                root_element_path_hint: nil,
                requireAction: "AXPressAction"
            )
        case .generatingIndicatorText:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXStaticText"],
                root_element_path_hint: nil,
                requireAction: nil,
                computed_name_contains: "generating"
            )
        case .sidebarActivityArea:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXScrollArea"],
                root_element_path_hint: nil,
                requireAction: nil
            )
        case .stopGeneratingButton:
            return AXorcistLib.Locator(
                match_all: false,
                criteria: ["role": "AXButton"],
                root_element_path_hint: nil,
                requireAction: nil,
                computed_name_contains: "Stop"
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
    /// - Returns: An `AXorcistLib.Locator` if discovery is successful, otherwise `nil`.
    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator?
}

// End of file, nothing should follow