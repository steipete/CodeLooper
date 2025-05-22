import AppKit
import AXorcistLib
import Combine
import Defaults
import Foundation
import OSLog
import SwiftUI // For potential future UI-related models if necessary, but primarily for @MainActor

@MainActor
class ProcessMonitoringTickUseCase {
    private let logger: OSLog.Logger
    private let pid: pid_t
    private var currentInfo: CursorInstanceInfo // Use 'var' if it might be modified locally before returning
    private let runningApp: NSRunningApplication
    private let axorcist: AXorcistLib.AXorcist
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private let interventionEngine: CursorInterventionEngine

    init(
        pid: pid_t,
        currentInfo: CursorInstanceInfo,
        runningApp: NSRunningApplication,
        axorcist: AXorcistLib.AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager,
        interventionEngine: CursorInterventionEngine,
        parentLogger: OSLog.Logger
    ) {
        self.pid = pid
        self.currentInfo = currentInfo
        self.runningApp = runningApp
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.interventionEngine = interventionEngine
        self.logger = OSLog.Logger(subsystem: parentLogger.subsystem, category: "ProcessMonitoringTickUseCase_PID_\(pid)")
        self.logger.info("Initialized for PID \(pid)")
    }

    /// Executes the monitoring logic for the single PID.
    /// - Returns: A tuple containing the new status, status message, and a boolean indicating if processing for this PID should stop for the current tick.
    func execute() async -> (newStatus: CursorInstanceStatus, newStatusMessage: String, shouldStopProcessingPID: Bool) {
        logger.debug("Executing monitoring tick for PID \(pid). Current status: \(currentInfo.status)")
        await sessionLogger.log(level: .debug, message: "Executing monitoring tick for Cursor instance (PID: \(pid)). Current status: \(currentInfo.status)", pid: pid)

        var newStatus: CursorInstanceStatus = currentInfo.status
        var newStatusMessage: String = currentInfo.statusMessage

        if instanceStateManager.isManuallyPaused(pid: pid) {
            logger.debug("Skipping PID \(pid) - manually paused")
            return (CursorInstanceStatus.paused, "Manually Paused", true)
        }

        // Note: runningApp is passed in and assumed valid for this tick instance of the use case.
        // The check for termination before creating the use case instance is handled by CursorMonitor.

        if let observationInfo = instanceStateManager.getPendingObservation(for: pid) {
            if Date().timeIntervalSince(observationInfo.startTime) > Defaults[.postInterventionObservationWindowSeconds] {
                let currentInterventionCount = instanceStateManager.getAutomaticInterventions(for: pid)
                if currentInterventionCount > 0 && currentInterventionCount >= observationInfo.initialInterventionCountWhenObservationStarted {
                    instanceStateManager.incrementConsecutiveRecoveryFailures(for: pid)
                    logger.info("PID \(pid): Post-intervention observation window ended without positive activity. Consecutive failures: \(instanceStateManager.getConsecutiveRecoveryFailures(for: pid))")
                    await sessionLogger.log(level: .warning, message: "Post-intervention observation window ended without positive activity. Consecutive failures incremented.", pid: pid)
                }
                instanceStateManager.clearPendingObservation(for: pid)
            }
        }

        if case .unrecoverable(let actualReason) = currentInfo.status {
            logger.warning("PID \(pid) is in unrecoverable state: \(actualReason). Skipping further checks this tick.")
            newStatus = .unrecoverable(reason: actualReason)
            newStatusMessage = "Unrecoverable: \(actualReason)"
            return (newStatus, newStatusMessage, true)
        }
        if case .paused = currentInfo.status, currentInfo.statusMessage.contains("Intervention Limit Reached") {
            logger.info("PID \(pid) is paused (intervention limit). Skipping further checks this tick.")
            newStatus = .paused
            newStatusMessage = "Paused (Intervention Limit Reached)"
            return (newStatus, newStatusMessage, true)
        }

        let interventionType = await interventionEngine.determineInterventionType(for: pid, runningApp: runningApp)

        if interventionType == .noInterventionNeeded || interventionType == .positiveWorkingState {
            logger.debug("PID \(pid): Intervention type is \(interventionType.rawValue). Assuming running okay or positive activity.")
            if case .error = currentInfo.status {
                newStatus = .idle
                newStatusMessage = "Running normally after error."
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
                await sessionLogger.log(level: .info, message: "PID \(pid) appears to be running normally after prior issue.", pid: pid)
            } else if currentInfo.status.isRecovering() {
                newStatus = .idle
                newStatusMessage = "Running normally after recovery."
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
                await sessionLogger.log(level: .info, message: "PID \(pid) appears to be running normally after recovery attempt.", pid: pid)
            } else if case .paused = currentInfo.status {
                newStatus = .idle
                newStatusMessage = "Running normally after pause."
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
                await sessionLogger.log(level: .info, message: "PID \(pid) appears to be running normally after being paused.", pid: pid)
            } else if currentInfo.status == .unknown {
                newStatus = .idle
                newStatusMessage = "Status now Idle."
            } else if interventionType == .positiveWorkingState {
                newStatus = .working(detail: "Positive activity detected")
                newStatusMessage = "Working"
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
            }
            return (newStatus, newStatusMessage, false)
        }

        logger.info("PID \(pid): Determined intervention type: \(interventionType.rawValue)")
        await sessionLogger.log(level: .info, message: "PID \(pid): Determined intervention type: \(interventionType.rawValue)", pid: pid)

        switch interventionType {
        case .connectionIssue:
            let currentAttempts = instanceStateManager.getAutomaticInterventions(for: pid)
            newStatus = .recovering(type: .connection, attempt: currentAttempts)
            newStatusMessage = "Attempting to recover from connection issue..."
            await interventionEngine.attemptConnectionRecovery(for: pid, runningApp: runningApp)
            instanceStateManager.incrementAutomaticInterventions(for: pid)
            instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: currentAttempts)

        case .generalError:
            let currentAttempts = instanceStateManager.getAutomaticInterventions(for: pid)
            logger.warning("PID \(pid) encountered general error (intervention type). Attempting generic stuck recovery.")
            newStatus = .recovering(type: .stuck, attempt: currentAttempts)
            newStatusMessage = "Attempting to recover from general error."
            await interventionEngine.attemptStuckStateRecovery(for: pid, runningApp: runningApp)
            instanceStateManager.incrementAutomaticInterventions(for: pid)
            instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: currentAttempts)

