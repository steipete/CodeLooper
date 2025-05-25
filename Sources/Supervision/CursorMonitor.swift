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
    @Published public var monitoredApps: [MonitoredAppInfo] = []
    
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

#if DEBUG
    public static var sharedForPreview: CursorMonitor = {
        let previewMonitor = CursorMonitor(
            axorcist: AXorcist(), // Assuming AXorcist can be init'd simply
            sessionLogger: SessionLogger.shared, // Or a mock/preview version if available
            locatorManager: LocatorManager.shared, // Or mock
            instanceStateManager: CursorInstanceStateManager(sessionLogger: SessionLogger.shared) // Or mock
        )
        // Configure previewMonitor with some mock data
        let appPID = pid_t(12345)
        let mockApp = MonitoredAppInfo(
            id: appPID,
            pid: appPID,
            displayName: "Cursor (Preview)",
            status: .active, // Use a valid status
            isActivelyMonitored: true,
            interventionCount: 2,
            windows: [
                MonitoredWindowInfo(id: "w1", windowTitle: "Document Preview.txt", axElement: nil, isPaused: false),
                MonitoredWindowInfo(id: "w2", windowTitle: "Settings Preview", axElement: nil, isPaused: true)
            ]
        )
        previewMonitor.monitoredApps = [mockApp]
        previewMonitor.totalAutomaticInterventionsThisSessionDisplay = 5
        // previewMonitor.isMonitoringActive = true // isMonitoringActive is internal
        return previewMonitor
    }()
