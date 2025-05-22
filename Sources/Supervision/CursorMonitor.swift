import AppKit
import Combine
import OSLog
import AXorcistLib
import os
import Defaults
import SwiftUI
import Foundation

// Assuming AXApplicationObserver is in a place where it can be imported, or its relevant notifications are used.

// Constants previously here are now managed via Defaults.Keys
// private let MONITORING_INTERVAL_SECONDS: TimeInterval = 5.0
// private let MAX_INTERVENTIONS_PER_POSITIVE_ACTIVITY: Int = 3
// private let MAX_CONNECTION_ISSUE_RETRIES: Int = 2
// private let MAX_CONSECUTIVE_RECOVERY_FAILURES: Int = 3
private let POSITIVE_WORK_KEYWORDS: [String] = ["generating", "typing", "processing", "thinking"] // Simplified, keep for now
private let STUCK_MESSAGE_KEYWORDS: [String] = ["stuck", "not responding", "error processing request"] // Simplified, keep for now
private let CONNECTION_ISSUE_KEYWORDS: [String] = ["connection issue", "offline", "cannot reach server"] // Simplified, keep for now

// AXElement is part of AXorcistLib, so it should be AXorcistLib.AXElement if not directly available
// For clarity, let's use the fully qualified name or ensure AXElement is re-exported by AXorcistLib's top level.
// Given the previous error, the typealias was not working. Let's assume AXElement is directly usable from AXorcistLib.
// If not, we might need to use AXorcistLib.AXElement directly where AXElement is used.
// For now, removing the typealias and will rely on direct usage or fix if AXElement is not found.

