import AppKit
import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
import SwiftUI // For potential future UI-related models if necessary, but primarily for @MainActor

/// Handles a single monitoring tick for a Cursor process, checking its state and triggering interventions.
///
/// This use case class encapsulates the logic for:
/// - Checking if a Cursor process is still alive and responsive
/// - Querying the current state through accessibility APIs
/// - Detecting various error conditions and stuck states
/// - Triggering appropriate interventions when issues are detected
/// - Updating instance state and statistics
///
/// Each tick represents one monitoring cycle for a specific Cursor instance,
/// designed to be executed periodically by the monitoring service.
@MainActor
class ProcessMonitoringTickUseCase {
    // MARK: Lifecycle

    // private let appMonitor: AppMonitor // Commented out

    init(
        pid: pid_t,
        currentInfo: CursorInstanceInfo,
        runningApp: NSRunningApplication,
        axorcist: AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager,
        interventionEngine: CursorInterventionEngine,
        // appMonitor: AppMonitor, // Commented out
        parentLogger _: Diagnostics.Logger
    ) {
        self.pid = pid
        self.currentInfo = currentInfo
        self.runningApp = runningApp
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.interventionEngine = interventionEngine
        // self.appMonitor = appMonitor // Commented out
        self.logger = Diagnostics.Logger(category: .supervision)
        self.logger.info("Initialized for PID \(pid)")
    }

    // MARK: Internal

    /// Executes the monitoring logic for the single PID.
    /// - Returns: A tuple containing the new status, status message, and a boolean indicating if processing for this
    /// PID should stop for the current tick.
    func execute() async -> (newStatus: CursorInstanceStatus, newStatusMessage: String, shouldStopProcessingPID: Bool) {
        logExecutionStart()

        var newStatus: CursorInstanceStatus = self.currentInfo.status
        var newStatusMessage: String = self.currentInfo.statusMessage

        // Check if manually paused
        if let pauseResult = checkManualPauseStatus() {
            return pauseResult
        }

        // Handle pending observations
        handlePendingObservations()

        // Check for unrecoverable or paused states
        if let skipResult = checkUnrecoverableOrPausedStates(
            currentStatus: &newStatus,
            statusMessage: &newStatusMessage
        ) {
            return skipResult
        }

        // Determine intervention type and handle accordingly
        return await handleInterventionFlow(
            currentStatus: newStatus,
            statusMessage: newStatusMessage
        )
    }

    private func logExecutionStart() {
        self.logger
            .debug(
                "Executing monitoring tick for PID \(self.pid). Current status: \(String(describing: self.currentInfo.status))"
            )
        self.sessionLogger.log(
            level: .debug,
            message: "Executing monitoring tick for Cursor instance (PID: \(self.pid)). " +
                "Current status: \(String(describing: self.currentInfo.status))",
            pid: self.pid
        )
    }

    private func checkManualPauseStatus() -> (CursorInstanceStatus, String, Bool)? {
        if self.instanceStateManager.isManuallyPaused(pid: self.pid) {
            self.logger.debug("Skipping PID \(self.pid) - manually paused")
            return (CursorInstanceStatus.paused, "Manually Paused", true)
        }
        return nil
    }

    private func handlePendingObservations() {
        guard let observationInfo = self.instanceStateManager.getPendingObservation(for: self.pid) else {
            return
        }

        let observationWindow = InterventionConstants.postInterventionObservationWindow
        if Date().timeIntervalSince(observationInfo.startTime) > observationWindow {
            let currentInterventionCount = self.instanceStateManager.getAutomaticInterventions(for: self.pid)

            if currentInterventionCount > 0,
               currentInterventionCount >= observationInfo.initialInterventionCountWhenObservationStarted
            {
                self.instanceStateManager.incrementConsecutiveRecoveryFailures(for: self.pid)

                let consecutiveFailures = self.instanceStateManager.getConsecutiveRecoveryFailures(for: self.pid)
                let logMsg = "PID \(self.pid): Post-intervention observation ended. Failures: \(consecutiveFailures)"
                self.logger.info("\(logMsg)")
                self.sessionLogger.log(
                    level: .warning,
                    message: "Post-intervention observation window ended without positive activity. " +
                        "Consecutive failures incremented.",
                    pid: self.pid
                )
            }
            self.instanceStateManager.clearPendingObservation(for: self.pid)
        }
    }

