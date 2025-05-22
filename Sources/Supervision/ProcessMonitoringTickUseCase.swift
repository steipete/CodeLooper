import AppKit
import AXorcistLib
import Combine
import Defaults
import Foundation
import OSLog
import SwiftUI // For potential future UI-related models if necessary, but primarily for @MainActor

@MainActor
class ProcessMonitoringTickUseCase {
    private let logger: Logger
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
        parentLogger: Logger
    ) {
        self.pid = pid
        self.currentInfo = currentInfo
        self.runningApp = runningApp
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.interventionEngine = interventionEngine
        let subsystem = Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper"
        self.logger = Logger(subsystem: subsystem, category: "ProcessMonitoringTickUseCase_PID_\(pid)")
        self.logger.info("Initialized for PID \(pid)")
    }

    /// Executes the monitoring logic for the single PID.
    /// - Returns: A tuple containing the new status, status message, and a boolean indicating if processing for this PID should stop for the current tick.
    func execute() async -> (newStatus: CursorInstanceStatus, newStatusMessage: String, shouldStopProcessingPID: Bool) {
        self.logger.debug("Executing monitoring tick for PID \(self.pid). Current status: \(String(describing: self.currentInfo.status))")
        await self.sessionLogger.log(level: .debug, message: "Executing monitoring tick for Cursor instance (PID: \(self.pid)). Current status: \(String(describing: self.currentInfo.status))", pid: self.pid)

        var newStatus: CursorInstanceStatus = self.currentInfo.status
        var newStatusMessage: String = self.currentInfo.statusMessage

        if self.instanceStateManager.isManuallyPaused(pid: self.pid) {
            self.logger.debug("Skipping PID \(self.pid) - manually paused")
            return (CursorInstanceStatus.paused, "Manually Paused", true)
        }

        // Note: runningApp is passed in and assumed valid for this tick instance of the use case.
        // The check for termination before creating the use case instance is handled by CursorMonitor.

        if let observationInfo = self.instanceStateManager.getPendingObservation(for: self.pid) {
            if Date().timeIntervalSince(observationInfo.startTime) > Defaults[.postInterventionObservationWindowSeconds] {
                let currentInterventionCount = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
                if currentInterventionCount > 0 && currentInterventionCount >= observationInfo.initialInterventionCountWhenObservationStarted {
                    self.instanceStateManager.incrementConsecutiveRecoveryFailures(for: self.pid)
                    self.logger.info("PID \(self.pid): Post-intervention observation window ended without positive activity. Consecutive failures: \(self.instanceStateManager.getConsecutiveRecoveryFailures(for: self.pid))")
                    await self.sessionLogger.log(level: .warning, message: "Post-intervention observation window ended without positive activity. Consecutive failures incremented.", pid: self.pid)
                }
                self.instanceStateManager.clearPendingObservation(for: self.pid)
            }
        }

        if case .unrecoverable(let actualReason) = self.currentInfo.status {
            self.logger.warning("PID \(self.pid) is in unrecoverable state: \(actualReason). Skipping further checks this tick.")
            newStatus = .unrecoverable(reason: actualReason)
            newStatusMessage = "Unrecoverable: \(actualReason)"
            return (newStatus, newStatusMessage, true)
        }
        if case .paused = self.currentInfo.status, self.currentInfo.statusMessage.contains("Intervention Limit Reached") {
            self.logger.info("PID \(self.pid) is paused (intervention limit). Skipping further checks this tick.")
            newStatus = .paused
            newStatusMessage = "Paused (Intervention Limit Reached)"
            return (newStatus, newStatusMessage, true)
        }

        let interventionType = await self.interventionEngine.determineInterventionType(for: self.pid, runningApp: self.runningApp)

        if interventionType == .noInterventionNeeded || interventionType == .positiveWorkingState {
            self.logger.debug("PID \(self.pid): Intervention type is \(String(describing: interventionType.rawValue)). Assuming running okay or positive activity.")
            if case .error = self.currentInfo.status {
                newStatus = .idle
                newStatusMessage = "Running normally after error."
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
                await self.sessionLogger.log(level: .info, message: "PID \(self.pid) appears to be running normally after prior issue.", pid: self.pid)
            } else if self.currentInfo.status.isRecovering() {
                newStatus = .idle
                newStatusMessage = "Running normally after recovery."
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
                await self.sessionLogger.log(level: .info, message: "PID \(self.pid) appears to be running normally after recovery attempt.", pid: self.pid)
            } else if case .paused = self.currentInfo.status {
                newStatus = .idle
                newStatusMessage = "Running normally after pause."
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
                await self.sessionLogger.log(level: .info, message: "PID \(self.pid) appears to be running normally after being paused.", pid: self.pid)
            } else if self.currentInfo.status == .unknown {
                newStatus = .idle
                newStatusMessage = "Status now Idle."
            } else if interventionType == .positiveWorkingState {
                newStatus = .working(detail: "Positive activity detected")
                newStatusMessage = "Working"
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
            }
            return (newStatus, newStatusMessage, false)
        }

        self.logger.info("PID \(self.pid): Determined intervention type: \(String(describing: interventionType.rawValue))")
        await self.sessionLogger.log(level: .info, message: "PID \(self.pid): Determined intervention type: \(String(describing: interventionType.rawValue))", pid: self.pid)

        switch interventionType {
        case .connectionIssue:
            let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
            newStatus = .recovering(type: .connection, attempt: currentAttempts)
            newStatusMessage = "Attempting to recover from connection issue..."
            let recoveryTried = await self.interventionEngine.attemptConnectionRecovery(for: self.pid, runningApp: self.runningApp)
            self.logger.info("Connection recovery attempt for PID \(self.pid) result: \(recoveryTried)")
            self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
            self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        case .generalError:
            let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
            self.logger.warning("PID \(self.pid) encountered general error (intervention type). Attempting generic stuck recovery.")
            newStatus = .recovering(type: .stuck, attempt: currentAttempts)
            newStatusMessage = "Attempting to recover from general error."
            let recoveryTried = await self.interventionEngine.attemptStuckStateRecovery(for: self.pid, runningApp: self.runningApp)
            self.logger.info("General error (stuck state) recovery attempt for PID \(self.pid) result: \(recoveryTried)")
            self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
            self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        case .automatedRecovery:
            let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
            self.logger.info("PID \(self.pid): InterventionType .automatedRecovery. Attempting stuck recovery.")
            newStatus = .recovering(type: .stuck, attempt: currentAttempts)
            newStatusMessage = "Performing automated recovery (Stuck)..."
            let recoveryTried = await self.interventionEngine.attemptStuckStateRecovery(for: self.pid, runningApp: self.runningApp)
            self.logger.info("Automated recovery (stuck state) attempt for PID \(self.pid) result: \(recoveryTried)")
            self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
            self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        case .unknown, .positiveWorkingState, .sidebarActivityDetected, .unrecoverableError, .manualPause, .interventionLimitReached, .awaitingAction, .monitoringPaused, .processNotRunning, .noInterventionNeeded:
            self.logger.debug("PID \(self.pid): Intervention type \(String(describing: interventionType.rawValue)) was not an actionable type for this switch. Current Status: \(String(describing: self.currentInfo.status))")
            if self.currentInfo.status.isRecovering() || (self.currentInfo.status == .paused) {
                newStatus = .idle; newStatusMessage = "Idle after \(String(describing: interventionType.rawValue))"
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
            } else if case .error = self.currentInfo.status {
                newStatus = .idle; newStatusMessage = "Idle after error and \(String(describing: interventionType.rawValue))"
                self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
                self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
                self.instanceStateManager.clearPendingObservation(for: self.pid)
            }
        }

        if self.instanceStateManager.getAutomaticInterventions(for: self.pid) >= Defaults[.maxInterventionsBeforePause] {
            newStatus = .paused
            newStatusMessage = "Paused (Intervention Limit Reached)"
            self.logger.warning("PID \(self.pid) reached max interventions (\(Defaults[.maxInterventionsBeforePause])). Pausing automated interventions for this instance.")
            await self.sessionLogger.log(level: .warning, message: "Reached max interventions. Pausing automated interventions for this instance.", pid: self.pid)
            if Defaults[.sendNotificationOnMaxInterventions] {
                await UserNotificationManager.shared.sendNotification(
                    identifier: "max_interventions_\(self.pid)",
                    title: "CodeLooper: Intervention Limit",
                    body: "Cursor instance (PID: \(self.pid)) has reached the maximum number of automated interventions and is now paused.",
                    soundName: Defaults[.notificationSoundName],
                    categoryIdentifier: nil,
                    userInfo: nil
                )
            }
        }

        if self.instanceStateManager.getConsecutiveRecoveryFailures(for: self.pid) >= Defaults[.maxConsecutiveRecoveryFailures] {
            newStatus = .unrecoverable(reason: "Max consecutive recovery failures reached.")
            newStatusMessage = "Unrecoverable: Max consecutive recovery failures reached (\(Defaults[.maxConsecutiveRecoveryFailures]))"
            self.logger.error("PID \(self.pid) has reached max consecutive recovery failures (\(Defaults[.maxConsecutiveRecoveryFailures])). Marking as unrecoverable.")
            await self.sessionLogger.log(level: .error, message: "Reached max consecutive recovery failures. Marking as unrecoverable.", pid: self.pid)
            if Defaults[.sendNotificationOnPersistentError] {
                await UserNotificationManager.shared.sendNotification(
                    identifier: "persistent_failure_\(self.pid)",
                    title: "CodeLooper: Persistent Failure",
                    body: "Cursor instance (PID: \(self.pid)) has encountered persistent recovery failures and is now marked unrecoverable.",
                    soundName: Defaults[.notificationSoundName],
                    categoryIdentifier: nil,
                    userInfo: nil
                )
            }
        }
        
        return (newStatus, newStatusMessage, false)
    }
} 