@MainActor
public class CursorMonitor: ObservableObject {
    public static let shared = CursorMonitor(
        axorcist: AXorcistLib.AXorcist(), // Use the type from the library
        sessionLogger: SessionLogger.shared,
        locatorManager: LocatorManager.shared
    )

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper",
        category: "CursorMonitor"
    )
    private let cursorBundleIdentifier = "ai.cursor.Cursor" // As per spec 2.1
    public let axorcist: AXorcistLib.AXorcist // Explicitly type with Lib
    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager

    // Per-instance state management (Spec 2.2)
    private var automaticInterventionsSincePositiveActivity: [pid_t: Int] = [:]
    @Published public var totalAutomaticInterventionsThisSession: Int = 0 // For popover display
    private var connectionIssueResumeButtonClicks: [pid_t: Int] = [:]
    private var consecutiveRecoveryFailures: [pid_t: Int] = [:]
    private var lastKnownSidebarStateHash: [pid_t: Int?] = [:] // Changed String? to Int?
    private var lastActivityTimestamp: [pid_t: Date] = [:] // For Stuck Detection Timeout

    // These are accessed and mutated on the MainActor due to the class being @MainActor
    @MainActor private var appLaunchObserver: AnyCancellable?
    @MainActor private var appTerminateObserver: AnyCancellable?
    private var monitoringTask: Task<Void, Never>?
    private var isMonitoringActive: Bool = false

    public init(axorcist: AXorcistLib.AXorcist, sessionLogger: SessionLogger, locatorManager: LocatorManager) {
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.logger.info("CursorMonitor initialized.")
        Task {
            await self.sessionLogger.log(level: .info, message: "CursorMonitor initialized.")
        }
        setupWorkspaceNotificationObservers()
        scanForExistingInstances()
    }

    deinit {
        logger.info("CursorMonitor deinitialized...")
        Task { [weak self] in // Already weak self
            await MainActor.run {
                Task { // New Task here
                    self?.stopMonitoringLoop()
                }
            }
        }
    }

    private func setupWorkspaceNotificationObservers() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier }
            .receive(on: DispatchQueue.main) // Ensure main thread for UI updates and AX interactions
            .sink { [weak self] app in
                self?.handleCursorLaunch(app)
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.handleCursorTermination(app)
            }
            .store(in: &cancellables)
        logger.info("Workspace notification observers set up for Cursor.")
    }

    private func scanForExistingInstances() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.bundleIdentifier == cursorBundleIdentifier, !app.isTerminated {
                logger.info("Found existing Cursor instance (PID: \\(app.processIdentifier)) on scan.")
                handleCursorLaunch(app)
            }
        }
        if instanceInfo.isEmpty {
            logger.info("No running Cursor instances found on initial scan.")
        }
    }

    private func handleCursorLaunch(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard instanceInfo[pid] == nil else {
            logger.info("Instance PID \\(pid) already being monitored.")
            return
        }
        let newInfo = CursorInstanceInfo(app: app, status: .unknown, statusMessage: "Initializing...")
        instanceInfo[pid] = newInfo
        
        automaticInterventionsSincePositiveActivity[pid] = 0
        connectionIssueResumeButtonClicks[pid] = 0
        consecutiveRecoveryFailures[pid] = 0
        lastKnownSidebarStateHash[pid] = nil
        lastActivityTimestamp[pid] = Date() // Initialize on launch
        
        logger.info("Cursor instance launched (PID: \\(pid)). Started monitoring.")
        Task {
            await sessionLogger.log(level: .info, message: "Cursor instance launched (PID: \\(pid)). Started monitoring.")
        }
        if !isMonitoringActive {
            startMonitoringLoop()
        }
    }

    private func handleCursorTermination(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard instanceInfo.removeValue(forKey: pid) != nil else {
            logger.info("Received termination for unmonitored PID \\(pid).")
            return
        }
        
        automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
        connectionIssueResumeButtonClicks.removeValue(forKey: pid)
        consecutiveRecoveryFailures.removeValue(forKey: pid)
        lastKnownSidebarStateHash.removeValue(forKey: pid)
        lastActivityTimestamp.removeValue(forKey: pid)

        logger.info("Cursor instance terminated (PID: \\(pid)). Stopped monitoring for this instance.")
        Task {
            await sessionLogger.log(level: .info, message: "Cursor instance terminated (PID: \\(pid)). Stopped monitoring for this instance.")
        }
        
        if instanceInfo.isEmpty && isMonitoringActive {
            logger.info("No more Cursor instances. Stopping monitoring loop.")
            stopMonitoringLoop()
        }
    }
    
    public func refreshMonitoredInstances() {
        logger.debug("Refreshing monitored instances list.")
        let currentlyRunningPIDs = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier }
            .map { $0.processIdentifier }
        
        let pidsToShutdown = Set(instanceInfo.keys).subtracting(currentlyRunningPIDs)
        for pid in pidsToShutdown {
            if instanceInfo.removeValue(forKey: pid) != nil {
                 logger.info("Instance PID \\(pid) no longer running (detected by refresh). Removing.")
                 Task { await sessionLogger.log(level: .info, message: "Instance PID \\(pid) no longer running (detected by refresh). Removing.", pid: pid) }
                 automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
                 connectionIssueResumeButtonClicks.removeValue(forKey: pid)
                 consecutiveRecoveryFailures.removeValue(forKey: pid)
                 lastKnownSidebarStateHash.removeValue(forKey: pid)
                 lastActivityTimestamp.removeValue(forKey: pid)
            }
        }
        scanForExistingInstances()
         if instanceInfo.isEmpty && isMonitoringActive {
            logger.info("No more Cursor instances after refresh. Stopping monitoring loop.")
            stopMonitoringLoop()
        }
    }

    public func startMonitoringLoop() {
        guard !isMonitoringActive else {
            logger.info("Monitoring loop already active.")
            return
        }
        guard !instanceInfo.isEmpty else {
            logger.info("No Cursor instances to monitor. Loop not started.")
            return
        }

        isMonitoringActive = true
        logger.info("Starting monitoring loop with interval \\(Defaults[.monitoringIntervalSeconds])s.")
        Task {
             await sessionLogger.log(level: .info, message: "Monitoring loop started with interval \\(Defaults[.monitoringIntervalSeconds])s.")
        }

        monitoringTask = Task { [weak self] in
            while let self = self, self.isMonitoringActive, !Task.isCancelled {
                if self.instanceInfo.isEmpty {
                    self.logger.info("No active Cursor instances. Stopping monitoring loop from within.")
                    await self.sessionLogger.log(level: .info, message: "No active Cursor instances. Monitoring loop will stop.")
                    await MainActor.run { self.stopMonitoringLoop() }
                    break 
                }
                await self.performMonitoringTick()
                do {
                    try await Task.sleep(for: .seconds(Defaults[.monitoringIntervalSeconds]))
                } catch {
                    if error is CancellationError {
                        self.logger.info("Monitoring loop sleep cancelled.")
                        await self.sessionLogger.log(level: .info, message: "Monitoring loop sleep cancelled.")
                        break
                    } else {
                        self.logger.error("Monitoring loop sleep failed: \\(error.localizedDescription)")
                        await self.sessionLogger.log(level: .error, message: "Monitoring loop sleep failed: \\(error.localizedDescription)")
                    }
                }
            }
            self?.logger.info("Monitoring loop finished.")
            Task { await self?.sessionLogger.log(level: .info, message: "Monitoring loop finished.") }
        }
    }

    public func stopMonitoringLoop() {
        guard isMonitoringActive else {
            return
        }
        isMonitoringActive = false
        monitoringTask?.cancel()
        monitoringTask = nil
        logger.info("Monitoring loop stopped.")
        Task {
            await sessionLogger.log(level: .info, message: "Monitoring loop stopped.")
        }
    }

    private func performMonitoringTick() async {
        logger.debug("Performing monitoring tick for \\(instanceInfo.count) instance(s).")
        guard !instanceInfo.isEmpty else {
            logger.debug("No instances to monitor in tick.")
            return
        }

        for (pid, currentInfo) in instanceInfo {
            guard let runningApp = NSRunningApplication(processIdentifier: pid), !runningApp.isTerminated else {
                logger.info("Instance PID \\(pid) found terminated during tick, removing.")
                if let appToTerminate = NSRunningApplication(processIdentifier: pid) {
                    handleCursorTermination(appToTerminate)
                 } else {
                    if instanceInfo.removeValue(forKey: pid) != nil {
                        automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
                        connectionIssueResumeButtonClicks.removeValue(forKey: pid)
                        consecutiveRecoveryFailures.removeValue(forKey: pid)
                        lastKnownSidebarStateHash.removeValue(forKey: pid)
                        lastActivityTimestamp.removeValue(forKey: pid)
                        Task { await sessionLogger.log(level: .info, message: "Instance PID \\(pid) terminated and removed.", pid: pid) }
                    }
                 }
                continue
            }

            logger.debug("Checking instance PID \\(pid). Current status: \\(currentInfo.status)")
            await sessionLogger.log(level: .debug, message: "Checking Cursor instance (PID: \\(pid)). Current status: \\(currentInfo.status)", pid: pid)

            var newStatus: CursorInstanceStatus = currentInfo.status
            var newStatusMessage: String = currentInfo.statusMessage

            // Flag to track if an intervention was made in this tick for this PID
            var interventionMadeThisTick = false

            if case .unrecoverable(let reason) = newStatus {
                logger.warning("PID \\(pid) is in unrecoverable state: \\(reason). Skipping further checks.")
                await sessionLogger.log(level: .warning, message: "PID \\(pid) is unrecoverable: \\(reason)", pid: pid)
                newStatusMessage = "Unrecoverable: \\(reason)"
                instanceInfo[pid]?.status = newStatus
                instanceInfo[pid]?.statusMessage = newStatusMessage
                continue
            }
            if case .paused = newStatus {
                logger.info("PID \\(pid) is paused. Skipping further checks.")
                await sessionLogger.log(level: .info, message: "PID \\(pid) is paused. Skipping checks.", pid: pid)
                newStatusMessage = "Paused (Intervention Limit Reached)"
                instanceInfo[pid]?.status = newStatus
                instanceInfo[pid]?.statusMessage = newStatusMessage
                continue
            }

            let maxInterventions = Defaults[.maxInterventionsBeforePause]
            if let interventions = automaticInterventionsSincePositiveActivity[pid], interventions >= maxInterventions {
                logger.warning("PID \\(pid) reached max interventions (\\(interventions)/\\(maxInterventions)) without positive activity.")
                await sessionLogger.log(level: .warning, message: "PID \\(pid) reached max interventions (\\(interventions)/\\(maxInterventions)) without positive activity.", pid: pid)
                newStatus = .paused
                newStatusMessage = "Paused (Intervention Limit: \\(maxInterventions) reached)"
                if Defaults[.sendNotificationOnPersistentError] {
                    await UserNotificationManager.shared.sendNotification(
                        identifier: "maxInterventions_\(pid)",
                        title: "Cursor Instance Paused (PID: \(pid))",
                        body: "Code Looper has paused automatic interventions for Cursor (PID: \(pid)) after \(maxInterventions) attempts without observing positive activity. You can resume interventions from the Code Looper menu.",
                        soundName: nil
                    )
                }
                instanceInfo[pid]?.status = newStatus
                instanceInfo[pid]?.statusMessage = newStatusMessage
                continue
            }
            
            var tempLogs: [String] = []
            var isShowingPositiveWork = false

            if let generatingIndicatorLocator = locatorManager.getLocator(for: "generatingIndicatorText") {
                let response = axorcist.handleQuery(for: String(pid), locator: generatingIndicatorLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                if let axData = response.data {
                    let textContent = getTextFromAXElement(axData)
                    if POSITIVE_WORK_KEYWORDS.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                         isShowingPositiveWork = true
                         newStatus = .working(detail: "Generating: \\(textContent.prefix(30))")
                         newStatusMessage = "Working (Generating...)"
                         logger.debug("PID \\(pid): Positive work indicator found via text: '\\(textContent)'.")
                         await sessionLogger.log(level: .debug, message: "PID \\(pid): Positive work indicator found via text: '\\(textContent)'.", pid: pid)
                    } else if !textContent.isEmpty {
                        logger.debug("PID \\(pid): Generating indicator text '\\(textContent)' did not match positive keywords.")
                    }
                    if !isShowingPositiveWork && response.error == nil {
                        isShowingPositiveWork = true
                        newStatus = .working(detail: "AX Element Found")
                        newStatusMessage = "Working (Monitoring Activity)"
                        logger.debug("PID \\(pid): Positive work indicator element found (no specific text match). Resetting counters.")
                        await sessionLogger.log(level: .debug, message: "PID \\(pid): Positive work indicator element found (fallback).", pid: pid)
                    }
                }
            }

            if isShowingPositiveWork {
                logger.info("PID \\(pid) appears to be working positively. Resetting intervention counts.")
                await sessionLogger.log(level: .info, message: "PID \\(pid) shows positive activity. Resetting intervention counts.", pid: pid)
                automaticInterventionsSincePositiveActivity[pid] = 0
                connectionIssueResumeButtonClicks[pid] = 0
                consecutiveRecoveryFailures[pid] = 0
                lastActivityTimestamp[pid] = Date() // Update activity timestamp
            } else {
                 newStatus = .idle
                 newStatusMessage = "Idle (Monitoring)"
            }

            if !isShowingPositiveWork {
                var detectedStuckMessageText: String? = nil
                if let errorMessageLocator = locatorManager.getLocator(for: "errorMessagePopup") {
                    let response = axorcist.handleQuery(for: String(pid), locator: errorMessageLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                    if let axData = response.data {
                        let textContent = getTextFromAXElement(axData)
                        if STUCK_MESSAGE_KEYWORDS.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                            detectedStuckMessageText = textContent
                            newStatus = .error(reason: "Stuck: \\(textContent.prefix(50))")
                            newStatusMessage = "Error: \\(textContent.prefix(50))"
                            logger.warning("PID \\(pid): Detected stuck/error message: '\\(textContent)'.")
                            await sessionLogger.log(level: .warning, message: "PID \\(pid): Detected stuck/error message: '\\(textContent)'.", pid: pid)
                        }
                    }
                }

                if detectedStuckMessageText != nil {
                    if let stopButtonLocator = locatorManager.getLocator(for: "stopGeneratingButton") {
                        logger.info("PID \\(pid): Attempting to click 'Stop Generating' button for stuck state.")
                        await sessionLogger.log(level: .info, message: "PID \\(pid): Attempting to click 'Stop Generating' for stuck state.", pid: pid)
                        let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                        newStatus = .recovering(type: .stopGenerating, attempt: attempts)
                        newStatusMessage = "Recovering (Clicking Stop...)"
                        
                        let performResponse = axorcist.handlePerformAction(for: String(pid), locator: stopButtonLocator, actionName: AXorcistLib.kAXPressAction, actionValue: nil, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                        if performResponse.error == nil {
                            logger.info("PID \\(pid): Successfully clicked 'Stop Generating' button.")
                            await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Stop Generating' button.", pid: pid)
                            automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                            totalAutomaticInterventionsThisSession += 1
                            interventionMadeThisTick = true
                            await SoundManager.shared.playInterventionSound()
                            AppIconStateController.shared.flashIcon()
                            lastActivityTimestamp[pid] = Date() // Update activity timestamp
                        } else {
                            let errorLogMessage = performResponse.error ?? "Unknown error"
                            logger.error("PID \\(pid): Failed to click 'Stop Generating' button. Error: \\(errorLogMessage)")
                            await sessionLogger.log(level: .error, message: "PID \\(pid): Failed to click 'Stop Generating'. Error: \\(errorLogMessage)", pid: pid)
                            newStatus = .error(reason: "Failed to click 'Stop Generating' button: \\(errorLogMessage)")
                            newStatusMessage = "Error (Failed Action)"
                        }
                    } else {
                        logger.warning("PID \\(pid): Stuck message detected, but 'stopGeneratingButton' locator not found.")
                        newStatus = .error(reason: "Stuck, but Stop button locator missing")
                        newStatusMessage = "Error (Locator Missing)"
                    }
                }
            }

            if !isShowingPositiveWork && !(newStatus == .recovering(type: .stopGenerating, attempt: 0)) {
                var detectedConnectionIssueFlag = false
                if let connectionErrorLocator = locatorManager.getLocator(for: "connectionErrorIndicator") {
                     let response = axorcist.handleQuery(for: String(pid), locator: connectionErrorLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                     if let axData = response.data {
                        let textContent = getTextFromAXElement(axData)
                        if CONNECTION_ISSUE_KEYWORDS.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                            detectedConnectionIssueFlag = true
                            newStatus = .error(reason: "Connection Issue: \\(textContent.prefix(50))")
                            newStatusMessage = "Error: Connection Issue"
                            logger.warning("PID \\(pid): Detected connection issue message: '\\(textContent)'.")
                            await sessionLogger.log(level: .warning, message: "PID \\(pid): Detected connection issue: '\\(textContent)'.", pid: pid)
                        }
                    }
                }
            
                if detectedConnectionIssueFlag {
                    let maxRetries = Defaults[.maxConnectionIssueRetries]
                    let currentRetries = connectionIssueResumeButtonClicks[pid, default: 0]
                    if currentRetries < maxRetries {
                        if let resumeButtonLocator = locatorManager.getLocator(for: "resumeConnectionButton") { 
                            let attemptCount = currentRetries + 1
                            logger.info("PID \\(pid): Attempting to click 'Resume' button for connection issue (attempt \\(attemptCount)/\\(maxRetries)).")
                            await sessionLogger.log(level: .info, message: "PID \\(pid): Attempting 'Resume' for connection (attempt \\(attemptCount)/\\(maxRetries)).", pid: pid)
                            newStatus = .recovering(type: .connection, attempt: attemptCount)
                            newStatusMessage = "Recovering (Connection Attempt \\(attemptCount))"

                            let performResponse = axorcist.handlePerformAction(for: String(pid), locator: resumeButtonLocator, actionName: AXorcistLib.kAXPressAction, actionValue: nil, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                            if performResponse.error == nil {
                                logger.info("PID \\(pid): Successfully clicked 'Resume' button.")
                                await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Resume' for connection.", pid: pid)
                                connectionIssueResumeButtonClicks[pid, default: 0] += 1
                                automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                                totalAutomaticInterventionsThisSession += 1
                                interventionMadeThisTick = true
                                await SoundManager.shared.playInterventionSound()
                                AppIconStateController.shared.flashIcon()
                                lastActivityTimestamp[pid] = Date() // Update activity timestamp
                            } else {
                                let errorLogMessage = performResponse.error ?? "Unknown error"
                                logger.error("PID \\(pid): Failed to click 'Resume' button. Error: \\(errorLogMessage)")
                                await sessionLogger.log(level: .error, message: "PID \\(pid): Failed 'Resume' click. Error: \\(errorLogMessage)", pid: pid)
                                newStatus = .error(reason: "Failed to click 'Resume' button: \\(errorLogMessage)")
                                newStatusMessage = "Error (Failed Action)"
                            }
                        } else {
                            logger.warning("PID \\(pid): Connection issue detected, but 'resumeConnectionButton' locator not found.")
                            await sessionLogger.log(level: .warning, message: "PID \\(pid): Connection issue, but 'resumeConnectionButton' locator missing.", pid: pid)
                            newStatus = .error(reason: "Connection Issue, but Resume locator missing")
                            newStatusMessage = "Error (Locator Missing)"
                        }
                    } else {
                        logger.error("PID \\(pid): Max retries (\\(maxRetries)) for connection issue reached.")
                        await sessionLogger.log(level: .error, message: "PID \\(pid): Max connection retries (\\(maxRetries)).", pid: pid)
                        newStatus = .unrecoverable(reason: "Max connection issue retries (\\(maxRetries)) reached.")
                        newStatusMessage = "Unrecoverable (Max Connection Retries)"
                        if Defaults[.sendNotificationOnPersistentError] {
                            await UserNotificationManager.shared.sendNotification(
                                identifier: "maxConnectionRetries_\(pid)",
                                title: "Cursor Connection Issue (PID: \(pid))",
                                body: "Code Looper could not resolve a connection issue for Cursor (PID: \(pid)) after \(maxRetries) attempts. Interventions for this issue are paused. Check Cursor and network status.",
                                soundName: nil
                            )
                        }
                    }
                }
            }
            
            if !isShowingPositiveWork, case .idle = newStatus {
                if Defaults[.monitorSidebarActivity] {
                    if let sidebarLocator = locatorManager.getLocator(for: "sidebarActivityArea") {
                        let response = axorcist.handleQuery(for: String(pid), locator: sidebarLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                        if let axData = response.data {
                            let sidebarTextRepresentation = getTextualRepresentation(for: axData, maxDepth: 2)
                            let currentHash = sidebarTextRepresentation.hashValue
                            
                            if let lastHashValue = lastKnownSidebarStateHash[pid], lastHashValue != nil, lastHashValue != currentHash {
                                logger.info("PID \\(pid): Sidebar activity detected (hash changed from \\(String(describing: lastHashValue)) to \\(currentHash)). Text: \\(sidebarTextRepresentation.prefix(100))...")
                                await sessionLogger.log(level: .info, message: "PID \\(pid): Sidebar activity detected.", pid: pid)
                                automaticInterventionsSincePositiveActivity[pid] = 0
                                connectionIssueResumeButtonClicks[pid] = 0
                                consecutiveRecoveryFailures[pid] = 0
                                newStatus = .working(detail: "Recent Sidebar Activity")
                                newStatusMessage = "Working (Recent Activity)"
                                lastActivityTimestamp[pid] = Date()
                            } else if lastKnownSidebarStateHash[pid] == nil {
                                logger.debug("PID \\(pid): Initial sidebar state observed or re-observed after nil. Hash: \\(currentHash)")
                            }
                            lastKnownSidebarStateHash[pid] = currentHash
                        } else {
                            if response.error != nil {
                                logger.debug("PID \\(pid): Sidebar query failed or element not found. Error: \\(response.error!.localizedDescription)")
                            } else {
                                logger.debug("PID \\(pid): Sidebar query failed or element not found (no specific error).")
                            }
                            lastKnownSidebarStateHash[pid] = nil
                        }
                    }
                }
            }

            // Before general stuck check, handle specific error scenarios first

            // G. Cursor Force-Stopped / Not Responding
            var shouldProceedToStuckDetectionNotForceStopped = false

            if !isShowingPositiveWork, case .error = newStatus { // Only if not working and some error or idle state
                if case .recovering = currentInfo.status {
                    // Skip if already recovering
                } else {
                    if !Defaults[.enableCursorForceStoppedRecovery] {
                        logger.debug("PID \\(pid): Cursor Force-Stopped recovery is disabled, skipping to stuck detection.")
                        shouldProceedToStuckDetectionNotForceStopped = true
                    }
                    if !shouldProceedToStuckDetectionNotForceStopped, let forceStopLocator = locatorManager.getLocator(for: "forceStopResumeLink") {
                        let response = axorcist.handleQuery(for: String(pid), locator: forceStopLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                        if let axData = response.data, response.error == nil { // Element found
                            let textContent = getTextFromAXElement(axData)
                            if !textContent.isEmpty {
                                logger.info("PID \\(pid): Detected 'Force-Stop / Resume Conversation' state. Attempting to click.")
                                await sessionLogger.log(level: .info, message: "PID \\(pid): Detected 'Force-Stop / Resume Conversation' state. Attempting to click.", pid: pid)
                                
                                let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                                newStatus = .recovering(type: .forceStop, attempt: attempts)
                                newStatusMessage = "Recovering (Force-Stop)"
                                instanceInfo[pid]?.status = newStatus
                                instanceInfo[pid]?.statusMessage = newStatusMessage

                                let performResponse = axorcist.handlePerformAction(for: String(pid), locator: forceStopLocator, actionName: AXorcistLib.kAXPressAction, actionValue: nil, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                                if performResponse.error == nil {
                                    logger.info("PID \\(pid): Successfully clicked 'Force-Stop / Resume Conversation' element.")
                                    await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Force-Stop / Resume Conversation' element.", pid: pid)
                                    automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                                    totalAutomaticInterventionsThisSession += 1
                                    interventionMadeThisTick = true
                                    connectionIssueResumeButtonClicks[pid] = 0 // Reset as per spec
                                    await SoundManager.shared.playInterventionSound()
                                    AppIconStateController.shared.flashIcon()
                                    lastActivityTimestamp[pid] = Date()
                                    isShowingPositiveWork = true // Assume this resolves the immediate issue
                                } else {
                                    let errorLogMessage = performResponse.error ?? "Unknown error"
                                    logger.error("PID \\(pid): Failed to click 'Force-Stop / Resume Conversation' element. Error: \\(errorLogMessage)")
                                    await sessionLogger.log(level: .error, message: "PID \\(pid): Failed to click 'Force-Stop / Resume Conversation'. Error: \\(errorLogMessage)", pid: pid)
                                    newStatus = .error(reason: "Failed to click 'Force-Stop / Resume Conversation' element: \\(errorLogMessage)")
                                    newStatusMessage = "Error (Failed Action)"
                                }
                            }
                        } else if response.error != nil {
                            logger.debug("PID \(pid): 'forceStopResumeLink' query failed. Error: \(response.error ?? "Unknown Error")")
                        }
                    }
                }
            }
            
            if shouldProceedToStuckDetectionNotForceStopped || (!isShowingPositiveWork && newStatus != .recovering(type: .forceStop, attempt: 0) ) { // Simplified logic
                // F. Connection Issues Check
                var shouldProceedToStuckDetection = false

                if !isShowingPositiveWork, case .error(let reason) = newStatus, reason.contains("Connection Issue") { 
                    if case .recovering = currentInfo.status {
                        // Skip if already recovering
                    } else {
                        if !Defaults[.enableConnectionIssuesRecovery] {
                            logger.debug("PID \\(pid): Connection issues recovery is disabled, skipping to stuck detection.")
                            shouldProceedToStuckDetection = true
                        }
                        
                        if !shouldProceedToStuckDetection {
                            var detectedConnectionIssueFlagForIntervention = false
                            if let connectionErrorTextLocator = locatorManager.getLocator(for: "connectionErrorIndicator") {
                                let response = axorcist.handleQuery(for: String(pid), locator: connectionErrorTextLocator, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                                if let axData = response.data, response.error == nil {
                                    let textContent = getTextFromAXElement(axData)
                                    if CONNECTION_ISSUE_KEYWORDS.contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) }) {
                                        detectedConnectionIssueFlagForIntervention = true
                                        logger.warning("PID \\(pid): Confirmed connection issue for intervention: '\\(textContent)'.")
                                        await sessionLogger.log(level: .warning, message: "PID \\(pid): Confirmed connection issue for intervention: '\\(textContent)'.", pid: pid)
                                    }
                                }
                            }

                            if detectedConnectionIssueFlagForIntervention {
                                let maxRetries = Defaults[.maxConnectionIssueRetries]
                                let currentRetries = connectionIssueResumeButtonClicks[pid, default: 0]

                                if currentRetries < maxRetries {
                                    if let resumeButtonLocator = locatorManager.getLocator(for: "resumeConnectionButton") { 
                                        let attemptCount = currentRetries + 1
                                        logger.info("PID \\(pid): Attempting to click 'Resume' button for connection issue (attempt \\(attemptCount)/\\(maxRetries)).")
                                        await sessionLogger.log(level: .info, message: "PID \\(pid): Attempting 'Resume' for connection (attempt \\(attemptCount)/\\(maxRetries)).", pid: pid)
                                        
                                        newStatus = .recovering(type: .connection, attempt: attemptCount)
                                        newStatusMessage = "Recovering (Connection Attempt \\(attemptCount))"
                                        instanceInfo[pid]?.status = newStatus
                                        instanceInfo[pid]?.statusMessage = newStatusMessage

                                        let performResponse = axorcist.handlePerformAction(for: String(pid), locator: resumeButtonLocator, actionName: AXorcistLib.kAXPressAction, actionValue: nil, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                                        if performResponse.error == nil {
                                            logger.info("PID \\(pid): Successfully clicked 'Resume' button for connection issue.")
                                            await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Resume' for connection.", pid: pid)
                                            connectionIssueResumeButtonClicks[pid, default: 0] += 1
                                            automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                                            totalAutomaticInterventionsThisSession += 1
                                            interventionMadeThisTick = true
                                            await SoundManager.shared.playInterventionSound()
                                            AppIconStateController.shared.flashIcon()
                                            lastActivityTimestamp[pid] = Date()
                                            isShowingPositiveWork = true // Assume this resolves the immediate issue
                                        } else {
                                            let errorLogMessage = performResponse.error ?? "Unknown error"
                                            logger.error("PID \\(pid): Failed to click 'Resume' button for connection issue. Error: \\(errorLogMessage)")
                                            await sessionLogger.log(level: .error, message: "PID \\(pid): Failed 'Resume' click for connection. Error: \\(errorLogMessage)", pid: pid)
                                            newStatus = .error(reason: "Failed to click 'Resume' button for connection issue: \\(errorLogMessage)")
                                            newStatusMessage = "Error (Failed Action)"
                                        }
                                    } else {
                                        logger.warning("PID \\(pid): Connection issue detected, but 'resumeConnectionButton' locator not found.")
                                        await sessionLogger.log(level: .warning, message: "PID \\(pid): Connection issue, but 'resumeConnectionButton' locator missing.", pid: pid)
                                        newStatus = .error(reason: "Connection Issue, but Resume locator missing")
                                        newStatusMessage = "Error (Locator Missing)"
                                    }
                                } else {
                                    logger.error("PID \\(pid): Max retries (\\(maxRetries)) for connection issue reached. Escalating to 'Cursor Stops' recovery.")
                                    await sessionLogger.log(level: .error, message: "PID \\(pid): Max connection retries (\\(maxRetries)). Escalating to nudge.", pid: pid)
                                    connectionIssueResumeButtonClicks[pid] = 0 
                                    
                                    let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                                    newStatus = .recovering(type: .stuck, attempt: attempts) 
                                    newStatusMessage = "Recovering (Nudge after Connection Failures)"
                                    instanceInfo[pid]?.status = newStatus
                                    instanceInfo[pid]?.statusMessage = newStatusMessage
                                    
                                    await nudgeInstance(pid: pid)
                                    if let updatedInfo = instanceInfo[pid] {
                                        newStatus = updatedInfo.status
                                        newStatusMessage = updatedInfo.statusMessage
                                    }
                                    interventionMadeThisTick = true 

                                    if var updatedInfo = instanceInfo[pid] {
                                        updatedInfo.status = newStatus // Ensure our local vars are what's in the map
                                        updatedInfo.statusMessage = newStatusMessage
                                        instanceInfo[pid] = updatedInfo
                                    }
                                }
                            }
                        }
                    }
                }
                
                if shouldProceedToStuckDetection || (!isShowingPositiveWork && newStatus != .recovering(type: .connection, attempt: 0) ) { // Simplified logic
                    // H. Cursor Stops / Stuck
                    var shouldProceedToEndOfChecks = false

                    if !isShowingPositiveWork, case .idle = newStatus { 
                        if case .recovering = currentInfo.status {
                            // Skip if already recovering
                        } else {
                            if !Defaults[.enableCursorStopsRecovery] {
                                logger.debug("PID \\(pid): Cursor stops recovery is disabled, skipping to end of checks.")
                                shouldProceedToEndOfChecks = true
                            }
                            
                            if !shouldProceedToEndOfChecks {
                                let stuckTimeout = Defaults[.stuckDetectionTimeoutSeconds]
                                if let lastActive = lastActivityTimestamp[pid],
                                   Date().timeIntervalSince(lastActive) > stuckTimeout {
                                logger.info("PID \\(pid) detected as stuck (idle for > \\(stuckTimeout)s). Triggering 'Cursor Stops' recovery.")
                                await sessionLogger.log(level: .info, message: "PID \\(pid) detected as stuck (idle for > \\(stuckTimeout)s). Triggering recovery.", pid: pid)
                                
                                    let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                                    newStatus = .recovering(type: .stuck, attempt: attempts)
                                    newStatusMessage = "Recovering (Stuck)"
                                    instanceInfo[pid]?.status = newStatus 
                                    instanceInfo[pid]?.statusMessage = newStatusMessage

                                    await nudgeInstance(pid: pid) 
                                    if let updatedInfo = instanceInfo[pid] {
                                        newStatus = updatedInfo.status
                                        newStatusMessage = updatedInfo.statusMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Persistent Failure Cycle Detection (Spec 2.3.7)
            if interventionMadeThisTick && !isShowingPositiveWork {
                self.consecutiveRecoveryFailures[pid, default: 0] += 1
                logger.warning("PID \\(pid): Intervention performed, but no immediate positive work observed. Consecutive failures: \\(self.consecutiveRecoveryFailures[pid, default: 0]).")
                await sessionLogger.log(level: .warning, message: "PID \\(pid): Intervention made, no immediate positive work. Consecutive failures: \\(self.consecutiveRecoveryFailures[pid, default: 0]).", pid: pid)
            }

            let maxFailures = Defaults[.maxConsecutiveRecoveryFailures]
            if self.consecutiveRecoveryFailures[pid, default: 0] >= maxFailures {
                logger.error("PID \\(pid) reached max consecutive recovery failures (\\(self.consecutiveRecoveryFailures[pid, default: 0])/\\(maxFailures)).")
                await sessionLogger.log(level: .error, message: "PID \\(pid) reached max consecutive recovery failures (\\(self.consecutiveRecoveryFailures[pid, default: 0])/\\(maxFailures)).", pid: pid)
                newStatus = .unrecoverable(reason: "Max consecutive recovery failures (\\(maxFailures)) reached.")
                newStatusMessage = "Unrecoverable (Persistent Failures)"
                if Defaults[.sendNotificationOnPersistentError] {
                    await UserNotificationManager.shared.sendNotification(
                        identifier: "persistentFailure_\(pid)",
                        title: "Cursor Instance Unrecoverable (PID: \(pid))",
                        body: "Code Looper encountered persistent recovery failures for Cursor (PID: \(pid)) after \(maxFailures) cycles. Automatic interventions are paused. Please check the Cursor instance or restart it.",
                        soundName: nil
                    )
                }
            }
            
            if var infoToUpdate = instanceInfo[pid] {
                infoToUpdate.status = newStatus
                infoToUpdate.statusMessage = newStatusMessage
                instanceInfo[pid] = infoToUpdate
            } else {
                 logger.warning("PID \\(pid) info was unexpectedly nil at end of tick. It might have terminated concurrently.")
            }
        }
        logger.debug("Monitoring tick completed.")
    }

    private func getTextFromAXElement(_ axElement: AXorcistLib.AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            AXorcistLib.kAXValueAttribute as String,
            AXorcistLib.kAXTitleAttribute as String,
            AXorcistLib.kAXDescriptionAttribute as String,
            AXorcistLib.kAXPlaceholderValueAttribute as String,
            AXorcistLib.kAXHelpAttribute as String
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
        var _: [String] = [] // tempLogs was unused, replaced with _

        let attributeKeysInOrder: [String] = [
            AXorcistLib.kAXValueAttribute as String,
            AXorcistLib.kAXTitleAttribute as String,
            AXorcistLib.kAXDescriptionAttribute as String,
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    components.append(stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                }
            }
        }
        
        if depth < maxDepth {
            /*
            if let childrenElements = element.children(isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs) {
                for child in childrenElements {
                    let childText = getTextualRepresentation(for: child, depth: depth + 1, maxDepth: maxDepth)
                    if !childText.isEmpty {
                        components.append(childText)
                    }
                }
            }
            */
        }
        
        return components.joined(separator: " | ")
    }

    public func resumeInterventions(for pid: pid_t) async {
        guard var info = instanceInfo[pid] else {
            logger.warning("Attempted to resume interventions for unknown PID: \\(pid)")
            return
        }
        logger.info("Resuming interventions for PID: \\(pid)")
        await sessionLogger.log(level: .info, message: "User resumed interventions for PID \\(pid).", pid: pid)
        
        automaticInterventionsSincePositiveActivity[pid] = 0
        connectionIssueResumeButtonClicks[pid] = 0
        consecutiveRecoveryFailures[pid] = 0
        info.status = .idle 
        info.statusMessage = "Idle (Resumed by User)"
        lastActivityTimestamp[pid] = Date() 
        instanceInfo[pid] = info
    }

    public func nudgeInstance(pid: pid_t) async {
        guard var infoToUpdate = instanceInfo[pid] else {
            logger.warning("Attempted to nudge unknown PID: \\(pid)")
            return
        }
        
        logger.info("Nudging instance PID: \\(pid)")
        await sessionLogger.log(level: .info, message: "User nudged PID \\(pid).", pid: pid)

        var tempLogs: [String] = []
        if let inputFieldLocator = locatorManager.getLocator(for: "mainInputField") {
            let recoveryText = Defaults[.textForCursorStopsRecovery]
            
            let setValueResponse = axorcist.handlePerformAction(for: String(pid), locator: inputFieldLocator, actionName: AXorcistLib.kAXValueAttribute, actionValue: AnyCodable(recoveryText), isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
            
            if setValueResponse.error == nil {
                let pressActionResponse = axorcist.handlePerformAction(for: String(pid), locator: inputFieldLocator, actionName: AXorcistLib.kAXPressAction, actionValue: nil, isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs)
                
                if pressActionResponse.error == nil {
                    logger.info("PID \\(pid): Successfully nudged by setting text and pressing Enter.")
                    await sessionLogger.log(level: .info, message: "PID \\(pid): Nudge successful.", pid: pid)
                    automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                    totalAutomaticInterventionsThisSession += 1
                    await SoundManager.shared.playInterventionSound()
                    AppIconStateController.shared.flashIcon()
                    automaticInterventionsSincePositiveActivity[pid] = 0 
                    connectionIssueResumeButtonClicks[pid] = 0
                    consecutiveRecoveryFailures[pid] = 0
                    lastActivityTimestamp[pid] = Date() 
                    
                    infoToUpdate.status = .working(detail: "Nudged by User")
                    infoToUpdate.statusMessage = "Working (Nudged)"
                    instanceInfo[pid] = infoToUpdate
                    
                } else {
                    let errorLogMessage = pressActionResponse.error ?? "Unknown"
                    logger.error("PID \\(pid): Nudge failed (press action). Error: \\(errorLogMessage)")
                    await sessionLogger.log(level: .error, message: "PID \\(pid): Nudge failed (press action). Error: \\(errorLogMessage)", pid: pid)
                    
                    infoToUpdate.status = .error(reason: "Nudge (Press) Failed: \\(errorLogMessage)")
                    infoToUpdate.statusMessage = "Error (Nudge Failed)"
                    instanceInfo[pid] = infoToUpdate
                }
            } else {
                let errorLogMessage = setValueResponse.error ?? "Unknown"
                logger.error("PID \\(pid): Nudge failed (set value). Error: \\(errorLogMessage)")
                await sessionLogger.log(level: .error, message: "PID \\(pid): Nudge failed (set value). Error: \\(errorLogMessage)", pid: pid)
                
                infoToUpdate.status = .error(reason: "Nudge (Set Value) Failed: \\(errorLogMessage)")
                infoToUpdate.statusMessage = "Error (Nudge Failed)"
                instanceInfo[pid] = infoToUpdate
            }
        } else {
            logger.warning("PID \\(pid): Nudge failed. 'mainInputField' locator not found.")
            await sessionLogger.log(level: .warning, message: "PID \\(pid): Nudge failed, main input field locator missing.", pid: pid)
            
            infoToUpdate.status = .error(reason: "Nudge Failed (Locator Missing)")
            infoToUpdate.statusMessage = "Error (Nudge Failed)"
            instanceInfo[pid] = infoToUpdate
        }
    }

    public func resetAllInstancesAndResume() async {
        logger.info("Resetting all instance counters and resuming paused instances.")
        await sessionLogger.log(level: .info, message: "User reset all instance counters and resumed paused instances.")
        
        totalAutomaticInterventionsThisSession = 0 

        for pid in instanceInfo.keys {
            await resumeInterventions(for: pid) 
            lastActivityTimestamp[pid] = Date() 
        }
    }
}