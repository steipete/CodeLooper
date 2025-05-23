import AppKit
import Combine
import OSLog
import Defaults // Assuming CursorInstanceInfo might use it, or for future use
import Foundation

// Forward declare CursorMonitor if needed for the owner reference, or ensure it's imported if in a different module (not the case here)
// class CursorMonitor {} // Placeholder if full import isn't desired yet, but direct reference is better.

@MainActor
public class CursorAppLifecycleManager: ObservableObject {
    private let logger = Logger(label: String(describing: CursorAppLifecycleManager.self), category: .lifecycle)
    
    // Constants
    private let cursorBundleIdentifier = "com.todesktop.230313mzl4w4u92"

    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    @Published public var monitoredInstances: [MonitoredInstanceInfo] = []
    
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
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier } // self.cursorBundleIdentifier is correct here
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                // self? refers to CursorAppLifecycleManager instance
                self?.handleCursorLaunch(app) 
            }
            .store(in: &cancellables) // self.cancellables is correct here

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .filter { $0.bundleIdentifier == self.cursorBundleIdentifier } // self.cursorBundleIdentifier is correct here
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                // self? refers to CursorAppLifecycleManager instance
                self?.handleCursorTermination(app)
            }
            .store(in: &cancellables) // self.cancellables is correct here
        logger.info("Workspace notification observers set up for Cursor.") // self.logger is correct here
    }

    func scanForExistingInstances() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.bundleIdentifier == cursorBundleIdentifier, !app.isTerminated {
                logger.info("Found existing Cursor instance (PID: \\(app.processIdentifier)) on scan.")
                handleCursorLaunch(app) // self.handleCursorLaunch implicitly
            }
        }
        if instanceInfo.isEmpty { // self.instanceInfo implicitly
            logger.info("No running Cursor instances found on initial scan.")
        }
    }

    func handleCursorLaunch(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard instanceInfo[pid] == nil else {
            logger.info("Instance PID \\(pid) already being monitored.")
            return
        }
        let newInfo = CursorInstanceInfo(app: app, status: .unknown, statusMessage: "Initializing...")
        instanceInfo[pid] = newInfo
        
        let monitoredInfo = MonitoredInstanceInfo(
            id: pid,
            pid: pid,
            displayName: "Cursor (PID: \\(pid))",
            status: .active, // Defaulting to active, owner might update based on deeper checks
            isActivelyMonitored: true, // Assuming newly launched are monitored
            interventionCount: 0 // Will be managed by owner or another component
        )
        monitoredInstances.append(monitoredInfo)
        
        // Initialization of per-PID states (e.g., automaticInterventionsSincePositiveActivity)
        // will be handled by the future CursorInstanceStateManager, signaled by the owner (CursorMonitor)
        // after a launch is processed by CursorAppLifecycleManager.
        owner?.didLaunchInstance(pid: pid) // Notify owner to set up detailed state

        logger.info("Cursor instance launched (PID: \\(pid)). Manager processed launch.")
        Task {
            await sessionLogger.log(level: .info, message: "Cursor instance launched (PID: \\(pid)). Manager processed launch.", pid: pid)
        }
        
        // Inform owner; owner decides if loop should start/is already running
        if let owner = self.owner, !owner.isMonitoringActivePublic {
             owner.startMonitoringLoop() // Call on owner
        }
    }

    func handleCursorTermination(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard instanceInfo.removeValue(forKey: pid) != nil else {
            logger.info("Received termination for unmonitored PID \\(pid).")
            return
        }
        
        monitoredInstances.removeAll { $0.pid == pid }
        
        // Notify owner to clean up detailed state for this PID
        owner?.didTerminateInstance(pid: pid)

        logger.info("Cursor instance terminated (PID: \\(pid)). Manager processed termination.")
        Task {
            await sessionLogger.log(level: .info, message: "Cursor instance terminated (PID: \\(pid)). Manager processed termination.", pid: pid)
        }
        
        // Inform owner; owner decides if loop should stop
        if let owner = self.owner, monitoredInstances.isEmpty, owner.isMonitoringActivePublic {
            logger.info("No more Cursor instances. Signaling owner to stop monitoring loop.")
            owner.stopMonitoringLoop() // Call on owner
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
                 
                 monitoredInstances.removeAll { $0.pid == pid }
                 
                 // Notify owner to clean up detailed state for this PID
                 owner?.didTerminateInstance(pid: pid)
            }
        }
        // After removing defunct instances, scan for any new ones that might have appeared
        // without a formal launch notification (e.g., if observers were temporarily down).
        scanForExistingInstances() // Calls the local method

        if let owner = self.owner, monitoredInstances.isEmpty, owner.isMonitoringActivePublic {
            logger.info("No more Cursor instances after refresh. Signaling owner to stop monitoring loop.")
            owner.stopMonitoringLoop() // Call on owner
        }
    }
} 