    private func checkUnrecoverableOrPausedStates(
        currentStatus: inout CursorInstanceStatus,
        statusMessage: inout String
    ) -> (CursorInstanceStatus, String, Bool)? {
        if case let .unrecoverable(actualReason) = self.currentInfo.status {
            self.logger.warning(
                "PID \(self.pid) is in unrecoverable state: \(actualReason). Skipping further checks this tick."
            )
            return (currentStatus, statusMessage, true)
        }

        if currentStatus == .paused,
           self.currentInfo.statusMessage.contains("Intervention Limit Reached")
        {
            self.logger.info("PID \(self.pid) is paused (intervention limit). Skipping further checks this tick.")
            currentStatus = .paused
            statusMessage = "Paused (Intervention Limit Reached)"
            return (currentStatus, statusMessage, true)
        }

        return nil
    }

    private func handleInterventionFlow(
        currentStatus: CursorInstanceStatus,
        statusMessage: String
    ) async -> (CursorInstanceStatus, String, Bool) {
        let newStatus = currentStatus
        let newStatusMessage = statusMessage

        let interventionType = await self.interventionEngine.determineInterventionType(
            for: self.pid,
            runningApp: self.runningApp
        )

        if interventionType == .noInterventionNeeded || interventionType == .positiveWorkingState {
            return handlePositiveState(
                interventionType: interventionType,
                currentStatus: newStatus,
                statusMessage: newStatusMessage
            )
        }

        return await handleInterventionRequired(
            interventionType: interventionType,
            currentStatus: newStatus,
            statusMessage: newStatusMessage
        )
    }

    private func handlePositiveState(
        interventionType: CursorInterventionEngine.InterventionType,
        currentStatus: CursorInstanceStatus,
        statusMessage: String
    ) -> (CursorInstanceStatus, String, Bool) {
        var newStatus = currentStatus
        var newStatusMessage = statusMessage

        self.logger.debug("""
            PID \(self.pid): Intervention type is \(String(describing: interventionType.rawValue)). \
            Assuming running okay or positive activity.
            """)

        if case .error = self.currentInfo.status {
            newStatus = .idle
            newStatusMessage = "Running normally after error."
            resetInstanceState()
            self.sessionLogger.log(
                level: .info,
                message: "PID \(self.pid) appears to be running normally after prior issue.",
                pid: self.pid
            )
        } else if self.currentInfo.status.isRecovering() {
            newStatus = .idle
            newStatusMessage = "Running normally after recovery."
            resetInstanceState()
            self.sessionLogger.log(
                level: .info,
                message: "PID \(self.pid) appears to be running normally after recovery attempt.",
                pid: self.pid
            )
        } else if case .paused = self.currentInfo.status {
            newStatus = .idle
            newStatusMessage = "Running normally after pause."
            resetInstanceState()
            self.sessionLogger.log(
                level: .info,
                message: "PID \(self.pid) appears to be running normally after being paused.",
                pid: self.pid
            )
        } else if self.currentInfo.status == .unknown {
            newStatus = .idle
            newStatusMessage = "Status now Idle."
        } else if interventionType == .positiveWorkingState {
            newStatus = .working(detail: "Positive activity detected")
            newStatusMessage = "Working"
            resetInstanceState()
        }

        return (newStatus, newStatusMessage, false)
    }

    private func resetInstanceState() {
        self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
        self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
        self.instanceStateManager.clearPendingObservation(for: self.pid)
    }

