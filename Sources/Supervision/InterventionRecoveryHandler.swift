import AppKit
import AXorcist
import Diagnostics
import Foundation

@MainActor
class InterventionRecoveryHandler {
    // MARK: Lifecycle

    init(
        axorcist: AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager
    ) {
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
    }

    // MARK: Internal

    func nudgeInstance(pid: pid_t, app _: NSRunningApplication) async -> Bool {
        self.logger
            .info("Attempting to nudge Cursor instance (PID: \(String(describing: pid))) via InterventionEngine")
        self.sessionLogger.log(level: .info, message: "Attempting to nudge instance via engine.", pid: pid)

        // Step 1: Click stop button
        guard await clickStopButton(for: pid) else {
            return false
        }

        // Wait a moment
        try? await Task.sleep(nanoseconds: UInt64(InterventionConstants.interventionActionDelay * 1_000_000_000))

        // Step 2: Click resume button
        guard await clickResumeButton(for: pid) else {
            return false
        }

        self.logger.info("PID \(String(describing: pid)): Successfully nudged instance (stop -> resume).")
        self.sessionLogger.log(level: .info, message: "Successfully nudged instance.", pid: pid)
        return true
    }

    func attemptConnectionRecovery(for pid: pid_t, runningApp _: NSRunningApplication) async -> Bool {
        self.logger.info("Attempting connection recovery for Cursor instance (PID: \(String(describing: pid)))")
        self.sessionLogger.log(level: .info, message: "Attempting connection recovery.", pid: pid)

        // Look for connection error links to click
        guard let connectionErrorLocator = await self.locatorManager.getLocator(
            for: .forceStopResumeLink,
            pid: pid
        ) else {
            self.logger.error("PID \(String(describing: pid)): Failed to get locator for forceStopResumeLink.")
            return false
        }

        let queryCommand = QueryCommand(
            appIdentifier: nil,
            locator: connectionErrorLocator,
            attributesToReturn: nil,
            maxDepthForSearch: 5
        )
        let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)

        guard (response.payload?.value) != nil else {
            self.logger
                .error("PID \(String(describing: pid)): No connection error link found. Falling back to nudge.")

            // Fallback to general nudge
            return await nudgeInstance(pid: pid, app: NSRunningApplication())
        }

        // Click the connection error link
        let clickAction = PerformActionCommand(
            appIdentifier: nil,
            locator: connectionErrorLocator,
            action: AXActionNames.kAXPressAction,
            value: nil,
            maxDepthForSearch: 5
        )
        let actionResponse = self.axorcist.handlePerformAction(command: clickAction)

        guard actionResponse.error == nil else {
            let errorMsg = String(describing: actionResponse.error?.message)
            self.logger
                .error(
                    "PID \(String(describing: pid)): Failed to click connection error link. Error: \(errorMsg)"
                )
            self.sessionLogger
                .log(
                    level: .error,
                    message: "Failed to click connection error link: \(errorMsg)",
                    pid: pid
                )
            return false
        }

