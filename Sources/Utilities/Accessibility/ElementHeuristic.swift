import AXorcistLib
import Foundation

// Define LocatorType based on the string keys used in LocatorManager
// This makes it more type-safe when mapping heuristics.
public enum LocatorType: String, CaseIterable {
    case generatingIndicatorText
    case sidebarActivityArea
    case errorMessagePopup
    case stopGeneratingButton
    case connectionErrorIndicator
    case resumeConnectionButton
    case forceStopResumeLink
    case mainInputField
    // Add other locator types as they are defined and used
}


/// Protocol for a dynamic discovery heuristic for a specific type of UI element.
protocol AXElementHeuristic {
    /// The type of locator this heuristic tries to discover.
    var locatorType: LocatorType { get }

    /// Attempts to discover the element and return a working Locator for it.
    /// - Parameters:
    ///   - pid: The process identifier of the target application.
    ///   - axorcist: An instance of AXorcist to perform queries.
    /// - Returns: An `AXorcistLib.Locator` if the element is successfully found and a locator can be constructed, otherwise `nil`.
    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator?
}

// End of file, nothing should follow