    private func handleInterventionRequired(
        interventionType: CursorInterventionEngine.InterventionType,
        currentStatus: CursorInstanceStatus,
        statusMessage: String
    ) async -> (CursorInstanceStatus, String, Bool) {
        var newStatus = currentStatus
        var newStatusMessage = statusMessage

        logInterventionType(interventionType)

        // Handle specific intervention type
        (newStatus, newStatusMessage) = await processInterventionType(
            interventionType,
            currentStatus: newStatus,
            statusMessage: newStatusMessage
        )

        // Check intervention limits
        if let limitResult = await checkInterventionLimits(currentStatus: newStatus) {
            newStatus = limitResult.status
            newStatusMessage = limitResult.message
        }

        // Check recovery failure limits
        if let failureResult = await checkRecoveryFailureLimits(currentStatus: newStatus) {
            newStatus = failureResult.status
            newStatusMessage = failureResult.message
        }

        return (newStatus, newStatusMessage, false)
    }

    private func logInterventionType(_ interventionType: CursorInterventionEngine.InterventionType) {
        self.logger.info("PID \(self.pid): Determined intervention type: \(String(describing: interventionType.rawValue))")
        self.sessionLogger.log(
            level: .info,
            message: "PID \(self.pid): Determined intervention type: \(String(describing: interventionType.rawValue))",
            pid: self.pid
        )
    }

    private func processInterventionType(
        _ interventionType: CursorInterventionEngine.InterventionType,
        currentStatus: CursorInstanceStatus,
        statusMessage: String
    ) async -> (CursorInstanceStatus, String) {
        switch interventionType {
        case .connectionIssue:
            await handleConnectionIssue()

        case .generalError:
            await handleGeneralError()

        case .automatedRecovery:
            await handleAutomatedRecovery()

        case .unknown, .positiveWorkingState, .sidebarActivityDetected, .unrecoverableError, .manualPause,
             .interventionLimitReached, .awaitingAction, .monitoringPaused, .processNotRunning, .noInterventionNeeded:
            handleNonActionableIntervention(interventionType, currentStatus: currentStatus, statusMessage: statusMessage)
        }
    }

    private func handleConnectionIssue() async -> (CursorInstanceStatus, String) {
        let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
        let newStatus = CursorInstanceStatus.recovering(type: .connection, attempt: currentAttempts)
        let newStatusMessage = "Attempting to recover from connection issue..."

        let recoveryTried = await self.interventionEngine.attemptConnectionRecovery(
            for: self.pid,
            runningApp: self.runningApp
        )

        self.logger.info("Connection recovery attempt for PID \(self.pid) result: \(recoveryTried)")
        self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
        self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        return (newStatus, newStatusMessage)
    }

    private func handleGeneralError() async -> (CursorInstanceStatus, String) {
        let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
        self.logger.warning("PID \(self.pid) encountered general error (intervention type). Attempting generic stuck recovery.")

        let newStatus = CursorInstanceStatus.recovering(type: .stuck, attempt: currentAttempts)
        let newStatusMessage = "Attempting to recover from general error."

        let recoveryTried = await self.interventionEngine.attemptStuckStateRecovery(
            for: self.pid,
            runningApp: self.runningApp
        )

        self.logger.info("General error (stuck state) recovery attempt for PID \(self.pid) result: \(recoveryTried)")
        self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
        self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        return (newStatus, newStatusMessage)
    }

    private func handleAutomatedRecovery() async -> (CursorInstanceStatus, String) {
        let currentAttempts = self.instanceStateManager.getAutomaticInterventions(for: self.pid)
        self.logger.info("PID \(self.pid): InterventionType .automatedRecovery. Attempting stuck recovery.")

        let newStatus = CursorInstanceStatus.recovering(type: .stuck, attempt: currentAttempts)
        let newStatusMessage = "Performing automated recovery (Stuck)..."

        let recoveryTried = await self.interventionEngine.attemptStuckStateRecovery(
            for: self.pid,
            runningApp: self.runningApp
        )

        self.logger.info("Automated recovery (stuck state) attempt for PID \(self.pid) result: \(recoveryTried)")
        self.instanceStateManager.incrementAutomaticInterventions(for: self.pid)
        self.instanceStateManager.startPendingObservation(for: self.pid, initialInterventionCount: currentAttempts)

        return (newStatus, newStatusMessage)
    }