#endif

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
            axorcist: self.axorcist,
            sessionLogger: self.sessionLogger, 
            locatorManager: self.locatorManager, 
            instanceStateManager: self.instanceStateManager
        )

        self.logger.info("CursorMonitor initialized with all components.")
        self.sessionLogger.log(level: .info, message: "CursorMonitor initialized with all components.")
        
        // Initial setup based on current state of AppLifecycleManager
        self.monitoredApps = appLifecycleManager.monitoredApps.map { appInfo in
            let newAppInfo = appInfo
            return newAppInfo
        }

        // Subscribe to updates from AppLifecycleManager on its primary published list
        appLifecycleManager.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAppsFromManager in
                guard let self = self else { return }
                self.monitoredApps = newAppsFromManager.map { appInfo in
                    if let existingApp = self.monitoredApps.first(where: { $0.pid == appInfo.pid }) {
                        var updatedApp = appInfo
                        updatedApp.windows = existingApp.windows
                        return updatedApp
                    } else {
                        return appInfo
                    }
                }
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

        // Subscribe to updates from AppLifecycleManager
        appLifecycleManager.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAppsFromManager in
                guard let self = self else { return }
                // Reconcile newAppsFromManager with self.monitoredApps
                // This might involve adding, removing, or updating existing app entries.
                // For now, a simple replacement, but a more sophisticated merge might be needed
                // if CursorMonitor adds its own state to MonitoredAppInfo that isn't from AppLifecycleManager.
                self.monitoredApps = newAppsFromManager.map { appInfo in
                    // If we need to preserve window list or other state through this update:
                    if let existingApp = self.monitoredApps.first(where: { $0.pid == appInfo.pid }) {
                        var updatedApp = appInfo
                        updatedApp.windows = existingApp.windows // Preserve existing windows for now
                        // Potentially copy over other CursorMonitor-specific states if any
                        return updatedApp
                    } else {
                        return appInfo // New app
                    }
                }
                // Potentially trigger an immediate window scan for new apps if required here.
                // For example, if an app was just added, call `updateWindows` for it.
            }
            .store(in: &cancellables)
            
        // NEW: Subscribe to own monitoredApps to manage the monitoring loop
        $monitoredApps
            .receive(on: DispatchQueue.main) // Ensure changes are processed on main thread
            .sink { [weak self] apps in
                guard let self = self else { return }
                if !apps.isEmpty && !self.isMonitoringActive {
                    self.logger.info("Monitored apps list became non-empty. Starting monitoring loop.")
                    self.startMonitoringLoop()
                } else if apps.isEmpty && self.isMonitoringActive {
                    // The loop itself also has a check to stop if monitoredApps becomes empty,
                    // but this provides a more immediate stop if the list clears due to external factors.
                    self.logger.info("Monitored apps list became empty. Stopping monitoring loop.")
                    self.stopMonitoringLoop()
                }
            }
            .store(in: &cancellables)
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
        logger.info("Instance PID \(pid) launched, initializing states via instanceStateManager.")
        instanceStateManager.initializeState(for: pid)
    }

    public func didTerminateInstance(pid: pid_t) {
        logger.info("Instance PID \(pid) terminated, cleaning up states via instanceStateManager.")
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
        guard !monitoredApps.isEmpty else {
            logger.info("No Cursor instances to monitor. Loop not started.")
            return
        }

        isMonitoringActive = true
        logger.info("Starting monitoring loop with interval \(Defaults[.monitoringIntervalSeconds])s.")
        sessionLogger.log(level: .info, message: "Monitoring loop started with interval \(Defaults[.monitoringIntervalSeconds])s.")

        monitoringTask = Task { [weak self] in
            while let self = self, self.isMonitoringActive, !Task.isCancelled {
                if self.monitoredApps.isEmpty {
                    self.logger.info("No active Cursor instances. Stopping monitoring loop from within.")
                    self.sessionLogger.log(level: .info, message: "No active Cursor instances. Monitoring loop will stop.")
                    await MainActor.run { self.stopMonitoringLoop() }
                    break 
                }
                await self.performMonitoringCycle()
                do {
                    try await Task.sleep(for: .seconds(Defaults[.monitoringIntervalSeconds]))
                } catch {
                    if error is CancellationError {
                        self.logger.info("Monitoring loop sleep cancelled.")
                        self.sessionLogger.log(level: .info, message: "Monitoring loop sleep cancelled.")
                        break
                    } else {
                        self.logger.error("Monitoring loop sleep failed: \(error.localizedDescription)")
                        self.sessionLogger.log(level: .error, message: "Monitoring loop sleep failed: \(error.localizedDescription)")
                    }
                }
            }
            if let strongSelf = self {
                strongSelf.logger.info("Monitoring loop finished.")
                strongSelf.sessionLogger.log(level: .info, message: "Monitoring loop finished.")
            } else {
                Diagnostics.Logger(category: .supervision).info("Monitoring loop finished, but CursorMonitor instance was deallocated.")
            }
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
        sessionLogger.log(level: .info, message: "Monitoring loop stopped.")
    }

    private func performMonitoringCycle() async {
        guard !monitoredApps.isEmpty else {
            logger.info("No monitored apps, skipping monitoring cycle.")
            return
        }

        logger.info("Performing monitoring cycle for \(monitoredApps.count) app(s).")

        // First, update window information for all monitored apps
        await processMonitoredApps() // This updates the .windows property of each app in monitoredApps

        // Existing intervention logic would go here, iterating through apps and their windows
        for appInfo in monitoredApps {
            // If you need to operate on windows, iterate appInfo.windows
            logger.debug("Processing app: \(appInfo.displayName) (PID: \(appInfo.pid)) with \(appInfo.windows.count) windows.")
            
            // Example: If intervention logic is per-app based on aggregated window states or app-level checks
            // let currentStatus = instanceStateManager.getStatus(for: appInfo.pid)
            // ... decision logic ...

            // If intervention logic is per-window:
            for windowInfo in appInfo.windows {
                logger.debug("  Window: \(windowInfo.windowTitle ?? "N/A")")
                // ... intervention logic for this specific window ...
                // This might involve using instanceStateManager with a window-specific ID if needed
            }
        }
        
        // Update total intervention count for display
        self.totalAutomaticInterventionsThisSessionDisplay = instanceStateManager.getTotalAutomaticInterventionsThisSession()
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
            logger.warning("Attempted to resume interventions for unknown PID: \(pid)")
            return
        }
        logger.info("Resuming interventions for PID: \(pid)")
        sessionLogger.log(level: .info, message: "User resumed interventions for PID \(pid).", pid: pid)
        
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
        logger.info("Manually pausing monitoring for PID: \(pid)")
        instanceStateManager.setManuallyPaused(pid: pid, paused: true)
        Task { @MainActor in
            self.updateInstanceDisplayInfo(for: pid, newStatus: .pausedManually, isActive: false)
        }
    }
    
    public func resumeMonitoring(for pid: pid_t) {
        logger.info("Manually resuming monitoring for PID: \(pid)")
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
        guard let index = monitoredApps.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to update display info for unknown PID: \(pid)")
            return
        }
        
        var updatedInfo = monitoredApps[index]
        updatedInfo.status = newStatus
        
        if let isActive = isActive {
            updatedInfo.isActivelyMonitored = isActive
        }
        
        if let interventionCount = interventionCount {
            updatedInfo.interventionCount = interventionCount
        }
        
        monitoredApps[index] = updatedInfo
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

    // Method to fetch and update window list for a given app PID
    private func updateWindows(for appInfo: inout MonitoredAppInfo) async {
        guard let appElement = applicationElement(forProcessID: appInfo.pid) else {
            logger.warning("Could not get application element for PID \(appInfo.pid) to fetch windows.")
            appInfo.windows = []
            return
        }

        logger.debug("Attempting to fetch windows for PID \(appInfo.pid) using element: \(appElement.briefDescription())")
        guard let windowElements: [Element] = appElement.windows() else {
            logger.info("Application PID \(appInfo.pid) has no windows or failed to fetch (appElement.windows() returned nil).")
            appInfo.windows = []
            return
        }
        
        logger.info("Fetched \(windowElements.count) raw window elements for PID \(appInfo.pid).")

        var newWindowInfos: [MonitoredWindowInfo] = []
        for (index, windowElement) in windowElements.enumerated() {
            let title: String? = windowElement.title()
            // Using a stable ID if possible, otherwise index. AXUIElement itself isn't directly hashable/identifiable for SwiftUI Identifiable easily.
            // A proper unique ID might involve hashing element properties or using its accessibility identifier if available.
            // For now, using index within the current fetch combined with PID as a temporary unique key if no title.
            let windowId = "\(appInfo.pid)-window-\(title ?? "untitled")-\(index)" 
            newWindowInfos.append(MonitoredWindowInfo(id: windowId, windowTitle: title, axElement: windowElement, isPaused: false)) // Pass AX element and default isPaused
        }
        appInfo.windows = newWindowInfos
        logger.info("Updated \(newWindowInfos.count) windows for PID \(appInfo.pid). Titles: \(newWindowInfos.map { $0.windowTitle ?? "N/A" })")
    }

    // In your main monitoring loop or when an app is detected:
    private func processMonitoredApps() async {
        var newMonitoredApps = self.monitoredApps // Create a mutable copy
        for i in newMonitoredApps.indices {
            await updateWindows(for: &newMonitoredApps[i]) // Pass element of the copy
        }
        self.monitoredApps = newMonitoredApps // Reassign to publish changes
    }

    // Placeholder for per-window pause/resume
    public func pauseMonitoring(for windowId: String, in pid: pid_t) {
        guard let appIndex = monitoredApps.firstIndex(where: { $0.pid == pid }),
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId }) else {
            logger.warning("Window ID \(windowId) in PID \(pid) not found for pausing.")
            return
        }
        monitoredApps[appIndex].windows[windowIndex].isPaused = true
        logger.info("Paused monitoring for window ID \(windowId) in PID \(pid)")
        // Potentially need to trigger objectWillChange if monitoredApps doesn't auto-publish nested changes deeply.
        objectWillChange.send()
    }

    public func resumeMonitoring(for windowId: String, in pid: pid_t) {
        guard let appIndex = monitoredApps.firstIndex(where: { $0.pid == pid }),
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId }) else {
            logger.warning("Window ID \(windowId) in PID \(pid) not found for resuming.")
            return
        }
        monitoredApps[appIndex].windows[windowIndex].isPaused = false
        logger.info("Resumed monitoring for window ID \(windowId) in PID \(pid)")
        objectWillChange.send()
    }
}
