import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import Diagnostics
@preconcurrency import Foundation
import KeyboardShortcuts
import os
@preconcurrency import OSLog
@preconcurrency import ServiceManagement
import SwiftUI

@objc(AppDelegate)
@objcMembers
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate,
    @unchecked Sendable,
    ObservableObject
{
    // MARK: Lifecycle

    // Called when app is initialized with SwiftUI lifecycle
    // This is an additional initializer to support SwiftUI app structure
    override public init() {
        super.init()
        // Note: self.logger might not be available here yet if it's a let constant initialized later.
        // For safety, critical init logging can use os_log directly or defer to applicationDidFinishLaunching.
        os_log("AppDelegate initialized via SwiftUI lifecycle", log: OSLog.default, type: .info)
    }

    // MARK: - Cleanup

    deinit {
        MainActor.assumeIsolated {
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()

            self.logger.info("AppDelegate deinit - notification resources cleaned up")
        }

        self.logger.info("AppDelegate deinit - resources cleaned up")
    }

    // MARK: Public

    /// Shared singleton instance for global access
    public static var shared: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
        logger.info("Application finished launching.")
        sessionLogger.log(level: .info, message: "Application finished launching.")

        // Single instance check
        singleInstanceLock = SingleInstanceLock(identifier: "me.steipete.codelooper.instance")

        // Wait for the async check to complete
        Task {
            // Give the SingleInstanceLock time to check
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

            if !singleInstanceLock!.isPrimaryInstance {
                logger.warning("Another instance of CodeLooper is already running. Terminating this instance.")
                // Bring the other instance to the front
                singleInstanceLock!.activateExistingInstance()
                NSApp.terminate(nil)
            }
        }

        // Initialize core services FIRST
        initializeServices() // Ensure windowManager and other services are ready

        // Sync login item state with user preference after services are up
        loginItemManager?.syncLoginItemWithPreference()
        
        // Setup dock visibility based on user preference
        setupDockVisibility()

        // Setup main application components
        setupNotificationObservers()
        // setupSupervision() // Commenting out for now - CursorMonitor.shared might handle its own start via Defaults
        // observation

        // Restore window state or show welcome guide
        handleWindowRestorationAndFirstLaunch()

        // Ensure shared instance is set up for other parts of the app that might need it early.
        // However, direct access should be minimized in favor of dependency injection or notifications.
        // Self.shared = self // This is incorrect; shared is a get-only computed property.

        #if DEBUG
            startCursorAXObservation()

            // Automatically open settings for faster debugging in DEBUG builds
            Task { @MainActor in
                // Ensure windowManager is available and settings can be opened.
                // This assumes windowManager is initialized and ready.
                // If settings are part of a scene that's always available, that's easier.
                // For now, directly call a method on windowManager if available.
                // Need to ensure windowManager is properly initialized before this timer fires.
                // A more robust way for scenes: NSApp.openSettings()
                // but if your settings is custom window, use windowManager.
                // Let's assume showSettingsWindow() exists on AppDelegate or WindowManager.
                // If using standard SwiftUI Settings scene:
                // NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                // Or for custom window via windowManager:
                // self.windowManager?.openSettings() // Incorrect method name
                // NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                SettingsService.openSettingsSubject.send()
                self.logger.info("DEBUG: Requested settings open via SettingsService.")
            }
        #endif
    }

    public func applicationWillTerminate(_: Notification) {
        logger.info("Application is terminating")

        // Stop the Cursor monitoring loop
        CursorMonitor.shared.stopMonitoringLoop()

        // Remove all notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        logger.info("Application termination cleanup completed")
    }

    // MARK: Internal

    // MARK: - Logger

    // Use custom Logger for categorized logging
    let logger = Logger(category: .appDelegate)
    // Services - initialized directly in AppDelegate
    var loginItemManager: LoginItemManager?
    var axApplicationObserver: AXApplicationObserver?
    var sparkleUpdaterManager: SparkleUpdaterManager?
    var updaterViewModel: UpdaterViewModel?
    var windowManager: WindowManager?
    // Core services
    let sessionLogger = SessionLogger.shared
    var axObservationStarted: Bool = false // Tracks if AX observe has been started

    func refreshUI() {
        logger.info("Refreshing UI components")
        loginItemManager?.syncLoginItemWithPreference()
    }

    // MARK: - Window Management

    func showAXpectorWindow() { // New method
        logger.info("AppDelegate: Request to show AXpector window.")
        if windowManager == nil {
            logger.error("WindowManager is nil in AppDelegate when trying to show AXpector window!")
            return
        }
        windowManager?.showAXpectorWindow()
    }

    // MARK: - Update Handling (Sparkle)

    @IBAction func checkForUpdates(_ sender: Any?) {
        sparkleUpdaterManager?.updaterController.checkForUpdates(sender)
    }

    func toggleDebugOverlay() {
        logger.info("Debug Overlay Toggled (Placeholder - No UI Change)")
    }

    // MARK: Private

    private var singleInstanceLock: SingleInstanceLock? // For single instance check

    private var axorcist: AXorcist?

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    private lazy var locatorManager = LocatorManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Settings Setup

    private func setupSettingsCoordinator() {
        logger.info("Setting up settings coordinator")

        // Initialize the main settings coordinator
        guard let loginItemManager, let updaterViewModel else {
            logger
                .error(
                    "Failed to initialize settings coordinator - missing required services (loginItemManager or updaterViewModel)"
                )
            return
        }

        mainSettingsCoordinator = MainSettingsCoordinator(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        logger.info("Settings functionality is ready")
    }

    // MARK: - Exception Handling

    private func setupExceptionHandling() {
        logger.info("Setting up exception handling")
        // Configure global exception handler
        NSSetUncaughtExceptionHandler { exception in
            let exceptionLogger = os.Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "me.steipete.codelooper",
                category: "ExceptionHandler"
            )
            exceptionLogger
                .critical("Uncaught exception: \(exception.name.rawValue), reason: \(exception.reason ?? "unknown")")

            // Get stack trace
            let callStack = exception.callStackSymbols
            exceptionLogger.critical("Stack trace: \(callStack.joined(separator: "\n"))")
        }
    }

    // MARK: - Service Initialization

    @MainActor
    private func initializeServices() {
        logger.info("Initializing essential services...")

        axorcist = AXorcist()
        if axorcist == nil {
            logger.error("Failed to initialize AXorcist instance.")
        }

        axApplicationObserver = AXApplicationObserver(axorcist: self.axorcist)

        loginItemManager = LoginItemManager.shared

        _ = self.locatorManager
        logger.info("LocatorManager accessed.")

        // Disabled until this is setup.
        // sparkleUpdaterManager = SparkleUpdaterManager()
        logger.info("SparkleUpdaterManager initialized.")

        if let sparkleManager = self.sparkleUpdaterManager {
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: sparkleManager)
            logger.info("UpdaterViewModel initialized.")
        } else {
            logger.error("SparkleUpdaterManager was nil, cannot initialize UpdaterViewModel.")
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: nil)
        }

        logger.info("CursorMonitor shared instance already initialized.")

        setupSettingsCoordinator()
        logger.info("MainSettingsCoordinator initialized.")

        if let loginMgr = self.loginItemManager {
            windowManager = WindowManager(loginItemManager: loginMgr, sessionLogger: self.sessionLogger, delegate: self)
            logger.info("WindowManager initialized with sessionLogger and delegate.")
        } else {
            logger.error("LoginItemManager was nil, cannot initialize WindowManager.")
        }

        logger.info("Essential services initialization complete.")
    }

    // MARK: - Helper Methods

    private func syncLoginItemStatus() {
        logger.info("Syncing login item status")
        guard let loginItemManager else {
            logger.error("Cannot sync login item status: loginItemManager is nil")
            return
        }
        loginItemManager.syncLoginItemWithPreference()
    }
    
    private func setupDockVisibility() {
        logger.info("Setting up dock visibility")
        updateDockVisibility()
        
        // Observe changes to the showInDock preference
        Defaults.observe(.showInDock) { [weak self] change in
            self?.logger.info("Dock visibility preference changed to: \(change.newValue)")
            self?.updateDockVisibility()
        }
        .tieToLifetime(of: self)
    }
    
    private func updateDockVisibility() {
        let shouldShowInDock = Defaults[.showInDock]
        logger.info("Updating dock visibility to: \(shouldShowInDock)")
        
        if shouldShowInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        logger.info("Setting up notification observers")

        let highlightMenuBarObserver = setupHighlightMenuBarObserver()

        notificationObservers.append(highlightMenuBarObserver)

        // Observer for showing AXpector Window
        let axpectorObserver = NotificationCenter.default.addObserver(
            forName: .showAXpectorWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Ensure execution on the main actor
            Task { @MainActor [weak self] in // Explicitly dispatch to MainActor
                self?.logger.info("Received notification to show AXpector window.")
                self?.showAXpectorWindow()
            }
        }
        notificationObservers.append(axpectorObserver)

        logger.info("Application startup completed successfully")
    }

    private func setupHighlightMenuBarObserver() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .highlightMenuBarIcon,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("Highlighting menu bar icon based on notification (.highlightMenuBarIcon received)")
                AppIconStateController.shared.flashIcon()
            }
        }
    }

    // MARK: - Monitoring State Management

    // New method to toggle monitoring state
    @objc private func toggleMonitoringState() {
        Defaults[.isGlobalMonitoringEnabled].toggle()
        let state = Defaults[.isGlobalMonitoringEnabled] ? "enabled" : "disabled"
        logger.info("Global monitoring toggled via shortcut: \(state)")
    }

    private func refreshUIStateAfterOnboarding() {
        logger.info("Onboarding complete. Refreshing UI state.")
    }

    // MARK: - Window Restoration

    private func handleWindowRestorationAndFirstLaunch() {
        // ... existing code ...
    }

    private func startCursorAXObservation() {
        guard !axObservationStarted else { return }
        guard let axorcist else {
            logger.error("AXorcist instance unavailable – cannot start AX observation.")
            return
        }
        let cursorBundleId = "com.todesktop.230313mzl4w4u92"
        let notifications = ["AXFocusedUIElementChanged", "AXValueChanged"]
        let includeDetails = [
            "AXRole", "AXRoleDescription", "AXValue", "AXPlaceholderValue", "AXIdentifier", "AXDescription", "AXHelp",
            "AXParent", "AXChildren",
        ]

        // Create ObserveCommand instance
        let observeCommand = ObserveCommand(
            appIdentifier: cursorBundleId,
            locator: nil,
            notifications: notifications,
            includeDetails: !includeDetails.isEmpty,
            watchChildren: true,
            notificationName: AXNotification.focusedUIElementChanged,
            includeElementDetails: includeDetails,
            maxDepthForSearch: 0
        )

        // Call handleObserve with the command (not async)
        let response = axorcist.handleObserve(command: observeCommand)

        // Handle the response
        switch response {
        case .success:
            self.logger
                .info("Started AX observation for Cursor via AXorcist (AppDelegate). JSON will stream to stdout.")
            self.axObservationStarted = true
        case let .error(message, code, _):
            self.logger
                .error("Failed to start AX observation for Cursor via AXorcist. Error: \(message), Code: \(code)")
        }
    }
}

// MARK: - WindowManagerDelegate

@MainActor
extension AppDelegate: WindowManagerDelegate {
    func windowManagerDidFinishOnboarding() {
        logger.info("WindowManagerDelegate: Onboarding finished. Performing any post-onboarding tasks.")
    }

    // Removed windowManagerRequestsAccessibilityPermissions as WindowManager handles it directly now
}