    private func handleNonActionableIntervention(
        _ interventionType: CursorInterventionEngine.InterventionType,
        currentStatus: CursorInstanceStatus,
        statusMessage: String
    ) -> (CursorInstanceStatus, String) {
        let interventionStr = String(describing: interventionType.rawValue)
        let statusStr = String(describing: self.currentInfo.status)
        self.logger.debug(
            "PID \(self.pid): Intervention type \(interventionStr) was not actionable. Status: \(statusStr)"
        )

        if self.currentInfo.status.isRecovering() || (self.currentInfo.status == .paused) {
            resetInterventionState()
            return (.idle, "Idle after \(String(describing: interventionType.rawValue))")
        } else if case .error = self.currentInfo.status {
            resetInterventionState()
            return (.idle, "Idle after error and \(String(describing: interventionType.rawValue))")
        }

        return (currentStatus, statusMessage)
    }

    private func resetInterventionState() {
        self.instanceStateManager.resetAutomaticInterventions(for: self.pid)
        self.instanceStateManager.resetConsecutiveRecoveryFailures(for: self.pid)
        self.instanceStateManager.clearPendingObservation(for: self.pid)
    }

    private func checkInterventionLimits(currentStatus _: CursorInstanceStatus) async -> (
        status: CursorInstanceStatus,
        message: String
    )? {
        guard self.instanceStateManager.getAutomaticInterventions(for: self.pid) >= Defaults[.maxInterventionsBeforePause] else {
            return nil
        }

        let maxInterventions = Defaults[.maxInterventionsBeforePause]
        self.logger.warning(
            "PID \(self.pid) reached max interventions (\(maxInterventions)). Pausing automated interventions."
        )
        self.sessionLogger.log(
            level: .warning,
            message: "Reached max interventions. Pausing automated interventions for this instance.",
            pid: self.pid
        )

        if Defaults[.sendNotificationOnMaxInterventions] {
            do {
                try await UserNotificationManager.shared.sendNotification(
                    title: "CodeLooper: Intervention Limit",
                    body: "Cursor instance (PID: \(self.pid)) has reached the maximum number of automated interventions and is now paused.",
                    identifier: "max_interventions_\(self.pid)"
                )
            } catch {
                logger.error("Failed to send max interventions notification: \(error)")
            }
        }

        return (status: .paused, message: "Paused (Intervention Limit Reached)")
    }

    private func checkRecoveryFailureLimits(currentStatus _: CursorInstanceStatus) async -> (
        status: CursorInstanceStatus,
        message: String
    )? {
        guard self.instanceStateManager.getConsecutiveRecoveryFailures(for: self.pid) >= InterventionConstants.maxConsecutiveRecoveryFailures else {
            return nil
        }

        self.logger.error("""
            PID \(self.pid) has reached max consecutive recovery failures \
            (\(InterventionConstants.maxConsecutiveRecoveryFailures)). Marking as unrecoverable.
            """)
        self.sessionLogger.log(
            level: .error,
            message: "Reached max consecutive recovery failures. Marking as unrecoverable.",
            pid: self.pid
        )

        if true { // Always send notification on persistent error
            do {
                try await UserNotificationManager.shared.sendNotification(
                    title: "CodeLooper: Persistent Failure",
                    body: "Cursor instance (PID: \(self.pid)) has encountered persistent recovery failures and is now marked unrecoverable.",
                    identifier: "persistent_failure_\(self.pid)"
                )
            } catch {
                logger.error("Failed to send persistent failure notification: \(error)")
            }
        }

        return (
            status: .unrecoverable(reason: "Max consecutive recovery failures reached."),
            message: "Unrecoverable: Max consecutive recovery failures reached (\(InterventionConstants.maxConsecutiveRecoveryFailures))"
        )
    }

    // MARK: Private

    private let logger: Diagnostics.Logger
    private let pid: pid_t
    private var currentInfo: CursorInstanceInfo // Use 'var' if it might be modified locally before returning
    private let runningApp: NSRunningApplication
    private let axorcist: AXorcist
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private let interventionEngine: CursorInterventionEngine
}
