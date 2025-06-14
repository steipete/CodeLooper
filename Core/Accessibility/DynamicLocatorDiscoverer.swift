@preconcurrency import AXorcist
import Diagnostics
import Foundation

/// Dynamically discovers accessibility locators for UI elements when default locators fail.
///
/// This class implements a heuristic-based approach to finding UI elements in Cursor:
/// - Maintains a collection of element-specific heuristics for different UI components
/// - Attempts discovery using multiple strategies per element type
/// - Returns the most appropriate locator when an element is found
/// - Designed to adapt to UI changes in Cursor without code modifications
///
/// The discoverer is crucial for maintaining functionality when Cursor updates
/// change the accessibility hierarchy or element properties.
@MainActor
class DynamicLocatorDiscoverer {
    // MARK: Lifecycle

    init() {
        // Initialize with all known heuristics, mapped to their types.
        // Each array is ordered by preference - more specific/reliable heuristics first.
        self.heuristics = [
            .generatingIndicatorText: [
                GeneratingIndicatorTextHeuristic(),
            ],
            .sidebarActivityArea: [
                SidebarActivityAreaHeuristic(),
            ],
            .errorMessagePopup: [
                ErrorMessagePopupHeuristic(),
            ],
            .stopGeneratingButton: [
                StopGeneratingButtonHeuristic(),
            ],
            .connectionErrorIndicator: [
                ConnectionErrorIndicatorHeuristic(),
            ],
            .resumeConnectionButton: [
                ResumeConnectionButtonHeuristic(),
            ],
            .forceStopResumeLink: [
                ForceStopResumeLinkHeuristic(),
            ],
            .mainInputField: [
                MainInputFieldHeuristic(),
            ],
        ]
    }

    // MARK: Internal

    /// Attempts to discover a locator for the given element type using registered heuristics.
    /// - Parameters:
    ///   - type: The `LocatorType` of the element to discover.
    ///   - pid: The process identifier of the target application.
    ///   - axorcist: An instance of `AXorcist` to perform queries.
    /// - Returns: An `AXorcist.Locator` if discovery is successful, otherwise `nil`.
    func discover(type: LocatorType, for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        guard let specificHeuristics = heuristics[type], !specificHeuristics.isEmpty else {
            SessionLogger.shared.log(
                level: .debug,
                message: "No dynamic discovery heuristics registered for LocatorType: \(type.rawValue)",
                pid: pid
            )
            return nil
        }

        SessionLogger.shared.log(
            level: .info,
            message: "Attempting dynamic discovery for LocatorType: \(type.rawValue) (PID: \(pid)) " +
                "using \(specificHeuristics.count) heuristic(s).",
            pid: pid
        )

        for heuristic in specificHeuristics {
            SessionLogger.shared.log(
                level: .debug,
                message: "Trying heuristic: \(String(describing: heuristic)) for LocatorType: \(type.rawValue)",
                pid: pid
            )
            if let discoveredLocator = await heuristic.discover(for: pid, axorcist: axorcist) {
                SessionLogger.shared.log(
                    level: .info,
                    message: "Dynamic discovery successful for LocatorType: \(type.rawValue) " +
                        "using heuristic: \(String(describing: heuristic)). " +
                        "Locator: \(String(describing: discoveredLocator))",
                    pid: pid
                )
                return discoveredLocator
            }
        }

        SessionLogger.shared.log(
            level: .warning,
            message: "Dynamic discovery failed for LocatorType: \(type.rawValue) " +
                "after trying all registered heuristics.",
            pid: pid
        )
        return nil
    }

    // MARK: Private

    // This maps a locator type to an ordered list of heuristics to try.
    // The order matters: heuristics are tried sequentially.
    private let heuristics: [LocatorType: [AXElementHeuristic]]
}
