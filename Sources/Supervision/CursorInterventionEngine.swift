import AppKit // For NSRunningApplication, AXUIElement etc.
import ApplicationServices // Added for kAX constants
import AXorcist
import Combine
import Defaults
import Diagnostics // Add this import
import Foundation
import SwiftUI // For ObservableObject

@MainActor
public class CursorInterventionEngine: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    public init(
        monitor: CursorMonitor,
        axorcist: AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager
    ) {
        self.monitor = monitor
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.stateChecker = InterventionStateChecker(
            axorcist: axorcist,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager,
            monitor: monitor
        )
        self.recoveryHandler = InterventionRecoveryHandler(
            axorcist: axorcist,
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )
        self.logger.info("CursorInterventionEngine initialized.")
    }

    // MARK: Public

    // MARK: - Enums

    public enum InterventionType: String, CaseIterable, Codable, Sendable {
        case unknown = "Unknown"
        case noInterventionNeeded = "No Intervention Needed"
        case positiveWorkingState = "Positive Working State"
        case sidebarActivityDetected = "Sidebar Activity Detected"
        case connectionIssue = "Connection Issue"
        case generalError = "General Error"
        case unrecoverableError = "Unrecoverable Error"
        case manualPause = "Manually Paused"
        case automatedRecovery = "Automated Recovery Attempt"
        case interventionLimitReached = "Intervention Limit Reached"
        case awaitingAction = "Awaiting Action"
        case monitoringPaused = "Monitoring Paused Global"
        case processNotRunning = "Process Not Running"

        // MARK: Internal

        var displayText: String {
            rawValue
        }
    }

    // MARK: - Core Intervention Logic

    // Placeholder for methods like:
    // func determineInterventionType(for pid: pid_t, runningApp: NSRunningApplication) async -> InterventionType?
    // func checkForPositiveWorkingState(for pid: pid_t, using element: AXUIElement?) async -> Bool
    // ... and other related methods ...

    public func determineInterventionType(for pid: pid_t,
                                          runningApp _: NSRunningApplication) async -> InterventionType
    {
        // Check basic states first
        if let basicState = stateChecker.checkBasicStates(for: pid) {
            return basicState
        }

        // Perform AX queries to determine state
        if let axState = await stateChecker.performAXQueries(for: pid) {
            return axState
        }

        // Check for stuck timeout
        if let timeoutState = stateChecker.checkStuckTimeout(for: pid) {
            return timeoutState
        }

        return .noInterventionNeeded
    }

    // MARK: - Intervention Actions

    public func nudgeInstance(pid: pid_t, app: NSRunningApplication) async -> Bool {
        await recoveryHandler.nudgeInstance(pid: pid, app: app)
    }

    public func attemptConnectionRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        await recoveryHandler.attemptConnectionRecovery(for: pid, runningApp: runningApp)
    }

    public func attemptStuckStateRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        await recoveryHandler.attemptStuckStateRecovery(for: pid, runningApp: runningApp)
    }

    public func attemptGeneralRecoveryByNudge(pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        await recoveryHandler.attemptGeneralRecoveryByNudge(pid: pid, runningApp: runningApp)
    }

    // MARK: Internal

    weak var monitor: CursorMonitor?

    // MARK: Private

    private let logger = Diagnostics.Logger(category: .interventionEngine)
    private let axorcist: AXorcist
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private let stateChecker: InterventionStateChecker
    private let recoveryHandler: InterventionRecoveryHandler
}
