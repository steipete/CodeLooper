import Foundation
import Combine
import OSLog
import Defaults
import AppKit // For NSRunningApplication, AXUIElement etc.
import AXorcistLib
import ApplicationServices // Added for kAX constants

@MainActor
public class CursorInterventionEngine: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper",
        category: String(describing: CursorInterventionEngine.self)
    )

    // MARK: - Constants & Thresholds
    // These will be populated from CursorMonitor.swift
    static let positiveWorkKeywords = [
        "Saving", "Saved", "Exporting", "Exported", "Generating", "Generated", "Building", "Built", "Running", "Ran",
        "Indexing", "Indexed", "Synchronizing", "Synced", "Cloning", "Cloned", "Fetching", "Fetched", "Pushing", "Pushed",
        "Pulling", "Pulled", "Merging", "Merged", "Rebasing", "Rebased", "Committing", "Committed", "Deploying", "Deployed",
        "Analyzing", "Analyzed", "Optimizing", "Optimized", "Refactoring", "Refactored", "Formatting", "Formatted",
        "Testing", "Tested", "Debugging", "Debugged", "Starting", "Started", "Stopping", "Stopped", "Loading", "Loaded",
        "Opening", "Opened", "Closing", "Closed", "Updating", "Updated", "Installing", "Installed", "Uploading", "Uploaded",
        "Downloading", "Downloaded", "Processing", "Processed", "Compressing", "Compressed", "Decompressing", "Decompressed",
        "Waiting for", "Connected to", "Authenticated", "Authorized", "Verified", "Validated", "No issues found", "Succeeded",
        "Complete", "Finished", "Ready"
    ]
    static let errorIndicatingKeywords = [
        "Error", "Failed", "Failure", "Cannot", "Unable", "Exception", "Invalid", "Missing", "Denied", "Timeout",
        "Timed out", "Refused", "Not found", "Unrecognized", "Unsupported", "Corrupt", "Aborted", "Canceled", "Terminated",
        "Disconnected", "Lost connection", "Build failed", "Test failed", "Syntax error", "Runtime error", "Crash", "Panic",
        "Fatal", "Segfault", "Segmentation fault", "Access violation", "Permission denied", "Could not", "Problem", "Issue",
        "Warning" // Warning can sometimes precede a fatal error
    ]
    static let sidebarKeywords = ["Copilot", "Chat", "Assistant", "Help", "AI", "GPT", "Claude", "LLM"]
    static let unrecoverableStateKeywords = ["fatal error", "panic", "corrupted data", "unable to proceed", "application will now terminate"]
    static let connectionIssueKeywords = ["Connection to language server", "language server failed", "language server crashed", "language server timed out", "Copilot is encountering temporary", "Copilot failed to connect", "network error", "connection lost", "no internet", "offline"]

    static let interventionActionDelay: TimeInterval = 2.0 // Seconds to wait before intervention action
    static let maxAutomaticInterventions = 5 // Per positive activity period
    static let maxTotalAutomaticInterventions = 20 // Per app session (CodeLooper session)
    static let maxConsecutiveRecoveryFailures = 3 // Before escalating or stopping automated attempts
    static let sidebarCheckInterval: TimeInterval = 5.0 // How often to check for sidebar activity if no other activity
    static let positiveActivityResetThreshold: TimeInterval = 60.0 // Seconds of inactivity before resetting positive work state
    static let automatedInterventionCooldown: TimeInterval = 30.0 // Seconds before another automated intervention can be tried for the same PID

    // MARK: - Properties
    private weak var monitor: CursorMonitor? // Reference to the main monitor for callbacks/state access if needed
    private let axorcist: AXorcistLib.AXorcist
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager

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

        var displayText: String {
            return rawValue
        }
    }

    static let interventionTypeTexts: [InterventionType: String] = [
        .unknown: "Status is currently unknown or being determined.",
        .noInterventionNeeded: "No intervention is currently needed. Application appears to be responsive.",
        .positiveWorkingState: "Positive working state detected. Monitoring continues.",
        .sidebarActivityDetected: "User activity detected in a sidebar (e.g., Copilot, Chat).",
        .connectionIssue: "A connection issue is suspected (e.g., to language server, Copilot).",
        .generalError: "A general error or stalled state is suspected.",
        .unrecoverableError: "An unrecoverable error state has been detected.",
        .manualPause: "Monitoring for this instance is manually paused.",
        .automatedRecovery: "Attempting an automated recovery action.",
        .interventionLimitReached: "Automatic intervention limit reached for this session or period.",
        .awaitingAction: "System is awaiting a user action or a timeout for the next step.",
        .monitoringPaused: "Global monitoring is currently paused.",
        .processNotRunning: "The monitored process is not currently running."
    ]

    // MARK: - Initialization
    public init(
        monitor: CursorMonitor,
        axorcist: AXorcistLib.AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager
    ) {
        self.monitor = monitor
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.logger.info("CursorInterventionEngine initialized.")
    }

    // MARK: - Core Intervention Logic
    // Placeholder for methods like:
    // func determineInterventionType(for pid: pid_t, runningApp: NSRunningApplication) async -> InterventionType?
    // func checkForPositiveWorkingState(for pid: pid_t, using element: AXUIElement?) async -> Bool
    // ... and other related methods ...

    public func determineInterventionType(for pid: pid_t, runningApp: NSRunningApplication) async -> InterventionType {
        // 1. Check if manually paused
        if self.instanceStateManager.isManuallyPaused(pid: pid) {
            return .manualPause
        }
        
        // 2. Check if monitoring is globally paused
        if let monitor = self.monitor, !monitor.isMonitoringActive {
            return .monitoringPaused
        }
        
        // 3. Check for consecutive recovery failures
        if self.instanceStateManager.getConsecutiveRecoveryFailures(for: pid) >= Self.maxConsecutiveRecoveryFailures {
            return .unrecoverableError
        }
        
        // 4. Check if intervention limit reached
        if self.instanceStateManager.getAutomaticInterventions(for: pid) >= Self.maxAutomaticInterventions {
            return .interventionLimitReached
        }
        
        // 5. Perform AX queries
        var tempLogs: [String] = []
        
        // 5a. Check for positive working state (generatingIndicatorText)
        if let generatingIndicatorLocator = await self.locatorManager.getLocator(for: .generatingIndicatorText, pid: pid) {
            let response = await self.axorcist.handleQuery(for: nil, locator: generatingIndicatorLocator, pathHint: nil, maxDepth: 10, requestedAttributes: nil, outputFormat: nil, isDebugLoggingEnabled: true, currentDebugLogs: &tempLogs)
            if let axData = response.data {
                let textContent = self.getTextFromAXElement(axData)
                if Self.positiveWorkKeywords.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                    return .positiveWorkingState
                }
            }
        }
        
        // 5b. Check for error messages (errorMessagePopup)
        if let errorMessageLocator = await self.locatorManager.getLocator(for: .errorMessagePopup, pid: pid) {
            let response = await self.axorcist.handleQuery(for: nil, locator: errorMessageLocator, pathHint: nil, maxDepth: 10, requestedAttributes: nil, outputFormat: nil, isDebugLoggingEnabled: true, currentDebugLogs: &tempLogs)
            if let axData = response.data {
                let textContent = self.getTextFromAXElement(axData)
                if Self.errorIndicatingKeywords.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                    return .generalError
                }
            }
        }
        
        // 5c. Check sidebar activity if enabled
        if Defaults[.monitorSidebarActivity] {
            if let sidebarLocator = await self.locatorManager.getLocator(for: .sidebarActivityArea, pid: pid) {
                let response = await self.axorcist.handleQuery(for: nil, locator: sidebarLocator, pathHint: nil, maxDepth: 10, requestedAttributes: nil, outputFormat: nil, isDebugLoggingEnabled: true, currentDebugLogs: &tempLogs)
                if let axData = response.data {
                    let sidebarTextRepresentation = self.getTextualRepresentation(for: axData, depth: 0, maxDepth: 1)
                    let currentHash = sidebarTextRepresentation.hashValue
                    
                    if let lastHashOptional = self.instanceStateManager.getLastKnownSidebarStateHash(for: pid), 
                       let lastHashValue = lastHashOptional, 
                       lastHashValue != currentHash {
                        return .sidebarActivityDetected
                    }
                }
            }
        }
        
        // 5d. Check for connection issues if enabled
        if Defaults[.enableConnectionIssuesRecovery] {
            if let connectionErrorLocator = await self.locatorManager.getLocator(for: .connectionErrorIndicator, pid: pid) {
                let response = await self.axorcist.handleQuery(for: nil, locator: connectionErrorLocator, pathHint: nil, maxDepth: 10, requestedAttributes: nil, outputFormat: nil, isDebugLoggingEnabled: true, currentDebugLogs: &tempLogs)
                if let axData = response.data {
                    let textContent = self.getTextFromAXElement(axData)
                    if Self.connectionIssueKeywords.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                        return .connectionIssue
                    }
                }
            }
        }
        
        // 6. Check for stuck timeout if enabled
        if Defaults[.enableCursorStopsRecovery] {
            if let lastActive = self.instanceStateManager.getLastActivityTimestamp(for: pid) {
                let timeoutThreshold = Defaults[.stuckDetectionTimeoutSeconds]
                if Date().timeIntervalSince(lastActive) > timeoutThreshold {
                    return .generalError
                }
            }
        }
        
        // 7. No intervention needed
        return .noInterventionNeeded
    }

    // MARK: - Intervention Actions

    public func nudgeInstance(pid: pid_t, app: NSRunningApplication) async -> Bool {
        var tempLogs: [String] = []
        self.logger.info("Attempting to nudge Cursor instance (PID: \\(String(describing: pid))) via InterventionEngine")
        await self.sessionLogger.log(level: .info, message: "Attempting to nudge instance via engine.", pid: pid)

        guard let nudgeLocator = await self.locatorManager.getLocator(for: .mainInputField, pid: pid) else {
            self.logger.warning("PID \\(String(describing: pid)): Nudge failed - chat input locator (.mainInputField) not found.")
            await self.sessionLogger.log(level: .warning, message: "Nudge failed - chat input locator (.mainInputField) not found.", pid: pid)
            // Monitor will update its own instanceInfo based on the false return
            return false
        }

        let axDebugLoggingEnabled = Defaults[.verboseLogging]

        let focusResponse = await self.axorcist.handlePerformAction(for: nil, locator: nudgeLocator, pathHint: nil, actionName: AXActionNames.kAXRaiseAction, actionValue: nil, maxDepth: 10, isDebugLoggingEnabled: axDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        if focusResponse.error != nil {
            let _ = focusResponse.error ?? "Unknown error focusing"
            self.logger.warning("PID \\(String(describing: pid)): Failed to focus chat input before nudge: \\(String(describing: focusResponse.error))")
        }

        let setValueResponse = await self.axorcist.handlePerformAction(for: nil, locator: nudgeLocator, pathHint: nil, actionName: AXActionNames.kAXSetValueAction, actionValue: AXorcistLib.AnyCodable(" "), maxDepth: 10, isDebugLoggingEnabled: axDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        if setValueResponse.error == nil {
            self.logger.info("PID \\(String(describing: pid)): Nudge successful (sent space to chat input) via engine.")
            await self.sessionLogger.log(level: .info, message: "Nudge successful via engine.", pid: pid)
            
            // Update state via instanceStateManager
            self.instanceStateManager.incrementAutomaticInterventions(for: pid)
            self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
            self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
            self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1) // -1 because we just incremented
            
            if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
            AppIconStateController.shared.flashIcon()
            return true
        } else {
            let _ = setValueResponse.error ?? "Unknown error"
            self.logger.warning("PID \\(String(describing: pid)): Nudge failed - AXSetValue action failed: \\(String(describing: setValueResponse.error))")
            await self.sessionLogger.log(level: .warning, message: "Nudge AXSetValue failed: \\(String(describing: setValueResponse.error))", pid: pid)
            return false
        }
    }

    public func attemptConnectionRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger.info("PID \\(String(describing: pid)): Attempting connection recovery.")
        await self.sessionLogger.log(level: .info, message: "Attempting connection recovery.", pid: pid)
        var tempLogs: [String] = []
        let axDebugLoggingEnabled = Defaults[.verboseLogging]

        // Try to click "Resume Connection" button first
        if let resumeButtonLocator = await self.locatorManager.getLocator(for: .resumeConnectionButton, pid: pid) {
            self.logger.debug("PID \\(String(describing: pid)): Found locator for ResumeConnectionButton. Attempting click.")
            let clickResponse = await self.axorcist.handlePerformAction(for: nil, locator: resumeButtonLocator, pathHint: nil, actionName: AXActionNames.kAXPressAction, actionValue: nil, maxDepth: 10, isDebugLoggingEnabled: axDebugLoggingEnabled, currentDebugLogs: &tempLogs)
            if clickResponse.error == nil {
                self.logger.info("PID \\(String(describing: pid)): Successfully clicked ResumeConnectionButton.")
                await self.sessionLogger.log(level: .info, message: "Clicked ResumeConnectionButton.", pid: pid)
                // Update state and return true
                self.instanceStateManager.incrementAutomaticInterventions(for: pid)
                self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
                self.instanceStateManager.resetConnectionIssueRetries(for: pid) // Reset since we took action
                self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
                self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)
                if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
                AppIconStateController.shared.flashIcon()
                return true
            } else {
                self.logger.warning("PID \\(String(describing: pid)): Failed to click ResumeConnectionButton: \\(String(describing: clickResponse.error))")
            }
        } else {
            self.logger.debug("PID \\(String(describing: pid)): Locator for ResumeConnectionButton not found.")
        }

        // If Resume button failed or not found, try "Force Stop Resume Link"
        if let forceResumeLinkLocator = await self.locatorManager.getLocator(for: .forceStopResumeLink, pid: pid) {
            self.logger.debug("PID \\(String(describing: pid)): Found locator for ForceStopResumeLink. Attempting click.")
            let clickResponse = await self.axorcist.handlePerformAction(for: nil, locator: forceResumeLinkLocator, pathHint: nil, actionName: AXActionNames.kAXPressAction, actionValue: nil, maxDepth: 10, isDebugLoggingEnabled: axDebugLoggingEnabled, currentDebugLogs: &tempLogs)
            if clickResponse.error == nil {
                self.logger.info("PID \\(String(describing: pid)): Successfully clicked ForceStopResumeLink.")
                await self.sessionLogger.log(level: .info, message: "Clicked ForceStopResumeLink.", pid: pid)
                // Update state and return true
                self.instanceStateManager.incrementAutomaticInterventions(for: pid)
                self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
                self.instanceStateManager.resetConnectionIssueRetries(for: pid)
                self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
                self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)
                if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
                AppIconStateController.shared.flashIcon()
                return true
            } else {
                self.logger.warning("PID \\(String(describing: pid)): Failed to click ForceStopResumeLink: \\(String(describing: clickResponse.error))")
            }
        } else {
            self.logger.debug("PID \\(String(describing: pid)): Locator for ForceStopResumeLink not found.")
        }
        
        // If both attempts fail
        self.logger.warning("PID \\(String(describing: pid)): Connection recovery failed after trying all methods.")
        await self.sessionLogger.log(level: .warning, message: "Connection recovery failed.", pid: pid)
        self.instanceStateManager.incrementConnectionIssueRetries(for: pid) // Increment retries as this specific type of recovery failed.
        return false
    }

    public func attemptStuckStateRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger.info("PID \\(String(describing: pid)): Attempting stuck state recovery (force stop/resume).")
        await self.sessionLogger.log(level: .info, message: "Attempting stuck state recovery (force stop/resume).", pid: pid)
        var tempLogs: [String] = []
        let axDebugLoggingEnabled = Defaults[.verboseLogging]

        guard let forceResumeLinkLocator = await self.locatorManager.getLocator(for: .forceStopResumeLink, pid: pid) else {
            self.logger.warning("PID \\(String(describing: pid)): Stuck state recovery failed - force stop/resume link locator not found.")
            return false
        }

        let clickResponse = await self.axorcist.handlePerformAction(for: nil, locator: forceResumeLinkLocator, pathHint: nil, actionName: AXActionNames.kAXPressAction, actionValue: nil, maxDepth: 10, isDebugLoggingEnabled: axDebugLoggingEnabled, currentDebugLogs: &tempLogs)

        if clickResponse.error == nil {
            self.logger.info("PID \\(String(describing: pid)): Clicked force stop/resume link successfully.")
            // Update state and return true
            self.instanceStateManager.incrementAutomaticInterventions(for: pid)
            self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
            self.instanceStateManager.resetConnectionIssueRetries(for: pid)
            self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
            self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)
            if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
            AppIconStateController.shared.flashIcon()
            return true
        } else {
            self.logger.warning("PID \\(String(describing: pid)): Failed to click force stop/resume link: \\(String(describing: clickResponse.error))")
            return false
        }
    }

    // MARK: - Helper methods (Private methods related to intervention logic)
    
    private func getTextFromAXElement(_ axElement: AXorcistLib.AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            AXAttributeNames.kAXValueAttribute,
            AXAttributeNames.kAXTitleAttribute,
            AXAttributeNames.kAXDescriptionAttribute,
            AXAttributeNames.kAXPlaceholderValueAttribute,
            AXAttributeNames.kAXHelpAttribute
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    return stringValue
                }
            }
        }
        return ""
    }
    
    private func getTextualRepresentation(for axElement: AXorcistLib.AXElement?, depth: Int = 0, maxDepth: Int = 1) -> String {
        guard let element = axElement, depth <= maxDepth else { return "" }

        var components: [String] = []

        let attributeKeysInOrder: [String] = [
            AXAttributeNames.kAXValueAttribute,
            AXAttributeNames.kAXTitleAttribute,
            AXAttributeNames.kAXDescriptionAttribute,
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    components.append(stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                }
            }
        }
        
        return components.joined(separator: " | ")
    }

} 