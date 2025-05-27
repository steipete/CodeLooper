import AppKit // For NSRunningApplication, AXUIElement etc.
import ApplicationServices // Added for kAX constants
import AXorcist
import Combine
import Defaults
import Foundation
import SwiftUI // For ObservableObject
import Diagnostics // Add this import

@MainActor
public class CursorInterventionEngine: ObservableObject {
    private let logger = Diagnostics.Logger(category: .interventionEngine)

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
    private let axorcist: AXorcist
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
        // 5a. Check for positive working state (generatingIndicatorText)
        if let generatingIndicatorLocator = await self.locatorManager.getLocator(for: .generatingIndicatorText, pid: pid) {
            let queryCommand = QueryCommand(
                appIdentifier: nil,
                locator: generatingIndicatorLocator,
                attributesToReturn: nil,
                maxDepthForSearch: 5
            )
            let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)
            if let axData = response.payload?.value {
                let textContent = self.getTextFromAXElement(AnyCodable(axData))
                if !textContent.isEmpty { // Assuming non-empty means it's generating
                    // Potentially refine this check if "generating" text has specific content
                    self.logger.info("PID \\(String(describing: pid)): Generating indicator found: \\(textContent)")
                    if Self.positiveWorkKeywords.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                        return .positiveWorkingState
                    }
                }
            }
        }
        
        // 5b. Check for error messages (errorMessagePopup)
        if let errorMessageLocator = await self.locatorManager.getLocator(for: .errorMessagePopup, pid: pid) {
            let queryCommand = QueryCommand(
                appIdentifier: nil,
                locator: errorMessageLocator,
                attributesToReturn: nil,
                maxDepthForSearch: 5
            )
            let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)
            if let axData = response.payload?.value {
                let textContent = self.getTextFromAXElement(AnyCodable(axData))
                if Self.errorIndicatingKeywords.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                    return .generalError
                }
            }
        }
        
        // 5c. Check sidebar activity if enabled
        if Defaults[.monitorSidebarActivity] {
            if let sidebarLocator = await self.locatorManager.getLocator(for: .sidebarActivityArea, pid: pid) {
                let queryCommand = QueryCommand(
                    appIdentifier: nil,
                    locator: sidebarLocator,
                    attributesToReturn: nil, // Sidebar content might be complex, adjust attributes if needed
                    maxDepthForSearch: 5  // Adjust depth as needed for sidebar structure
                )
                let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)
                if let axData = response.payload?.value {
                    let sidebarTextRepresentation = self.getTextualRepresentation(for: AnyCodable(axData), depth: 0, maxDepth: 1) // Wrap with AnyCodable
                    if !sidebarTextRepresentation.isEmpty {
                        self.logger.info("PID \\(String(describing: pid)): Sidebar activity detected: \\(sidebarTextRepresentation.prefix(200))...")
                        return .sidebarActivityDetected
                    }
                }
            }
        }
        
        // 5d. Check for connection issues if enabled
        if Defaults[.enableConnectionIssuesRecovery] {
            if let connectionErrorLocator = await self.locatorManager.getLocator(for: .connectionErrorIndicator, pid: pid) {
                let queryCommand = QueryCommand(
                    appIdentifier: nil, 
                    locator: connectionErrorLocator,
                    attributesToReturn: nil,
                    maxDepthForSearch: 5
                )
                let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)
                if let axData = response.payload?.value {
                    let textContent = self.getTextFromAXElement(AnyCodable(axData))
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
        self.logger.info("Attempting to nudge Cursor instance (PID: \\(String(describing: pid))) via InterventionEngine")
        self.sessionLogger.log(level: .info, message: "Attempting to nudge instance via engine.", pid: pid)

        guard let nudgeLocator = await self.locatorManager.getLocator(for: .mainInputField, pid: pid) else {
            self.logger.warning("PID \\(String(describing: pid)): Nudge failed - chat input locator (.mainInputField) not found.")
            self.sessionLogger.log(level: .warning, message: "Nudge failed - chat input locator (.mainInputField) not found.", pid: pid)
            return false
        }

        let performActionCommand = PerformActionCommand(
            appIdentifier: nil, 
            locator: nudgeLocator,
            action: AXActionNames.kAXRaiseAction, 
            value: nil, 
            maxDepthForSearch: 10
        )
        let focusResponse = self.axorcist.handlePerformAction(command: performActionCommand)
        if focusResponse.error != nil {
            self.logger.warning("PID \\(String(describing: pid)): Failed to focus chat input before nudge: \\(String(describing: focusResponse.error?.message))")
        }

        let setValueCommand = PerformActionCommand(
            appIdentifier: nil, 
            locator: nudgeLocator, 
            action: AXActionNames.kAXSetValueAction, 
            value: AnyCodable(" "), 
            maxDepthForSearch: 10
        )
        let setValueResponse = self.axorcist.handlePerformAction(command: setValueCommand)
        if setValueResponse.error == nil {
            self.logger.info("PID \\(String(describing: pid)): Nudge successful (sent space to chat input) via engine.")
            self.sessionLogger.log(level: .info, message: "Nudge successful via engine.", pid: pid)
            
            // Update state via instanceStateManager
            self.instanceStateManager.incrementAutomaticInterventions(for: pid)
            self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
            self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
            self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1) // -1 because we just incremented
            
            if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
            AppIconStateController.shared.flashIcon()
            return true
        } else {
            self.logger.warning("PID \\(String(describing: pid)): Failed to nudge (set value) on chat input: \\(String(describing: setValueResponse.error?.message))")
            self.sessionLogger.log(level: .warning, message: "Failed to nudge (set value) on chat input: \\(String(describing: setValueResponse.error?.message))", pid: pid)
            return false
        }
    }

    public func attemptConnectionRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger.info("PID \\(String(describing: pid)): Attempting connection recovery.")
        self.sessionLogger.log(level: .info, message: "Attempting connection recovery.", pid: pid)

        guard let resumeButtonLocator = await self.locatorManager.getLocator(for: .resumeConnectionButton, pid: pid) else {
            self.logger.warning("PID \\(String(describing: pid)): Connection recovery failed - resume button locator (.resumeConnectionButton) not found.")
            self.sessionLogger.log(level: .warning, message: "Connection recovery: Resume button locator not found.", pid: pid)
            return false
        }

        self.logger.info("PID \\(String(describing: pid)): Found resume button locator. Attempting to press it.")
        let pressCommand = PerformActionCommand(
            appIdentifier: nil,
            locator: resumeButtonLocator,
            action: AXActionNames.kAXPressAction,
            value: nil,
            maxDepthForSearch: 10
        )
        let pressResponse = self.axorcist.handlePerformAction(command: pressCommand)

        if pressResponse.error == nil {
            self.logger.info("PID \\(String(describing: pid)): Successfully pressed resume button.")
            self.sessionLogger.log(level: .info, message: "Successfully pressed resume button.", pid: pid)
            self.instanceStateManager.incrementAutomaticInterventions(for: pid)
            self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
            self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
            self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)

            if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
            AppIconStateController.shared.flashIcon()
            return true
        } else {
            self.logger.warning("PID \\(String(describing: pid)): Failed to press resume button: \\(String(describing: pressResponse.error?.message))")
            self.sessionLogger.log(level: .warning, message: "Failed to press resume button: \\(String(describing: pressResponse.error?.message))", pid: pid)
            return false
        }
    }

    public func attemptStuckStateRecovery(for pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger.info("PID \\(String(describing: pid)): Attempting stuck state recovery.")
        self.sessionLogger.log(level: .info, message: "Attempting stuck state recovery.", pid: pid)

        // Try pressing "Force Stop/Resume" link first if available
        if let forceStopLocator = await self.locatorManager.getLocator(for: .forceStopResumeLink, pid: pid) {
            let pressForceStopCommand = PerformActionCommand(
                appIdentifier: nil,
                locator: forceStopLocator,
                action: AXActionNames.kAXPressAction,
                value: nil,
                maxDepthForSearch: 10
            )
            let pressForceStopResponse = self.axorcist.handlePerformAction(command: pressForceStopCommand)
            if pressForceStopResponse.error == nil {
                self.logger.info("PID \\(String(describing: pid)): Pressed force stop/resume link.")
                self.instanceStateManager.incrementAutomaticInterventions(for: pid)
                self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
                self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
                self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)
                self.sessionLogger.log(level: .info, message: "Pressed force stop/resume link.", pid: pid)
                if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
                AppIconStateController.shared.flashIcon()
                return true
            }
        }

        // If "Force Stop/Resume" fails or not found, try "Stop Generating" button
        if let stopGeneratingLocator = await self.locatorManager.getLocator(for: .stopGeneratingButton, pid: pid) {
            let pressStopGeneratingCommand = PerformActionCommand(
                appIdentifier: nil,
                locator: stopGeneratingLocator,
                action: AXActionNames.kAXPressAction,
                value: nil,
                maxDepthForSearch: 10
            )
            let pressStopGeneratingResponse = self.axorcist.handlePerformAction(command: pressStopGeneratingCommand)
            if pressStopGeneratingResponse.error == nil {
                self.logger.info("PID \\(String(describing: pid)): Pressed stop generating button.")
                self.instanceStateManager.incrementAutomaticInterventions(for: pid)
                self.instanceStateManager.incrementTotalAutomaticInterventionsThisSession()
                self.instanceStateManager.setLastActivityTimestamp(for: pid, date: Date())
                self.instanceStateManager.startPendingObservation(for: pid, initialInterventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid) - 1)
                self.sessionLogger.log(level: .info, message: "Pressed stop generating button.", pid: pid)
                if Defaults[.playSoundOnIntervention] { await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName]) }
                AppIconStateController.shared.flashIcon()
                return true
            }
        }

        self.logger.warning("PID \\(String(describing: pid)): All stuck state recovery attempts (Force Stop/Resume, Stop Generating) failed.")
        self.sessionLogger.log(level: .warning, message: "All stuck state recovery attempts failed.", pid: pid)
        return false
    }
    
    public func attemptGeneralRecoveryByNudge(pid: pid_t, runningApp: NSRunningApplication) async -> Bool {
        self.logger.info("PID \\(String(describing: pid)): Attempting general recovery by nudge as a last resort.")
        self.sessionLogger.log(level: .info, message: "Attempting general recovery by nudge.", pid: pid)
        
        let nudgeSuccessful = await self.nudgeInstance(pid: pid, app: runningApp)
        
        if nudgeSuccessful {
            self.logger.info("PID \\(String(describing: pid)): General recovery (nudge) successful.")
            self.sessionLogger.log(level: .info, message: "General recovery (nudge) successful.", pid: pid)
            return true
        } else {
            self.logger.warning("PID \\(String(describing: pid)): General recovery (nudge) failed.")
            self.sessionLogger.log(level: .warning, message: "General recovery (nudge) failed.", pid: pid)
            return false
        }
    }

    // Helper to extract primary text from an AX element
    // Updated to use AXElement.attributes
    private func getTextFromAXElement(_ axData: AnyCodable?) -> String {
        guard let data = axData?.value else { return "" }

        if let element = data as? AXElement {
            // Prioritize standard attributes for textual content
            let textAttributes = [
                kAXValueAttribute as String,
                kAXTitleAttribute as String,
                kAXDescriptionAttribute as String,
                kAXPlaceholderValueAttribute as String, // For text fields
                kAXStringForRangeParameterizedAttribute as String, // Though parameterized, sometimes holds full text
                kAXHelpAttribute as String
            ]
            for attrKey in textAttributes {
                if let attributeValue = element.attributes?[attrKey]?.value as? String, !attributeValue.isEmpty {
                    return attributeValue
                }
            }
        } else if let stringValue = data as? String { // If AnyCodable directly wraps a string
            return stringValue
        }
        return ""
    }

    // Updated to use AXElement.attributes and fixed "N/A"
    private func getTextualRepresentation(for axData: AnyCodable?, depth: Int, maxDepth: Int) -> String {
        guard let data = axData?.value, depth <= maxDepth else { return "" }

        var representation = ""
        let indent = String(repeating: "  ", count: depth)

        if let element = data as? AXElement {
            let roleText = element.attributes?[kAXRoleAttribute as String]?.value as? String ?? "N-A"
            representation += "\(indent)Role: \(roleText)"

            if let title = element.attributes?[kAXTitleAttribute as String]?.value as? String, !title.isEmpty { representation += ", Title: \(title)" }
            if let value = element.attributes?[kAXValueAttribute as String]?.value as? String, !value.isEmpty { representation += ", Value: \(value)" }
            if let desc = element.attributes?[kAXDescriptionAttribute as String]?.value as? String, !desc.isEmpty { representation += ", Desc: \(desc)" }
            representation += "\n"
            
            // Recursively get representation for children
            if depth < maxDepth, let childrenData = element.attributes?[kAXChildrenAttribute as String]?.value {
                if let childrenArray = childrenData as? [Any?] { // Children might be an array of AXElement or AnyCodable
                    for childData in childrenArray {
                        representation += getTextualRepresentation(for: AnyCodable(childData), depth: depth + 1, maxDepth: maxDepth)
                    }
                }
            }
        } else if let textVal = data as? String {
            representation += "\(indent)\(textVal)\n"
        }
        return representation
    }

} 
