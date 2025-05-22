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
    @Published public var monitoredInstances: [MonitoredInstanceInfo] = []
    private var manuallyPausedPIDs: Set<pid_t> = []
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
    // New state for Post-Intervention Observation Window
    private var pendingObservationForPID: [pid_t: (startTime: Date, initialInterventionCountWhenObservationStarted: Int)] = [:]

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
        Task { @MainActor [weak self] in
            self?.stopMonitoringLoop()
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
        
        // Add to monitoredInstances for UI
        let monitoredInfo = MonitoredInstanceInfo(
            id: pid,
            pid: pid,
            displayName: "Cursor (PID: \(pid))",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0
        )
        monitoredInstances.append(monitoredInfo)
        
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
        
        // Remove from monitoredInstances
        monitoredInstances.removeAll { $0.pid == pid }
        
        // Remove from manuallyPausedPIDs if present
        manuallyPausedPIDs.remove(pid)
        
        automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
        connectionIssueResumeButtonClicks.removeValue(forKey: pid)
        consecutiveRecoveryFailures.removeValue(forKey: pid)
        lastKnownSidebarStateHash.removeValue(forKey: pid)
        lastActivityTimestamp.removeValue(forKey: pid)
        pendingObservationForPID.removeValue(forKey: pid)

        logger.info("Cursor instance terminated (PID: \\(pid)). Stopped monitoring for this instance.")
        Task {
            await sessionLogger.log(level: .info, message: "Cursor instance terminated (PID: \\(pid)). Stopped monitoring for this instance.")
        }
        
        if monitoredInstances.isEmpty && isMonitoringActive {
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
                 
                 // Remove from monitoredInstances
                 monitoredInstances.removeAll { $0.pid == pid }
                 
                 // Remove from manuallyPausedPIDs if present
                 manuallyPausedPIDs.remove(pid)
                 
                 automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
                 connectionIssueResumeButtonClicks.removeValue(forKey: pid)
                 consecutiveRecoveryFailures.removeValue(forKey: pid)
                 lastKnownSidebarStateHash.removeValue(forKey: pid)
                 lastActivityTimestamp.removeValue(forKey: pid)
                 pendingObservationForPID.removeValue(forKey: pid)
            }
        }
        scanForExistingInstances()
         if monitoredInstances.isEmpty && isMonitoringActive {
            logger.info("No more Cursor instances after refresh. Stopping monitoring loop.")
            stopMonitoringLoop()
        }
    }

    public func startMonitoringLoop() {
        guard !isMonitoringActive else {
            logger.info("Monitoring loop already active.")
            return
        }
        guard !monitoredInstances.isEmpty else {
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
                if self.monitoredInstances.isEmpty {
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

        // Create a copy to avoid mutation issues
        let pidsToProcess = Array(instanceInfo.keys)
        
        for pid in pidsToProcess {
            // Check if manually paused first
            if manuallyPausedPIDs.contains(pid) {
                logger.debug("Skipping PID \\(pid) - manually paused")
                updateInstanceDisplayInfo(for: pid, newStatus: .pausedManually, isActive: false)
                continue
            }
            
            guard let currentInfo = instanceInfo[pid] else { continue }
            
            guard let runningApp = NSRunningApplication(processIdentifier: pid), !runningApp.isTerminated else {
                logger.info("Instance PID \\(pid) found terminated during tick, removing.")
                // Use a local variable for app if it might be nil after the guard
                if let appToTerminate = NSRunningApplication(processIdentifier: pid) {
                    handleCursorTermination(appToTerminate)
                } else {
                    // If app is not running, directly remove info
                    if instanceInfo.removeValue(forKey: pid) != nil {
                        // Remove from monitoredInstances
                        monitoredInstances.removeAll { $0.pid == pid }
                        
                        // Remove from manuallyPausedPIDs if present
                        manuallyPausedPIDs.remove(pid)
                        
                        automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
                        connectionIssueResumeButtonClicks.removeValue(forKey: pid)
                        consecutiveRecoveryFailures.removeValue(forKey: pid)
                        lastKnownSidebarStateHash.removeValue(forKey: pid)
                        lastActivityTimestamp.removeValue(forKey: pid)
                        pendingObservationForPID.removeValue(forKey: pid) // Clean up observation state too
                        Task { await sessionLogger.log(level: .info, message: "Instance PID \\(pid) terminated and removed.", pid: pid) }
                    }
                }
                continue
            }

            logger.debug("Checking instance PID \\(pid). Current status: \\(currentInfo.status)")
            await sessionLogger.log(level: .debug, message: "Checking Cursor instance (PID: \\(pid)). Current status: \\(currentInfo.status)", pid: pid)

            var newStatus: CursorInstanceStatus = currentInfo.status
            var newStatusMessage: String = currentInfo.statusMessage
            var interventionMadeThisTick = false // Keep this flag to track if an intervention happened for failure cycle detection

            // 0. Handle Post-Intervention Observation Window if active
            if let observationInfo = pendingObservationForPID[pid] {
                if Date().timeIntervalSince(observationInfo.startTime) > Defaults[.postInterventionObservationWindowSeconds] {
                    let currentInterventionCount = automaticInterventionsSincePositiveActivity[pid, default: 0]
                    // Check if positive activity occurred (counter reset) OR if it incremented but wasn't reset by *this specific* intervention observation.
                    // This means if currentInterventionCount > 0 (not reset) AND it's the same or higher than when observation started.
                    if currentInterventionCount > 0 && currentInterventionCount >= observationInfo.initialInterventionCountWhenObservationStarted {
                        consecutiveRecoveryFailures[pid, default: 0] += 1
                        logger.info("PID \\(pid): Post-intervention observation window ended without positive activity. Consecutive failures: \\(consecutiveRecoveryFailures[pid, default: 0])")
                        await sessionLogger.log(level: .warning, message: "Post-intervention observation window ended without positive activity. Consecutive failures incremented.", pid: pid)
                    }
                    pendingObservationForPID.removeValue(forKey: pid) // End observation
                }
            }

            // 1. Unrecoverable State Check (Spec 2.3.1)
            if case .unrecoverable(let actualReason) = currentInfo.status {
                logger.warning("PID \\(pid) is in unrecoverable state: \\(actualReason). Skipping further checks.")
                await sessionLogger.log(level: .warning, message: "PID \\(pid) is unrecoverable: \\(actualReason)", pid: pid)
                newStatus = .unrecoverable(reason: actualReason)
                newStatusMessage = "Unrecoverable: \\(actualReason)"
                continue
            }
            if case .paused = currentInfo.status {
                logger.info("PID \\(pid) is paused. Skipping further checks.")
                await sessionLogger.log(level: .info, message: "PID \\(pid) is paused. Skipping checks.", pid: pid)
                newStatus = .paused
                newStatusMessage = "Paused (Intervention Limit Reached)"
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
                continue
            }
            
            var tempLogs: [String] = []
            var isShowingPositiveWork = false

            // Try to find a generating indicator first.
            if let generatingIndicatorLocator = await locatorManager.getLocator(for: .generatingIndicatorText, pid: pid) {
                let response = axorcist.handleQuery(
                    for: nil,
                    locator: generatingIndicatorLocator,
                    pathHint: nil,
                    maxDepth: 10,
                    requestedAttributes: nil,
                    outputFormat: nil,
                    isDebugLoggingEnabled: true,
                    currentDebugLogs: &tempLogs
                )
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
                pendingObservationForPID.removeValue(forKey: pid) // Positive work ends observation
                
                // Update UI immediately for positive work
                updateInstanceDisplayInfo(for: pid, newStatus: .positiveWork, interventionCount: 0)
            } else {
                 newStatus = .idle
                 newStatusMessage = "Idle (Monitoring)"
            }

            if !isShowingPositiveWork {
                var detectedStuckMessageText: String? = nil
                if let errorMessageLocator = await locatorManager.getLocator(for: .errorMessagePopup, pid: pid) {
                    let response = axorcist.handleQuery(
                        for: nil,
                        locator: errorMessageLocator,
                        pathHint: nil,
                        maxDepth: 10,
                        requestedAttributes: nil,
                        outputFormat: nil,
                        isDebugLoggingEnabled: true,
                        currentDebugLogs: &tempLogs
                    )
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
                    if let stopButtonLocator = await locatorManager.getLocator(for: .stopGeneratingButton, pid: pid) {
                        logger.info("PID \\(pid): Attempting to click 'Stop Generating' button for stuck state.")
                        await sessionLogger.log(level: .info, message: "PID \\(pid): Attempting to click 'Stop Generating' for stuck state.", pid: pid)
                        let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                        newStatus = .recovering(type: .stopGenerating, attempt: attempts)
                        newStatusMessage = "Clicked Stop Generating. Observing..."
                        
                        let performResponse = axorcist.handlePerformAction(
                            for: nil,
                            locator: stopButtonLocator,
                            pathHint: nil,
                            actionName: "AXPress",
                            actionValue: nil,
                            maxDepth: 10,
                            isDebugLoggingEnabled: true,
                            currentDebugLogs: &tempLogs
                        )
                        if performResponse.error == nil {
                            logger.info("PID \\(pid): Successfully clicked 'Stop Generating' button.")
                            await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Stop Generating' button.", pid: pid)
                            automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                            totalAutomaticInterventionsThisSession += 1
                            // Store the count *before* this increment
                            pendingObservationForPID[pid] = (startTime: Date(), initialInterventionCountWhenObservationStarted: automaticInterventionsSincePositiveActivity[pid, default: 0] -1)
                            updateInstanceDisplayInfo(for: pid, newStatus: .observation)
                            if Defaults[.playSoundOnIntervention] {
                                await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName])
                            }
                            AppIconStateController.shared.flashIcon()
                            lastActivityTimestamp[pid] = Date() // Update activity timestamp
                            interventionMadeThisTick = true
                        } else {
                            let errorDesc = performResponse.error ?? "Unknown error"
                            logger.error("PID \\(pid): Failed to click 'Stop Generating' button. Error: \\(errorDesc)")
                            _ = errorDesc
                            let errorDesc2 = performResponse.error ?? "Unknown error"
                            await sessionLogger.log(level: .error, message: "PID \\(pid): Failed to click 'Stop Generating'. Error: \\(errorDesc2)", pid: pid)
                            _ = errorDesc2
                            let errorDesc3 = performResponse.error ?? "Unknown error"
                            newStatus = .error(reason: "Failed to click 'Stop Generating' button: \\(errorDesc3)")
                            _ = errorDesc3
                            newStatusMessage = "Error (Failed Action)"
                        }
                    } else {
                        logger.warning("PID \\(pid): Stuck message detected, but 'stopGeneratingButton' locator not found.")
                        newStatus = .error(reason: "Stuck, but Stop button locator missing")
                        newStatusMessage = "Error (Locator Missing)"
                    }
                }
            }

            if !isShowingPositiveWork && !(newStatus.isRecovering(ofAnyType: [.stopGenerating])) {
                if Defaults[.monitorSidebarActivity] {
                    guard let sidebarLocator = await locatorManager.getLocator(for: .sidebarActivityArea, pid: pid) else {
                        logger.debug("PID \\(pid): Sidebar locator not available")
                        tempLogs.removeAll()
                        lastKnownSidebarStateHash[pid] = nil
                        continue
                    }
                    let response = axorcist.handleQuery(
                        for: nil,
                        locator: sidebarLocator,
                        pathHint: nil,
                        maxDepth: Defaults[.sidebarActivityMaxDepth],
                        requestedAttributes: nil,
                        outputFormat: nil,
                        isDebugLoggingEnabled: true,
                        currentDebugLogs: &tempLogs
                    )

                    if response.error != nil {
                        let errorDesc = response.error ?? "No error description"
                        logger.debug("PID \\(pid): Sidebar query failed or element not found. Error: \\(errorDesc)")
                        _ = errorDesc
                        let errorDesc2 = response.error ?? "No error description"
                        Task { await sessionLogger.log(level: .debug, message: "Sidebar query failed or element not found. Error: \\(errorDesc2)", pid: pid) }
                        _ = errorDesc2
                        tempLogs.removeAll()
                        lastKnownSidebarStateHash[pid] = nil
                    } else {
                        let sidebarTextRepresentation = getTextualRepresentation(for: response.data, depth: 0, maxDepth: Defaults[.sidebarActivityMaxDepth])
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
                            pendingObservationForPID.removeValue(forKey: pid) // Positive work/activity ends observation
                            
                            // Update UI for sidebar activity
                            updateInstanceDisplayInfo(for: pid, newStatus: .positiveWork, interventionCount: 0)
                        } else if lastKnownSidebarStateHash[pid] == nil {
                            logger.debug("PID \\(pid): Initial sidebar state observed or re-observed after nil. Hash: \\(currentHash)")
                        }
                        lastKnownSidebarStateHash[pid] = currentHash
                    }
                }
            }

            // Before general stuck check, handle specific error scenarios first

            // G. Cursor Force-Stopped / Not Responding
            let shouldProceedToStuckDetectionNotForceStopped = false

            if !isShowingPositiveWork && !newStatus.isRecovering() {
                if Defaults[.enableCursorForceStoppedRecovery] {
                    if let forceStopLocator = await locatorManager.getLocator(for: .forceStopResumeLink, pid: pid) {
                        let response = axorcist.handleQuery(
                            for: nil,
                            locator: forceStopLocator,
                            pathHint: nil,
                            maxDepth: 10,
                            requestedAttributes: nil,
                            outputFormat: nil,
                            isDebugLoggingEnabled: true,
                            currentDebugLogs: &tempLogs
                        )
                        if let _ = response.data { // Element found
                            logger.info("PID \\(pid): Detected 'Force-Stop / Resume Conversation' state. Attempting to click.")
                            await sessionLogger.log(level: .info, message: "PID \\(pid): Detected 'Force-Stop / Resume Conversation' state. Attempting to click.", pid: pid)
                            
                            let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                            newStatus = .recovering(type: .forceStop, attempt: attempts)
                            newStatusMessage = "Clicked force-stop resume. Observing..."
                            instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)

                            let performResponse = axorcist.handlePerformAction(
                                for: nil,
                                locator: forceStopLocator,
                                pathHint: nil,
                                actionName: "AXPress",
                                actionValue: nil,
                                maxDepth: 10,
                                isDebugLoggingEnabled: true,
                                currentDebugLogs: &tempLogs
                            )
                            if performResponse.error == nil {
                                logger.info("PID \\(pid): Successfully clicked 'Force-Stop / Resume Conversation' element.")
                                await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Force-Stop / Resume Conversation' element.", pid: pid)
                                automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                                totalAutomaticInterventionsThisSession += 1
                                // Store the count *before* this increment
                                pendingObservationForPID[pid] = (startTime: Date(), initialInterventionCountWhenObservationStarted: automaticInterventionsSincePositiveActivity[pid, default: 0] -1)
                                updateInstanceDisplayInfo(for: pid, newStatus: .observation)
                                if Defaults[.playSoundOnIntervention] {
                                    await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName])
                                }
                                AppIconStateController.shared.flashIcon()
                                lastActivityTimestamp[pid] = Date()
                                isShowingPositiveWork = true // Assume this resolves the immediate issue
                                interventionMadeThisTick = true
                            } else {
                                let errorDesc = performResponse.error ?? "Unknown error"
                                logger.error("PID \\(pid): Failed to click 'Force-Stop / Resume Conversation' element. Error: \\(errorDesc)")
                                _ = errorDesc
                                let errorDesc2 = performResponse.error ?? "Unknown error"
                                await sessionLogger.log(level: .error, message: "PID \\(pid): Failed to click 'Force-Stop / Resume Conversation'. Error: \\(errorDesc2)", pid: pid)
                                _ = errorDesc2
                                let errorDesc3 = performResponse.error ?? "Unknown error"
                                newStatus = .error(reason: "Failed to click 'Force-Stop / Resume Conversation' element: \\(errorDesc3)")
                                _ = errorDesc3
                                newStatusMessage = "Error (Failed Action)"
                                instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)
                            }
                        } else if response.error != nil {
                            logger.debug("PID \(pid): 'forceStopResumeLink' query failed. Error: \(response.error ?? "Unknown Error")")
                        }
                    }
                }
            }
            
            if shouldProceedToStuckDetectionNotForceStopped || (!isShowingPositiveWork && newStatus != .recovering(type: .forceStop, attempt: 0) ) { // Simplified logic
                // F. Connection Issues Check
                let shouldProceedToStuckDetection = false

                if !isShowingPositiveWork && !newStatus.isRecovering() {
                    if Defaults[.enableConnectionIssuesRecovery] {
                        var detectedConnectionIssueFlagForIntervention = false
                        if let connectionErrorTextLocator = await locatorManager.getLocator(for: .connectionErrorIndicator, pid: pid) {
                            let response = axorcist.handleQuery(
                                for: nil,
                                locator: connectionErrorTextLocator,
                                pathHint: nil,
                                maxDepth: 10,
                                requestedAttributes: nil,
                                outputFormat: nil,
                                isDebugLoggingEnabled: true,
                                currentDebugLogs: &tempLogs
                            )
                            if let axData = response.data {
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
                                if let resumeButtonLocator = await locatorManager.getLocator(for: .resumeConnectionButton, pid: pid) {
                                    let attemptCount = currentRetries + 1
                                    logger.info("PID \\(pid): Attempting to click 'Resume' button for connection issue (attempt \\(attemptCount)/\\(maxRetries)).")
                                    await sessionLogger.log(level: .info, message: "PID \\(pid): Attempting 'Resume' for connection (attempt \\(attemptCount)/\\(maxRetries)).", pid: pid)
                                    
                                    newStatus = .recovering(type: .connection, attempt: attemptCount)
                                    newStatusMessage = "Attempted to resume connection. Observing..."
                                    instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)

                                    let performResponse = axorcist.handlePerformAction(
                                        for: nil,
                                        locator: resumeButtonLocator,
                                        pathHint: nil,
                                        actionName: "AXPress",
                                        actionValue: nil,
                                        maxDepth: 10,
                                        isDebugLoggingEnabled: true,
                                        currentDebugLogs: &tempLogs
                                    )
                                    if performResponse.error == nil {
                                        logger.info("PID \\(pid): Successfully clicked 'Resume' button for connection issue.")
                                        await sessionLogger.log(level: .info, message: "PID \\(pid): Clicked 'Resume' for connection.", pid: pid)
                                        connectionIssueResumeButtonClicks[pid, default: 0] += 1
                                        automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                                        totalAutomaticInterventionsThisSession += 1
                                        // Store the count *before* this increment
                                        pendingObservationForPID[pid] = (startTime: Date(), initialInterventionCountWhenObservationStarted: automaticInterventionsSincePositiveActivity[pid, default: 0] -1)
                                        updateInstanceDisplayInfo(for: pid, newStatus: .observation)
                                        if Defaults[.playSoundOnIntervention] {
                                            await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName])
                                        }
                                        AppIconStateController.shared.flashIcon()
                                        lastActivityTimestamp[pid] = Date()
                                        isShowingPositiveWork = true // Assume this resolves the immediate issue
                                        interventionMadeThisTick = true
                                    } else {
                                        let errorDesc = performResponse.error ?? "Unknown error"
                                        logger.error("PID \\(pid): Failed to click 'Resume' button for connection issue. Error: \\(errorDesc)")
                                        _ = errorDesc
                                        let errorDesc2 = performResponse.error ?? "Unknown error"
                                        await sessionLogger.log(level: .error, message: "PID \\(pid): Failed 'Resume' click for connection. Error: \\(errorDesc2)", pid: pid)
                                        _ = errorDesc2
                                        let errorDesc3 = performResponse.error ?? "Unknown error"
                                        newStatus = .error(reason: "Failed to click 'Resume' button for connection issue: \\(errorDesc3)")
                                        _ = errorDesc3
                                        newStatusMessage = "Error (Failed Action)"
                                        instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)
                                    }
                                } else {
                                    logger.warning("PID \\(pid): Connection issue detected, but 'resumeConnectionButton' locator not found.")
                                    await sessionLogger.log(level: .warning, message: "PID \\(pid): Connection issue, but 'resumeConnectionButton' locator missing.", pid: pid)
                                    newStatus = .error(reason: "Connection Issue, but Resume locator missing")
                                    newStatusMessage = "Error (Locator Missing)"
                                    instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)
                                }
                            } else {
                                logger.error("PID \\(pid): Max retries (\\(maxRetries)) for connection issue reached. Escalating to 'Cursor Stops' recovery.")
                                await sessionLogger.log(level: .error, message: "PID \\(pid): Max connection retries (\\(maxRetries)). Escalating to nudge.", pid: pid)
                                connectionIssueResumeButtonClicks[pid] = 0 
                                
                                let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                                newStatus = .recovering(type: .stuck, attempt: attempts) 
                                newStatusMessage = "Recovering (Nudge after Connection Failures)"
                                instanceInfo[pid] = CursorInstanceInfo(app: runningApp, status: newStatus, statusMessage: newStatusMessage)
                                
                                let nudgeSuccessful = await nudgeInstance(pid: pid, app: runningApp)
                                if nudgeSuccessful {
                                    interventionMadeThisTick = true
                                    // Status and message are updated within nudgeInstance if successful
                                    // Fetch them back if nudgeInstance modified them directly
                                    if let updatedInfo = instanceInfo[pid] { // Reload info if nudge changed it
                                        newStatus = updatedInfo.status
                                        newStatusMessage = updatedInfo.statusMessage
                                    }
                                } else {
                                    // Nudge failed, status already set by nudgeInstance
                                    if let updatedInfo = instanceInfo[pid] { // Reload info if nudge changed it
                                        newStatus = updatedInfo.status
                                        newStatusMessage = updatedInfo.statusMessage
                                    }
                                }
                            }
                        }
                    }
                }
                
                if shouldProceedToStuckDetection || (!isShowingPositiveWork && newStatus != .recovering(type: .connection, attempt: 0) ) { // Simplified logic
                    // H. Cursor Stops / Stuck

                    if !isShowingPositiveWork && !newStatus.isRecovering() {
                        if Defaults[.enableCursorStopsRecovery] {
                            let stuckTimeout = Defaults[.stuckDetectionTimeoutSeconds]
                            if let lastActive = lastActivityTimestamp[pid],
                               Date().timeIntervalSince(lastActive) > stuckTimeout {
                                logger.info("PID \\(pid) detected as stuck (idle for > \\(stuckTimeout)s). Triggering 'Cursor Stops' recovery.")
                                await sessionLogger.log(level: .info, message: "PID \\(pid) detected as stuck (idle for > \\(stuckTimeout)s). Triggering recovery.", pid: pid)
                                
                                let attempts = (automaticInterventionsSincePositiveActivity[pid] ?? 0) + 1
                                newStatus = .recovering(type: .stuck, attempt: attempts)
                                newStatusMessage = "Recovering (Stuck - Nudging)"
                                
                                // Nudge instance will also start its own observation window if successful
                                let nudgeSuccessful = await nudgeInstance(pid: pid, app: runningApp)
                                if nudgeSuccessful {
                                    interventionMadeThisTick = true
                                    // Status and message are updated within nudgeInstance if successful
                                    // Fetch them back if nudgeInstance modified them directly
                                    if let updatedInfo = instanceInfo[pid] { // Reload info if nudge changed it
                                        newStatus = updatedInfo.status
                                        newStatusMessage = updatedInfo.statusMessage
                                    }
                                } else {
                                    // Nudge failed, status already set by nudgeInstance
                                    if let updatedInfo = instanceInfo[pid] { // Reload info if nudge changed it
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
            if interventionMadeThisTick {
                if !isShowingPositiveWork {
                    consecutiveRecoveryFailures[pid, default: 0] += 1
                    logger.warning("PID \\(pid): Intervention performed, but no immediate positive work observed. Consecutive failures: \\(consecutiveRecoveryFailures[pid, default: 0]).")
                    await sessionLogger.log(level: .warning, message: "PID \\(pid): Intervention made, no immediate positive work. Consecutive failures: \\(consecutiveRecoveryFailures[pid, default: 0]).", pid: pid)
                }
            }
            
            if isShowingPositiveWork {
                consecutiveRecoveryFailures[pid] = 0
            }

            let maxFailures = Defaults[.maxConsecutiveRecoveryFailures]
            if consecutiveRecoveryFailures[pid, default: 0] >= maxFailures {
                logger.error("PID \\(pid) reached max consecutive recovery failures (\\(consecutiveRecoveryFailures[pid, default: 0])/\\(maxFailures)).")
                await sessionLogger.log(level: .error, message: "PID \\(pid) reached max consecutive recovery failures (\\(consecutiveRecoveryFailures[pid, default: 0])/\\(maxFailures)).", pid: pid)
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
                
                // Update MonitoredInstanceInfo for UI
                let displayStatus = mapCursorStatusToDisplayStatus(newStatus)
                let interventionCount = automaticInterventionsSincePositiveActivity[pid] ?? 0
                updateInstanceDisplayInfo(
                    for: pid,
                    newStatus: displayStatus,
                    interventionCount: interventionCount
                )
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
        pendingObservationForPID.removeValue(forKey: pid)
        info.status = .idle 
        info.statusMessage = "Idle (Resumed by User)"
        lastActivityTimestamp[pid] = Date() 
        instanceInfo[pid] = info
    }

    public func nudgeInstance(pid: pid_t, app: NSRunningApplication) async -> Bool {
        guard let inputFieldLocator = await locatorManager.getLocator(for: .mainInputField, pid: pid) else {
            logger.warning("PID \\(pid): Main input field locator not found. Cannot nudge.")
            await sessionLogger.log(level: .warning, message: "Main input field locator not found. Cannot nudge.", pid: pid)
            return false
        }

        let textToEnter = Defaults[.textForCursorStopsRecovery]
        
        // Use handlePerformAction to set the value
        var debugLogs: [String] = []
        let setValueResponse = axorcist.handlePerformAction(
            for: app.bundleIdentifier,
            locator: inputFieldLocator,
            pathHint: nil,
            actionName: "AXValue",
            actionValue: AXorcistLib.AnyCodable(textToEnter),
            maxDepth: nil,
            isDebugLoggingEnabled: true,
            currentDebugLogs: &debugLogs
        )
        
        var currentStatus: CursorInstanceStatus = .unknown
        var currentStatusMessage = "Nudge status update pending..."
        if let infoToUpdate = instanceInfo[pid] {
            currentStatus = infoToUpdate.status
            currentStatusMessage = infoToUpdate.statusMessage
        }

        if setValueResponse.error == nil {
            logger.info("PID \\(pid): Successfully set value in input field: '\\(textToEnter)'. Attempting to press Enter.")
            await sessionLogger.log(level: .info, message: "Successfully set value for nudge: '\\(textToEnter)'.", pid: pid)
            
            // Press Enter using Carbon events since AXorcist doesn't have pressKey
            let enterKeyPressed = await pressEnterKey()
            if enterKeyPressed {
                logger.info("PID \\(pid): Successfully pressed Enter after nudge.")
                await sessionLogger.log(level: .info, message: "Successfully pressed Enter for nudge.", pid: pid)
                automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
                totalAutomaticInterventionsThisSession += 1
                // Store the count *before* this increment
                pendingObservationForPID[pid] = (startTime: Date(), initialInterventionCountWhenObservationStarted: automaticInterventionsSincePositiveActivity[pid, default: 0] -1)
                updateInstanceDisplayInfo(for: pid, newStatus: .observation)
                lastActivityTimestamp[pid] = Date() // Consider this an activity
                connectionIssueResumeButtonClicks[pid] = 0 // Reset this as per spec
                if Defaults[.playSoundOnIntervention] {
                    await SoundManager.shared.playSound(soundName: Defaults[.successfulInterventionSoundName])
                }
                if Defaults[.flashIconOnIntervention] { AppIconStateController.shared.flashIcon() }
                currentStatus = .recovering(type: .stuck, attempt: automaticInterventionsSincePositiveActivity[pid, default: 0]) // Use .stuck for nudge
                currentStatusMessage = "Nudged with text. Observing..."
                if var infoToUpdate = instanceInfo[pid] {
                    infoToUpdate.status = currentStatus
                    infoToUpdate.statusMessage = currentStatusMessage
                    instanceInfo[pid] = infoToUpdate
                }
                return true
            } else {
                logger.warning("PID \\(pid): Failed to press Enter after nudge")
                await sessionLogger.log(level: .warning, message: "Failed to press Enter for nudge", pid: pid)
                currentStatus = .error(reason: "Nudge (Press Enter) Failed")
                currentStatusMessage = "Nudge failed (Enter key)."
                if var infoToUpdate = instanceInfo[pid] {
                    infoToUpdate.status = currentStatus
                    infoToUpdate.statusMessage = currentStatusMessage
                    instanceInfo[pid] = infoToUpdate
                }
                return false
            }
        } else {
            let errorDesc = setValueResponse.error ?? "Unknown error"
            logger.warning("PID \\(pid): Failed to set value in input field for nudge: \\(errorDesc)")
            _ = errorDesc
            let errorDesc2 = setValueResponse.error ?? "Unknown error"
            await sessionLogger.log(level: .warning, message: "Failed to set value for nudge: \\(errorDesc2)", pid: pid)
            _ = errorDesc2
            let errorDesc3 = setValueResponse.error ?? "Unknown error"
            currentStatus = .error(reason: "Nudge (Set Value) Failed: \\(errorDesc3)")
            _ = errorDesc3
            currentStatusMessage = "Nudge failed (set text)."
            if var infoToUpdate = instanceInfo[pid] {
                infoToUpdate.status = currentStatus
                infoToUpdate.statusMessage = currentStatusMessage
                instanceInfo[pid] = infoToUpdate
            }
            return false
        }
    }

    public func resetAllInstancesAndResume() async {
        logger.info("Resetting all instance counters and resuming paused instances.")
        await sessionLogger.log(level: .info, message: "User reset all instance counters and resumed paused instances.")
        
        totalAutomaticInterventionsThisSession = 0 

        for pid in instanceInfo.keys {
            await resumeInterventions(for: pid) 
            lastActivityTimestamp[pid] = Date() 
            pendingObservationForPID.removeValue(forKey: pid)
        }
    }
    
    // Helper method to press Enter key using Carbon events
    private func pressEnterKey() async -> Bool {
        let enterKeyCode: UInt16 = 36 // Enter key virtual key code
        
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: enterKeyCode, keyDown: true) else {
            logger.warning("Failed to create key down event for Enter key")
            return false
        }
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: enterKeyCode, keyDown: false) else {
            logger.warning("Failed to create key up event for Enter key")
            return false
        }
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay between key down and up
        try? await Task.sleep(for: .milliseconds(50))
        
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    // MARK: - Manual Pause/Resume Methods
    
    public func pauseMonitoring(for pid: pid_t) {
        logger.info("Manually pausing monitoring for PID: \\(pid)")
        Task {
            await sessionLogger.log(level: .info, message: "User manually paused monitoring for PID \\(pid).", pid: pid)
        }
        
        // Add to manually paused set
        manuallyPausedPIDs.insert(pid)
        
        // Update MonitoredInstanceInfo
        updateInstanceDisplayInfo(for: pid, newStatus: .pausedManually, isActive: false)
    }
    
    public func resumeMonitoring(for pid: pid_t) {
        logger.info("Manually resuming monitoring for PID: \\(pid)")
        Task {
            await sessionLogger.log(level: .info, message: "User manually resumed monitoring for PID \\(pid).", pid: pid)
        }
        
        // Remove from manually paused set
        manuallyPausedPIDs.remove(pid)
        
        // Update MonitoredInstanceInfo - reset to active
        updateInstanceDisplayInfo(for: pid, newStatus: .active, isActive: true)
    }
    
    // MARK: - Helper Methods
    
    private func updateInstanceDisplayInfo(
        for pid: pid_t,
        newStatus: DisplayStatus,
        message: String? = nil,
        isActive: Bool? = nil,
        interventionCount: Int? = nil
    ) {
        guard let index = monitoredInstances.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to update display info for unknown PID: \\(pid)")
            return
        }
        
        var updatedInfo = monitoredInstances[index]
        updatedInfo.status = newStatus
        
        if let isActive = isActive {
            updatedInfo.isActivelyMonitored = isActive
        }
        
        if let interventionCount = interventionCount {
            updatedInfo.interventionCount = interventionCount
        }
        
        monitoredInstances[index] = updatedInfo
    }
    
    private func mapCursorStatusToDisplayStatus(_ cursorStatus: CursorInstanceStatus) -> DisplayStatus {
        switch cursorStatus {
        case .unknown:
            return .unknown
        case .working:
            return .positiveWork
        case .idle:
            return .idle
        case .recovering:
            return .intervening
        case .error:
            return .idle // Map errors to idle for now
        case .unrecoverable:
            return .pausedUnrecoverable
        case .paused:
            return .pausedInterventionLimit
        }
    }
}