import AppKit
import Combine
import Defaults
import Diagnostics
import Foundation

// Forward declare CursorMonitor if needed for the owner reference, or ensure it's imported if in a different module (not the case here)
// class CursorMonitor {} // Placeholder if full import isn't desired yet, but direct reference is better.

@MainActor
public class CursorAppLifecycleManager: ObservableObject {
    private let logger = Diagnostics.Logger(category: .lifecycle)
    
    // Constants
    private let cursorBundleIdentifier = "com.todesktop.230313mzl4w4u92"

    // Store the app info directly, keyed by PID
    @Published public var runningAppInfo: [pid_t: MonitoredAppInfo] = [:]
    // Published list of MonitoredAppInfo for observers like CursorMonitor
    @Published public var monitoredApps: [MonitoredAppInfo] = []
    
    // Marking cancellables as nonisolated(unsafe) means we assert its access is externally synchronized
    // or that operations on it are inherently thread-safe. Storing and cancelling Combine publishers
    // should generally be safe.
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    
    private weak var owner: CursorMonitor? // Weak to avoid retain cycles
    private let sessionLogger: SessionLogger

    public init(owner: CursorMonitor, sessionLogger: SessionLogger) {
        self.owner = owner
        self.sessionLogger = sessionLogger
        self.logger.info("CursorAppLifecycleManager initialized for owner.")
        
        // Initial scan and observer setup will be called by owner after initialization
    }

    deinit {
        logger.info("CursorAppLifecycleManager deinitialized.")
        cancellables.forEach { $0.cancel() }
        // No need to explicitly removeAll if the instance is being deinitialized
    }

    public func initializeSystemHooks() {
        setupWorkspaceNotificationObservers()
        scanForExistingInstances()
    }

    // Placeholder methods to be filled
    func setupWorkspaceNotificationObservers() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier }
            .receive(on: DispatchQueue.main)
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

    func scanForExistingInstances() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.bundleIdentifier == cursorBundleIdentifier, !app.isTerminated {
                logger.info("Found existing Cursor instance (PID: \\(app.processIdentifier)) on scan.")
                handleCursorLaunch(app)
            }
        }
        if runningAppInfo.isEmpty {
            logger.info("No running Cursor instances found on initial scan.")
        }
        updatePublishedMonitoredApps() // Update published list
    }

    func handleCursorLaunch(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard runningAppInfo[pid] == nil else {
            logger.info("Instance PID \\(pid) already being monitored.")
            return
        }
        
        let appInfo = MonitoredAppInfo(
            id: pid,
            pid: pid,
            displayName: app.localizedName ?? "Cursor (PID: \\(pid))", // Use app's localized name
            status: .active, // Initial status
            isActivelyMonitored: true,
            interventionCount: 0,
            windows: [] // Windows will be populated by CursorMonitor
        )
        runningAppInfo[pid] = appInfo
        updatePublishedMonitoredApps() // Update published list
        
        owner?.didLaunchInstance(pid: pid)

        logger.info("Cursor instance launched (PID: \\(pid)). Manager processed launch.")
        Task {
            sessionLogger.log(level: .info, message: "Cursor instance launched (PID: \\(pid)). Manager processed launch.", pid: pid)
        }
        
        if let owner = self.owner, !owner.isMonitoringActivePublic {
             owner.startMonitoringLoop()
        }
    }

    func handleCursorTermination(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard runningAppInfo.removeValue(forKey: pid) != nil else {
            logger.info("Received termination for unmonitored PID \\(pid).")
            return
        }
        updatePublishedMonitoredApps() // Update published list
        
        owner?.didTerminateInstance(pid: pid)

        logger.info("Cursor instance terminated (PID: \\(pid)). Manager processed termination.")
        Task {
            sessionLogger.log(level: .info, message: "Cursor instance terminated (PID: \\(pid)). Manager processed termination.", pid: pid)
        }
        
        if let owner = self.owner, monitoredApps.isEmpty, owner.isMonitoringActivePublic { // Check new published list
            logger.info("No more Cursor instances. Signaling owner to stop monitoring loop.")
            owner.stopMonitoringLoop()
        }
    }

    public func refreshMonitoredInstances() { // Renaming to refreshRunningApps might be clearer
        logger.debug("Refreshing monitored apps list.")
        let currentlyRunningPIDs = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier }
            .map { $0.processIdentifier }
        
        let pidsToShutdown = Set(runningAppInfo.keys).subtracting(currentlyRunningPIDs)
        for pid in pidsToShutdown {
            if runningAppInfo.removeValue(forKey: pid) != nil {
                 logger.info("Instance PID \\(pid) no longer running (detected by refresh). Removing.")
                 Task { sessionLogger.log(level: .info, message: "Instance PID \\(pid) no longer running (detected by refresh). Removing.", pid: pid) }
                 owner?.didTerminateInstance(pid: pid)
            }
        }
        updatePublishedMonitoredApps() // Update published list

        // Scan for new ones that might have appeared
        scanForExistingInstances() // This also calls updatePublishedMonitoredApps

        if let owner = self.owner, monitoredApps.isEmpty, owner.isMonitoringActivePublic {
            logger.info("No more Cursor instances after refresh. Signaling owner to stop monitoring loop.")
            owner.stopMonitoringLoop()
        }
    }

    // Helper to update the @Published monitoredApps array from runningAppInfo dictionary
    private func updatePublishedMonitoredApps() {
        monitoredApps = Array(runningAppInfo.values)
    }
} 