        self.logger.info("PID \(String(describing: pid)): Successfully clicked connection recovery link.")
        self.sessionLogger.log(level: .info, message: "Successfully attempted connection recovery.", pid: pid)
        return true
    }

    func attemptStuckStateRecovery(for pid: pid_t, runningApp _: NSRunningApplication) async -> Bool {
        self.logger.info("Attempting stuck state recovery for Cursor instance (PID: \(String(describing: pid)))")
        self.sessionLogger.log(level: .info, message: "Attempting stuck state recovery.", pid: pid)

        // First, try to find and focus the main input field
        guard let mainInputLocator = await self.locatorManager.getLocator(for: .mainInputField, pid: pid) else {
            self.logger.error("PID \(String(describing: pid)): Failed to get locator for mainInputField.")
            return false
        }

        // Try to focus the input field
        let focusAction = PerformActionCommand(
            appIdentifier: nil,
            locator: mainInputLocator,
            action: AXActionNames.kAXRaiseAction,
            value: nil,
            maxDepthForSearch: 5
        )
        let focusResponse = self.axorcist.handlePerformAction(command: focusAction)

        if focusResponse.error != nil {
            self.logger
                .warning(
                    "PID \(String(describing: pid)): Failed to focus input field, trying click instead."
                )

            // Try clicking instead
            let clickAction = PerformActionCommand(
                appIdentifier: nil,
                locator: mainInputLocator,
                action: AXActionNames.kAXPressAction,
                value: nil,
                maxDepthForSearch: 5
            )
            let clickResponse = self.axorcist.handlePerformAction(command: clickAction)

            if clickResponse.error != nil {
                self.logger.error("PID \(String(describing: pid)): Failed to interact with input field.")
                return false
            }
        }

        self.logger.info("PID \(String(describing: pid)): Successfully focused/clicked main input field.")

        // Wait a moment before typing
        try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))

        // Type a space and backspace to trigger activity
        let typeSpaceAction = PerformActionCommand(
            appIdentifier: nil,
            locator: mainInputLocator,
            action: AXActionNames.kAXSetValueAction,
            value: AnyCodable(" "),
            maxDepthForSearch: 5
        )
        _ = self.axorcist.handlePerformAction(command: typeSpaceAction)

        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))

        // Clear the space
        let clearAction = PerformActionCommand(
            appIdentifier: nil,
            locator: mainInputLocator,
            action: AXActionNames.kAXSetValueAction,
            value: AnyCodable(""),
            maxDepthForSearch: 5
        )
        _ = self.axorcist.handlePerformAction(command: clearAction)

        self.logger.info("PID \(String(describing: pid)): Completed stuck state recovery attempt.")
        self.sessionLogger.log(level: .info, message: "Completed stuck state recovery attempt.", pid: pid)
        return true
    }

    func attemptGeneralRecoveryByNudge(pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger
            .info(
                "Attempting general recovery by nudge for Cursor instance (PID: \(String(describing: pid)))"
            )
        self.sessionLogger.log(level: .info, message: "Attempting general recovery by nudge.", pid: pid)

        // For general recovery, we'll use the nudge approach
        let nudgeResult = await nudgeInstance(pid: pid, app: runningApp)

        if nudgeResult {
            self.logger
                .info("PID \(String(describing: pid)): General recovery by nudge succeeded.")
            self.sessionLogger
                .log(level: .info, message: "General recovery by nudge succeeded.", pid: pid)
        } else {
            self.logger
                .warning("PID \(String(describing: pid)): General recovery by nudge failed.")
            self.sessionLogger
                .log(level: .warning, message: "General recovery by nudge failed.", pid: pid)
        }

        return nudgeResult
    }

    // MARK: Private

    private let axorcist: AXorcist
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private let logger = Logger(category: .interventionEngine)

    private func clickStopButton(for pid: pid_t) async -> Bool {
        guard let stopButtonLocator = await self.locatorManager.getLocator(for: .stopGeneratingButton, pid: pid) else {
            self.logger.error("PID \(String(describing: pid)): Failed to get locator for stopGeneratingButton.")
            return false
        }

        return await clickElement(locator: stopButtonLocator, elementName: "stop button", pid: pid)
    }

    private func clickResumeButton(for pid: pid_t) async -> Bool {
        guard let resumeButtonLocator = await self.locatorManager.getLocator(for: .resumeConnectionButton, pid: pid)
        else {
            self.logger.error("PID \(String(describing: pid)): Failed to get locator for resumeConnectionButton.")
            return false
        }

        return await clickElement(locator: resumeButtonLocator, elementName: "resume button", pid: pid)
    }

    private func clickElement(locator: Locator, elementName: String, pid: pid_t) async -> Bool {
        let action = PerformActionCommand(
            appIdentifier: nil,
            locator: locator,
            action: AXActionNames.kAXPressAction,
            value: nil,
            maxDepthForSearch: 5
        )
        let actionResponse = self.axorcist.handlePerformAction(command: action)

        guard actionResponse.error == nil else {
            self.logger.error("""
                PID \(String(describing: pid)): Failed to click \(elementName). \
                Error: \(String(describing: actionResponse.error?.message))
                """)
            self.sessionLogger
                .log(
                    level: .error,
                    message: "Failed to click \(elementName): \(String(describing: actionResponse.error?.message))",
                    pid: pid
                )
            return false
        }

        self.logger.info("PID \(String(describing: pid)): Successfully clicked \(elementName).")
        return true
    }
}
