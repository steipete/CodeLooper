import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
import os
import SwiftUI

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
/// - ``startMonitoringLoop()``
/// - ``stopMonitoringLoop()``
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
/// monitor.startMonitoringLoop()
///
/// // Monitor will automatically detect and handle Cursor issues
/// ```
@MainActor
public class CursorMonitor: ObservableObject, Loggable {
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
        Task { @MainActor [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.cancellables.forEach { $0.cancel() }
            strongSelf.cancellables.removeAll()
            strongSelf.stopMonitoringLoop()
        }
    }

    // MARK: Public

    /// Shared singleton instance
    public static let shared = CursorMonitor(
        axorcist: AXorcist(),
        sessionLogger: SessionLogger.shared,
        locatorManager: LocatorManager.shared,
        instanceStateManager: CursorInstanceStateManager(sessionLogger: SessionLogger.shared)
    )

    #if DEBUG
        public static var sharedForPreview: CursorMonitor = {
            let previewMonitor = CursorMonitor(
                axorcist: AXorcist(),
                sessionLogger: SessionLogger.shared,
                locatorManager: LocatorManager.shared,
                instanceStateManager: CursorInstanceStateManager(sessionLogger: SessionLogger.shared)
            )
            // Configure previewMonitor with some mock data
            let appPID = pid_t(12345)
            let mockApp = MonitoredAppInfo(
                id: appPID,
                pid: appPID,
                displayName: "Cursor (Preview)",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 2,
                windows: [
                    MonitoredWindowInfo(id: "w1", windowTitle: "Document Preview.txt", axElement: nil, isPaused: false),
                    MonitoredWindowInfo(id: "w2", windowTitle: "Settings Preview", axElement: nil, isPaused: true),
                ]
            )
            previewMonitor.monitoredApps = [mockApp]
            previewMonitor.totalAutomaticInterventionsThisSessionDisplay = 5
            return previewMonitor
        }()
    #endif

    // MARK: - Published Properties

    public let axorcist: AXorcist
    @Published public var instanceInfo: [pid_t: CursorInstanceInfo] = [:]
    @Published public var monitoredApps: [MonitoredAppInfo] = []

    /// Total number of automatic interventions this session for display purposes
    @Published public var totalAutomaticInterventionsThisSessionDisplay: Int = 0

    // MARK: - Components

    public var appLifecycleManager: CursorAppLifecycleManager!

    public var isMonitoringActivePublic: Bool { isMonitoringActive }

    // MARK: Internal

    var isMonitoringActive: Bool = false

    var monitoringTask: Task<Void, Error>?
    let sessionLogger: SessionLogger
    let locatorManager: LocatorManager
    let instanceStateManager: CursorInstanceStateManager
    var monitoringCycleCount: Int = 0
    var cancellables = Set<AnyCancellable>()

    lazy var ruleExecutor = RuleExecutor()

    // MARK: Private

    private var axApplicationObserver: AXApplicationObserver!

    private var interventionEngine: CursorInterventionEngine!
    private var tickUseCases: [pid_t: ProcessMonitoringTickUseCase] = [:]

    // MARK: - Subscription Setup

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
}
