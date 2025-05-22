import AppKit
import Combine
import OSLog
import AXorcistLib
import os
import Defaults
import SwiftUI
import Foundation
import ApplicationServices
import AXorcistLib

// Assuming AXApplicationObserver is in a place where it can be imported, or its relevant notifications are used.

// Constants previously here are now managed via Defaults.Keys
// private let MONITORING_INTERVAL_SECONDS: TimeInterval = 5.0
// private let MAX_INTERVENTIONS_PER_POSITIVE_ACTIVITY: Int = 3
// private let MAX_CONNECTION_ISSUE_RETRIES: Int = 2
// private let MAX_CONSECUTIVE_RECOVERY_FAILURES: Int = 3

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
    public let axorcist: AXorcistLib.AXorcist // Explicitly type with Lib
    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    @Published public var monitoredInstances: [MonitoredInstanceInfo] = []
    
    // totalAutomaticInterventionsThisSession is now managed by instanceStateManager
    // but we still need a @Published property here to update the UI.
    // It will be kept in sync via a Combine subscription.
    @Published public var totalAutomaticInterventionsThisSessionDisplay: Int = 0
    
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager // New
    private var appLifecycleManager: CursorAppLifecycleManager!
    private var interventionEngine: CursorInterventionEngine! // Added property

    // Removed state properties now in CursorInstanceStateManager:
    // private var manuallyPausedPIDs: Set<pid_t> = [:]
    // private var automaticInterventionsSincePositiveActivity: [pid_t: Int] = [:]
    // @Published public var totalAutomaticInterventionsThisSession: Int = 0 -> Replaced with totalAutomaticInterventionsThisSessionDisplay
    // private var connectionIssueResumeButtonClicks: [pid_t: Int] = [:]
    // private var consecutiveRecoveryFailures: [pid_t: Int] = [:]
    // private var lastKnownSidebarStateHash: [pid_t: Int?] = [:]
    // private var lastActivityTimestamp: [pid_t: Date] = [:]
    // private var pendingObservationForPID: [pid_t: (startTime: Date, initialInterventionCountWhenObservationStarted: Int)] = [:]

    // These are accessed and mutated on the MainActor due to the class being @MainActor
    private var monitoringTask: Task<Void, Never>?
    var isMonitoringActive: Bool = false // Changed from private to internal (default)
    public var isMonitoringActivePublic: Bool { isMonitoringActive } // For CursorAppLifecycleManager

    public init(axorcist: AXorcistLib.AXorcist, sessionLogger: SessionLogger, locatorManager: LocatorManager) {
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = CursorInstanceStateManager(sessionLogger: sessionLogger) // Initialize new manager
        self.appLifecycleManager = CursorAppLifecycleManager(owner: self, sessionLogger: sessionLogger)
        // Initialize interventionEngine
        self.interventionEngine = CursorInterventionEngine(
            monitor: self, 
            axorcist: self.axorcist, // Pass the instance's axorcist
            sessionLogger: self.sessionLogger, 
            locatorManager: self.locatorManager, 
            instanceStateManager: self.instanceStateManager
        )

        self.logger.info("CursorMonitor initialized with all components.")
        Task {
            await self.sessionLogger.log(level: .info, message: "CursorMonitor initialized with all components.")
        }
        
        appLifecycleManager.$instanceInfo
            .receive(on: DispatchQueue.main)
            .assign(to: &$instanceInfo)
        
        appLifecycleManager.$monitoredInstances
            .receive(on: DispatchQueue.main)
            .assign(to: &$monitoredInstances)

        // Subscribe to totalAutomaticInterventionsThisSession from instanceStateManager
        instanceStateManager.$totalAutomaticInterventionsThisSession
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalAutomaticInterventionsThisSessionDisplay)

        appLifecycleManager.initializeSystemHooks()
    }

    deinit {
        logger.info("CursorMonitor deinitialized...")
        cancellables.forEach { $0.cancel() }
        Task { @MainActor [weak self] in
            self?.stopMonitoringLoop()
        }
    }

    public func didLaunchInstance(pid: pid_t) {
        logger.info("Instance PID \\(pid) launched, initializing states via instanceStateManager.")
        instanceStateManager.initializeState(for: pid)
    }

    public func didTerminateInstance(pid: pid_t) {
        logger.info("Instance PID \\(pid) terminated, cleaning up states via instanceStateManager.")
        instanceStateManager.cleanupState(for: pid)
    }
    
    public func refreshMonitoredInstances() {
        appLifecycleManager.refreshMonitoredInstances()
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
        logger.debug("Performing monitoring tick for \\(appLifecycleManager.instanceInfo.count) instance(s).")
        guard !appLifecycleManager.instanceInfo.isEmpty else {
            logger.debug("No instances to monitor in tick.")
            return
        }

        let pidsToProcess = Array(appLifecycleManager.instanceInfo.keys)
        
        for pid in pidsToProcess {
            guard let currentInfo = appLifecycleManager.instanceInfo[pid] else {
                logger.warning("PID \(pid) was in pidsToProcess but not found in instanceInfo. Skipping.")
                continue
            }
            
            guard let runningApp = NSRunningApplication(processIdentifier: pid), !runningApp.isTerminated else {
                logger.info("Instance PID \(pid) found terminated during tick, processing removal.")
                // This logic should ideally be centralized in appLifecycleManager or a dedicated handler
                // For now, keep it here but flag for potential future refactor if not already handled by appLifecycleManager's observation.
                if let appInstance = NSRunningApplication(processIdentifier: pid) { // Re-fetch in case it was found terminated just now
                    self.appLifecycleManager.handleCursorTermination(appInstance) 
                } else { // If NSRunningApplication can't find it, it means it's truly gone
                    self.didTerminateInstance(pid: pid) // Ensure state is cleaned up in instanceStateManager
                    self.appLifecycleManager.instanceInfo.removeValue(forKey: pid)
                    self.appLifecycleManager.monitoredInstances.removeAll { $0.pid == pid }
                }
                continue
            }

            // Check if manually paused before diving into the use case which might do AX queries
            if instanceStateManager.isManuallyPaused(pid: pid) {
                logger.debug("PID \(pid) is manually paused. Skipping deep check in this tick.")
                // Ensure UI reflects this state accurately if not already set
                if var infoToUpdate = appLifecycleManager.instanceInfo[pid] {
                    if infoToUpdate.status != .paused {
                        infoToUpdate.status = .paused
                        infoToUpdate.statusMessage = "Monitoring Paused (Manual)"
                        appLifecycleManager.instanceInfo[pid] = infoToUpdate
                        let displayStatus = mapCursorStatusToDisplayStatus(infoToUpdate.status)
                        updateInstanceDisplayInfo(for: pid, newStatus: displayStatus, interventionCount: instanceStateManager.getAutomaticInterventions(for: pid))
                    }
                }
                continue // Skip to next PID
            }

            let useCase = ProcessMonitoringTickUseCase(
                pid: pid,
                currentInfo: currentInfo,
                runningApp: runningApp,
                axorcist: self.axorcist,
                sessionLogger: self.sessionLogger,
                locatorManager: self.locatorManager,
                instanceStateManager: self.instanceStateManager,
                interventionEngine: self.interventionEngine,
                parentLogger: self.logger // Pass CursorMonitor's logger as parent
            )

            // All calls to interventionEngine methods are within useCase.execute(), which is async.
            // The execute() method itself is async, so the 'await' here covers those calls implicitly.
            let (newStatus, newStatusMessage, shouldStopProcessingPID) = await useCase.execute()

            if var infoToUpdate = appLifecycleManager.instanceInfo[pid] { // Re-fetch in case it was removed by termination logic
                infoToUpdate.status = newStatus
                infoToUpdate.statusMessage = newStatusMessage
                appLifecycleManager.instanceInfo[pid] = infoToUpdate // Update the source of truth

                let displayStatus = mapCursorStatusToDisplayStatus(newStatus)
                updateInstanceDisplayInfo(for: pid, newStatus: displayStatus, interventionCount: instanceStateManager.getAutomaticInterventions(for: pid))
            } else {
                logger.info("PID \(pid) no longer in instanceInfo after use case execution (likely terminated). Skipping UI update for it.")
            }

            if shouldStopProcessingPID {
                // This means the use case determined no further action is needed for this PID in this tick
                // (e.g., manually paused, unrecoverable, or intervention limit reached and handled within useCase)
                logger.debug("PID \(pid): Processing stopped for this tick based on use case result.")
                continue
            }

        } // end for pid in pidsToProcess
        logger.debug("Finished monitoring tick.")
    }

    private func getPrimaryDisplayableText(axElement: AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            AXAttributeNames.kAXValueAttribute as String,
            AXAttributeNames.kAXTitleAttribute as String,
            AXAttributeNames.kAXDescriptionAttribute as String,
            AXAttributeNames.kAXPlaceholderValueAttribute as String,
            AXAttributeNames.kAXHelpAttribute as String
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
    
    private func getSecondaryDisplayableText(axElement: AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            AXAttributeNames.kAXValueAttribute as String,
            AXAttributeNames.kAXTitleAttribute as String,
            AXAttributeNames.kAXDescriptionAttribute as String,
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    return stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
            }
        }
        return ""
    }

    public func resumeInterventions(for pid: pid_t) async {
        guard var info = instanceInfo[pid] else {
            logger.warning("Attempted to resume interventions for unknown PID: \\(pid)")
            return
        }
        logger.info("Resuming interventions for PID: \\(pid)")
        await sessionLogger.log(level: .info, message: "User resumed interventions for PID \\(pid).", pid: pid)
        
        instanceStateManager.initializeState(for: pid) // This resets all relevant counters and states
        info.status = .idle 
        info.statusMessage = "Idle (Resumed by User)"
        instanceStateManager.setLastActivityTimestamp(for: pid, date: Date()) // Also update last activity
        instanceInfo[pid] = info
    }

    public func resetAllInstancesAndResume() async {
        logger.info("Resetting all instance counters and resuming paused instances.")
        instanceStateManager.resetAllStatesAndSessionCounters() // This now handles total session too.

        for pid in instanceInfo.keys {
            await resumeInterventions(for: pid) // This re-initializes individual pid states and sets status to idle.
                                                // lastActivityTimestamp is set within resumeInterventions.
        }
    }
    
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
    
    public func pauseMonitoring(for pid: pid_t) {
        logger.info("Manually pausing monitoring for PID: \\(pid)")
        instanceStateManager.setManuallyPaused(pid: pid, paused: true)
        updateInstanceDisplayInfo(for: pid, newStatus: .pausedManually, isActive: false)
    }
    
    public func resumeMonitoring(for pid: pid_t) {
        logger.info("Manually resuming monitoring for PID: \\(pid)")
        instanceStateManager.setManuallyPaused(pid: pid, paused: false)
        instanceStateManager.setLastActivityTimestamp(for: pid, date: Date()) // Treat resume as activity
        updateInstanceDisplayInfo(for: pid, newStatus: .active, isActive: true)
    }
    
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
    
    public func mapCursorStatusToDisplayStatus(_ status: CursorInstanceStatus) -> DisplayStatus {
        switch status {
        case .unknown: return .unknown
        case .working: return .positiveWork // Or .active if "working" is too specific for general activity
        case .idle: return .idle
        case .recovering: return .intervening // Or .observation depending on context post-recovery attempt
        case .error: return .pausedUnrecoverable // Map general error to pausedUnrecoverable for UI
        case .unrecoverable: return .pausedUnrecoverable
        case .paused: return .pausedInterventionLimit // This is for intervention limit pause.
        // Missing: How to map to .pausedManually from CursorInstanceStatus if it only has .paused?
        // Add a check here if needed, or rely on instanceStateManager.isManuallyPaused for distinct UI in popover.
        }
    }

    // Called from AppDelegate or similar UI context
    @MainActor
    public func updateInstanceDisplayInfo(for pid: pid_t, newStatus: DisplayStatus, interventionCount: Int) {
        // ... existing code ...
    }
}