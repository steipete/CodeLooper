import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
import os
import SwiftUI

// Assuming AXApplicationObserver is in a place where it can be imported, or its relevant notifications are used.

// private let MONITORING_INTERVAL_SECONDS: TimeInterval = 5.0
// private let MAX_INTERVENTIONS_PER_POSITIVE_ACTIVITY: Int = 3
// private let MAX_CONNECTION_ISSUE_RETRIES: Int = 2
// private let MAX_CONSECUTIVE_RECOVERY_FAILURES: Int = 3

@MainActor
public class CursorMonitor: ObservableObject {
    private let logger = Diagnostics.Logger(category: .supervision)
    private var axApplicationObserver: AXApplicationObserver!
    private var monitoringTask: Task<Void, Error>?
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    
    // Inject AXorcist from the main app dependency graph
    // This will be the single instance shared across the app.
    public static let shared = CursorMonitor(
        axorcist: AXorcist(), 
        sessionLogger: SessionLogger.shared, 
        locatorManager: LocatorManager.shared,
        instanceStateManager: CursorInstanceStateManager(sessionLogger: SessionLogger.shared)
    )

    public let axorcist: AXorcist
    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    @Published public var monitoredInstances: [MonitoredInstanceInfo] = []
    
    // totalAutomaticInterventionsThisSession is now managed by instanceStateManager
    // but we still need a @Published property here to update the UI.
    // It will be kept in sync via a Combine subscription.
    @Published public var totalAutomaticInterventionsThisSessionDisplay: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    public var appLifecycleManager: CursorAppLifecycleManager!
    private var interventionEngine: CursorInterventionEngine!
    private var tickUseCases: [pid_t: ProcessMonitoringTickUseCase] = [:]

    // These are accessed and mutated on the MainActor due to the class being @MainActor
    var isMonitoringActive: Bool = false // Changed from private to internal (default)
    public var isMonitoringActivePublic: Bool { isMonitoringActive } // For CursorAppLifecycleManager

    // private var manuallyPausedPIDs: Set<pid_t> = [:]
    // private var automaticInterventionsSincePositiveActivity: [pid_t: Int] = [:]
    // @Published public var totalAutomaticInterventionsThisSession: Int = 0 -> Replaced with totalAutomaticInterventionsThisSessionDisplay
    // private var connectionIssueResumeButtonClicks: [pid_t: Int] = [:]
    // private var consecutiveRecoveryFailures: [pid_t: Int] = [:]
    // private var lastKnownSidebarStateHash: [pid_t: Int?] = [:]
    // private var lastActivityTimestamp: [pid_t: Date] = [:]
    // private var pendingObservationForPID: [pid_t: (startTime: Date, initialInterventionCountWhenObservationStarted: Int)] = [:]

    // Public initializer allowing AXorcist injection
    public init(axorcist: AXorcist, sessionLogger: SessionLogger, locatorManager: LocatorManager, instanceStateManager: CursorInstanceStateManager) {
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
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
        
        // Use sink instead of assign to avoid immediate updates during initialization
        appLifecycleManager.$instanceInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newInstanceInfo in
                self?.instanceInfo = newInstanceInfo
            }
            .store(in: &cancellables)
        
        appLifecycleManager.$monitoredInstances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMonitoredInstances in
                self?.monitoredInstances = newMonitoredInstances
            }
            .store(in: &cancellables)

        // Subscribe to totalAutomaticInterventionsThisSession from instanceStateManager
        instanceStateManager.$totalAutomaticInterventionsThisSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTotal in
                self?.totalAutomaticInterventionsThisSessionDisplay = newTotal
            }
            .store(in: &cancellables)

        appLifecycleManager.initializeSystemHooks()
    }

    deinit {
        logger.info("CursorMonitor deinitialized...")
        Task { @MainActor [weak self] in // Task is now @MainActor
            guard let strongSelf = self else { return }
            strongSelf.cancellables.forEach { $0.cancel() }
            strongSelf.cancellables.removeAll()
            strongSelf.stopMonitoringLoop() // Consolidate stopMonitoringLoop call here too
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
                    await MainActor.run {
                        self.appLifecycleManager.handleCursorTermination(appInstance)
                    }
                } else { // If NSRunningApplication can't find it, it means it's truly gone
                    self.didTerminateInstance(pid: pid) // Ensure state is cleaned up in instanceStateManager
                    await MainActor.run {
                        self.appLifecycleManager.instanceInfo.removeValue(forKey: pid)
                        self.appLifecycleManager.monitoredInstances.removeAll { $0.pid == pid }
                    }
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
                        await MainActor.run {
                            self.appLifecycleManager.instanceInfo[pid] = infoToUpdate
                            let displayStatus = self.mapCursorStatusToDisplayStatus(infoToUpdate.status)
                            self.updateInstanceDisplayInfo(for: pid, newStatus: displayStatus, interventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid))
                        }
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

            if var infoToUpdate = appLifecycleManager.instanceInfo[pid] {
                infoToUpdate.status = newStatus
                infoToUpdate.statusMessage = newStatusMessage
                await MainActor.run {
                    self.appLifecycleManager.instanceInfo[pid] = infoToUpdate // Update the source of truth

                    let displayStatus = self.mapCursorStatusToDisplayStatus(newStatus)
                    self.updateInstanceDisplayInfo(for: pid, newStatus: displayStatus, interventionCount: self.instanceStateManager.getAutomaticInterventions(for: pid))
                }
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
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXPlaceholderValueAttribute as String,
            kAXHelpAttribute as String
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
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String
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
        await MainActor.run {
            self.instanceInfo[pid] = info
        }
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
        Task { @MainActor in
            self.updateInstanceDisplayInfo(for: pid, newStatus: .pausedManually, isActive: false)
        }
    }
    
    public func resumeMonitoring(for pid: pid_t) {
        logger.info("Manually resuming monitoring for PID: \\(pid)")
        instanceStateManager.setManuallyPaused(pid: pid, paused: false)
        instanceStateManager.setLastActivityTimestamp(for: pid, date: Date()) // Treat resume as activity
        Task { @MainActor in
            self.updateInstanceDisplayInfo(for: pid, newStatus: .active, isActive: true)
        }
    }
    
    @MainActor
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