        case .automatedRecovery:
            let currentAttempts = instanceStateManager.getAutomaticInterventions(for: pid)
            logger.info("PID \(pid): InterventionType .automatedRecovery. Attempting stuck recovery.")
            newStatus = .recovering(type: .stuck, attempt: currentAttempts)
            newStatusMessage = "Performing automated recovery (Stuck)..."
            await interventionEngine.attemptStuckStateRecovery(for: pid, runningApp: runningApp)
            instanceStateManager.incrementAutomaticInterventions(for: pid)
            instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: currentAttempts)

        case .unknown, .positiveWorkingState, .sidebarActivityDetected, .unrecoverableError, .manualPause, .interventionLimitReached, .awaitingAction, .monitoringPaused, .processNotRunning, .noInterventionNeeded:
            logger.debug("PID \(pid): Intervention type \(interventionType.rawValue) was not an actionable type for this switch. Current Status: \(currentInfo.status.debugDescription)")
            if currentInfo.status.isRecovering() || (currentInfo.status == .paused) {
                newStatus = .idle; newStatusMessage = "Idle after \(interventionType.rawValue)"
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
            } else if case .error = currentInfo.status {
                newStatus = .idle; newStatusMessage = "Idle after error and \(interventionType.rawValue)"
                instanceStateManager.resetAutomaticInterventions(for: pid)
                instanceStateManager.resetConsecutiveRecoveryFailures(for: pid)
                instanceStateManager.clearPendingObservation(for: pid)
            }
        }

        if instanceStateManager.getAutomaticInterventions(for: pid) >= Defaults[.maxInterventionsBeforePause] {
            newStatus = .paused
            newStatusMessage = "Paused (Intervention Limit Reached)"
            logger.warning("PID \(pid) reached max interventions (\(Defaults[.maxInterventionsBeforePause])). Pausing automated interventions for this instance.")
            await sessionLogger.log(level: .warning, message: "Reached max interventions. Pausing automated interventions for this instance.", pid: pid)
            if Defaults[.sendNotificationOnMaxInterventions] {
                await UserNotificationManager.shared.sendNotification(
                    identifier: "max_interventions_\(pid)",
                    title: "CodeLooper: Intervention Limit",
                    body: "Cursor instance (PID: \(pid)) has reached the maximum number of automated interventions and is now paused.",
                    soundName: Defaults[.notificationSoundName],
                    categoryIdentifier: nil,
                    userInfo: nil
                )
            }
        }

        if instanceStateManager.getConsecutiveRecoveryFailures(for: pid) >= Defaults[.maxConsecutiveRecoveryFailures] {
            newStatus = .unrecoverable(reason: "Max consecutive recovery failures reached.")
            newStatusMessage = "Unrecoverable: Max consecutive recovery failures reached (\(Defaults[.maxConsecutiveRecoveryFailures]))"
            logger.error("PID \(pid) has reached max consecutive recovery failures (\(Defaults[.maxConsecutiveRecoveryFailures])). Marking as unrecoverable.")
            await sessionLogger.log(level: .error, message: "Reached max consecutive recovery failures. Marking as unrecoverable.", pid: pid)
            if Defaults[.sendNotificationOnPersistentError] {
                await UserNotificationManager.shared.sendNotification(
                    identifier: "persistent_failure_\(pid)",
                    title: "CodeLooper: Persistent Failure",
                    body: "Cursor instance (PID: \(pid)) has encountered persistent recovery failures and is now marked unrecoverable.",
                    soundName: Defaults[.notificationSoundName],
                    categoryIdentifier: nil,
                    userInfo: nil
                )
            }
        }
        
        return (newStatus, newStatusMessage, false)
    }
} 