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

/// Monitors Cursor AI application instances and manages automated interventions.
///
/// CursorMonitor is the core component responsible for detecting and resolving
/// common issues in Cursor AI sessions, such as connection problems, stuck states,
/// and unresponsive UI elements.
///
/// ## Features
///
/// - Real-time monitoring of Cursor instances
/// - Automatic detection of stuck or error states
/// - Intelligent intervention strategies
/// - Configurable monitoring parameters
/// - Session logging and diagnostics
///
/// ## Topics
///
/// ### Monitoring Control
/// - ``startMonitoring()``
/// - ``stopMonitoring()``
/// - ``shared``
///
/// ### Monitored Apps
/// - ``monitoredApps``
/// - ``addApp(_:)``
/// - ``removeApp(_:)``
///
/// ### Configuration
/// - ``isMonitoring``
/// - ``monitoringTask``
///
/// ## Usage
///
/// ```swift
/// let monitor = CursorMonitor.shared
/// monitor.startMonitoring()
///
/// // Monitor will automatically detect and handle Cursor issues
/// ```
@MainActor
public class CursorMonitor: ObservableObject {
    // MARK: Lifecycle

    /// Creates a new CursorMonitor with the specified dependencies.
    ///
    /// - Parameters:
    ///   - axorcist: The AXorcist instance for accessibility operations
    ///   - sessionLogger: Logger for recording monitoring sessions
    ///   - locatorManager: Manager for UI element location strategies
    ///   - instanceStateManager: Manager for tracking instance states
    public init(
        axorcist: AXorcist,
        sessionLogger: SessionLogger,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager
    ) {
        self.axorcist = axorcist
        self.sessionLogger = sessionLogger
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.appLifecycleManager = CursorAppLifecycleManager(owner: self, sessionLogger: sessionLogger)
        self.interventionEngine = CursorInterventionEngine(
            monitor: self,
            axorcist: self.axorcist,
            sessionLogger: self.sessionLogger,
            locatorManager: self.locatorManager,
            instanceStateManager: self.instanceStateManager
        )

        self.logger.info("CursorMonitor initialized with all components.")
        self.sessionLogger.log(level: .info, message: "CursorMonitor initialized with all components.")

        // Initial setup
        self.monitoredApps = appLifecycleManager.monitoredApps

        // Setup subscriptions
        setupAppLifecycleSubscriptions()
        setupInstanceStateSubscriptions()
        setupMonitoringLoopSubscription()

        // Initialize system hooks
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

    // MARK: Public

    // Inject AXorcist from the main app dependency graph
    // This will be the single instance shared across the app.
    public static let shared = CursorMonitor(
        axorcist: AXorcist(),
        sessionLogger: SessionLogger.shared,
        locatorManager: LocatorManager.shared,
        instanceStateManager: CursorInstanceStateManager(sessionLogger: SessionLogger.shared)
    )

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
                    MonitoredWindowInfo(id: "w2", windowTitle: "Settings Preview", axElement: nil, isPaused: true),
                ]
            )
            previewMonitor.monitoredApps = [mockApp]
            previewMonitor.totalAutomaticInterventionsThisSessionDisplay = 5
            // previewMonitor.isMonitoringActive = true // isMonitoringActive is internal
            return previewMonitor
        }()
    #endif

    public let axorcist: AXorcist
    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    @Published public var monitoredApps: [MonitoredAppInfo] = []

    // totalAutomaticInterventionsThisSession is now managed by instanceStateManager
    // but we still need a @Published property here to update the UI.
    // It will be kept in sync via a Combine subscription.
    @Published public var totalAutomaticInterventionsThisSessionDisplay: Int = 0

    public var appLifecycleManager: CursorAppLifecycleManager!

    public var isMonitoringActivePublic: Bool { isMonitoringActive } // For CursorAppLifecycleManager

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
        sessionLogger.log(
            level: .info,
            message: "Monitoring loop started with interval \(Defaults[.monitoringIntervalSeconds])s."
        )

        monitoringTask = Task { [weak self] in
            while let self, self.isMonitoringActive, !Task.isCancelled {
                if self.monitoredApps.isEmpty {
                    self.logger.info("No active Cursor instances. Stopping monitoring loop from within.")
                    self.sessionLogger.log(
                        level: .info,
                        message: "No active Cursor instances. Monitoring loop will stop."
                    )
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
                        self.sessionLogger.log(
                            level: .error,
                            message: "Monitoring loop sleep failed: \(error.localizedDescription)"
                        )
                    }
                }
            }
            if let strongSelf = self {
                strongSelf.logger.info("Monitoring loop finished.")
                strongSelf.sessionLogger.log(level: .info, message: "Monitoring loop finished.")
            } else {
                Diagnostics.Logger(category: .supervision)
                    .info("Monitoring loop finished, but CursorMonitor instance was deallocated.")
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

    public func mapCursorStatusToDisplayStatus(_ status: CursorInstanceStatus) -> DisplayStatus {
        switch status {
        case .unknown: .unknown
        case .working: .positiveWork // Or .active if "working" is too specific for general activity
        case .idle: .idle
        case .recovering: .intervening // Or .observation depending on context post-recovery attempt
        case .error: .pausedUnrecoverable // Map general error to pausedUnrecoverable for UI
        case .unrecoverable: .pausedUnrecoverable
        case .paused: .pausedInterventionLimit // This is for intervention limit pause.
            // Missing: How to map to .pausedManually from CursorInstanceStatus if it only has .paused?
            // Add a check here if needed, or rely on instanceStateManager.isManuallyPaused for distinct UI in popover.
        }
    }

    // Called from AppDelegate or similar UI context
    @MainActor
    public func updateInstanceDisplayInfo(for _: pid_t, newStatus _: DisplayStatus, interventionCount _: Int) {
        // ... existing code ...
    }

    // Placeholder for per-window pause/resume
    public func pauseMonitoring(for windowId: String, in pid: pid_t) {
        guard let appIndex = monitoredApps.firstIndex(where: { $0.pid == pid }),
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId })
        else {
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
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId })
        else {
            logger.warning("Window ID \(windowId) in PID \(pid) not found for resuming.")
            return
        }
        monitoredApps[appIndex].windows[windowIndex].isPaused = false
        logger.info("Resumed monitoring for window ID \(windowId) in PID \(pid)")
        objectWillChange.send()
    }

    // MARK: Internal

    // These are accessed and mutated on the MainActor due to the class being @MainActor
    var isMonitoringActive: Bool = false // Changed from private to internal (default)

    // MARK: Private

    private let logger = Diagnostics.Logger(category: .supervision)
    private var axApplicationObserver: AXApplicationObserver!
    private var monitoringTask: Task<Void, Error>?
    private let sessionLogger: SessionLogger
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private var monitoringCycleCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var interventionEngine: CursorInterventionEngine!
    private var tickUseCases: [pid_t: ProcessMonitoringTickUseCase] = [:]

    private func setupAppLifecycleSubscriptions() {
        // Subscribe to updates from AppLifecycleManager
        appLifecycleManager.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAppsFromManager in
                guard let self else { return }
                self.updateMonitoredApps(with: newAppsFromManager)
            }
            .store(in: &cancellables)
    }

    private func setupInstanceStateSubscriptions() {
        // Subscribe to totalAutomaticInterventionsThisSession from instanceStateManager
        instanceStateManager.$totalAutomaticInterventionsThisSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTotal in
                self?.totalAutomaticInterventionsThisSessionDisplay = newTotal
            }
            .store(in: &cancellables)
    }

    private func setupMonitoringLoopSubscription() {
        // Subscribe to own monitoredApps to manage the monitoring loop
        $monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                self.handleMonitoredAppsChange(apps)
            }
            .store(in: &cancellables)
    }

    private func updateMonitoredApps(with newAppsFromManager: [MonitoredAppInfo]) {
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

    private func handleMonitoredAppsChange(_ apps: [MonitoredAppInfo]) {
        if !apps.isEmpty, !self.isMonitoringActive {
            self.logger.info("Monitored apps list became non-empty. Starting monitoring loop.")
            self.startMonitoringLoop()
        } else if apps.isEmpty, self.isMonitoringActive {
            self.logger.info("Monitored apps list became empty. Stopping monitoring loop.")
            self.stopMonitoringLoop()
        }
    }

    private func performMonitoringCycle() async {
        guard !monitoredApps.isEmpty else {
            logger.info("No monitored apps, skipping monitoring cycle.")
            return
        }

        // Only log every 10th cycle to reduce verbosity
        if monitoringCycleCount % 10 == 0 {
            logger.debug("Monitoring cycle #\(monitoringCycleCount): \(monitoredApps.count) app(s)")
        }
        monitoringCycleCount += 1

        // First, update window information for all monitored apps
        await processMonitoredApps() // This updates the .windows property of each app in monitoredApps

        // Existing intervention logic would go here, iterating through apps and their windows
        for appInfo in monitoredApps {
            // If you need to operate on windows, iterate appInfo.windows
            if monitoringCycleCount % 10 == 0 {
                logger
                    .debug(
                        "Processing app: \(appInfo.displayName) (PID: \(appInfo.pid)) with \(appInfo.windows.count) windows."
                    )
            }

            // Example: If intervention logic is per-app based on aggregated window states or app-level checks
            // let currentStatus = instanceStateManager.getStatus(for: appInfo.pid)
            // ... decision logic ...

            // If intervention logic is per-window:
            for windowInfo in appInfo.windows {
                if monitoringCycleCount % 10 == 0 {
                    logger.debug("  Window: \(windowInfo.windowTitle ?? "N/A")")
                }
                // ... intervention logic for this specific window ...
                // This might involve using instanceStateManager with a window-specific ID if needed
            }
        }

        // Update total intervention count for display
        self.totalAutomaticInterventionsThisSessionDisplay = instanceStateManager
            .getTotalAutomaticInterventionsThisSession()
    }

    private func getPrimaryDisplayableText(axElement: AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXPlaceholderValueAttribute as String,
            kAXHelpAttribute as String,
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
            kAXDescriptionAttribute as String,
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

    @MainActor
    private func updateInstanceDisplayInfo(
        for pid: pid_t,
        newStatus: DisplayStatus,
        message _: String? = nil,
        isActive: Bool? = nil,
        interventionCount: Int? = nil
    ) {
        guard let index = monitoredApps.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to update display info for unknown PID: \(pid)")
            return
        }

        var updatedInfo = monitoredApps[index]
        updatedInfo.status = newStatus

        if let isActive {
            updatedInfo.isActivelyMonitored = isActive
        }

        if let interventionCount {
            updatedInfo.interventionCount = interventionCount
        }

        monitoredApps[index] = updatedInfo
    }

    // Method to fetch and update window list for a given app PID
    private func updateWindows(for appInfo: inout MonitoredAppInfo) async {
        guard let appElement = applicationElement(forProcessID: appInfo.pid) else {
            logger.warning("Could not get application element for PID \(appInfo.pid) to fetch windows.")
            appInfo.windows = []
            return
        }

        if monitoringCycleCount % 10 == 0 {
            logger
                .debug(
                    "Attempting to fetch windows for PID \(appInfo.pid) using element: \(appElement.briefDescription())"
                )
        }
        guard let windowElements: [Element] = appElement.windows() else {
            if monitoringCycleCount % 10 == 0 {
                logger
                    .debug(
                        "Application PID \(appInfo.pid) has no windows or failed to fetch (appElement.windows() returned nil)."
                    )
            }
            appInfo.windows = []
            return
        }

        if monitoringCycleCount % 10 == 0 {
            logger.debug("Fetched \(windowElements.count) raw window elements for PID \(appInfo.pid).")
        }

        var newWindowInfos: [MonitoredWindowInfo] = []
        for (index, windowElement) in windowElements.enumerated() {
            let title: String? = windowElement.title()
            // Using a stable ID if possible, otherwise index. AXUIElement itself isn't directly hashable/identifiable
            // for SwiftUI Identifiable easily.
            // A proper unique ID might involve hashing element properties or using its accessibility identifier if
            // available.
            // For now, using index within the current fetch combined with PID as a temporary unique key if no title.
            let windowId = "\(appInfo.pid)-window-\(title ?? "untitled")-\(index)"
            newWindowInfos.append(MonitoredWindowInfo(
                id: windowId,
                windowTitle: title,
                axElement: windowElement,
                isPaused: false
            )) // Pass AX element and default isPaused
        }
        appInfo.windows = newWindowInfos
        if monitoringCycleCount % 10 == 0 {
            logger
                .debug(
                    "Updated \(newWindowInfos.count) windows for PID \(appInfo.pid). Titles: \(newWindowInfos.map { $0.windowTitle ?? "N/A" })"
                )
        }
    }

    // In your main monitoring loop or when an app is detected:
    private func processMonitoredApps() async {
        var newMonitoredApps = self.monitoredApps // Create a mutable copy
        for i in newMonitoredApps.indices {
            await updateWindows(for: &newMonitoredApps[i]) // Pass element of the copy
        }
        self.monitoredApps = newMonitoredApps // Reassign to publish changes
    }
}
