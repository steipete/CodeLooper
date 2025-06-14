import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import DesignSystem
import Diagnostics
@preconcurrency import Foundation
import KeyboardShortcuts
import os
@preconcurrency import OSLog
@preconcurrency import ServiceManagement
import SwiftUI

/// Main application delegate that manages the lifecycle and core functionality of CodeLooper.
///
/// This class serves as the central hub for:
/// - Application lifecycle events (launch, termination, wake from sleep)
/// - Menu bar management and user interaction
/// - Cursor monitoring coordination
/// - Settings and preferences management
/// - Accessibility permissions handling
/// - System notifications and AppleScript support
///
/// The AppDelegate coordinates between various subsystems including the monitoring service,
/// intervention engine, and UI components to provide seamless Cursor IDE supervision.
@objc(AppDelegate)
@objcMembers
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
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
        // Notification observers will be cleaned up automatically when the object is deallocated.
        // We cannot safely access @MainActor-isolated properties from deinit.
    }

    // MARK: Public

    /// Shared singleton instance for global access
    public static var shared: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
    
    // Status bar controller - initialized later
    private var statusBarController: StatusBarController?

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
        logger.info("Application finished launching.")
        sessionLogger.log(level: .info, message: "Application finished launching.")

        // Single instance check - skip for Xcode previews and tests
        let isXcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        // Single instance check - skip for Xcode previews, tests, and DEBUG builds
        #if !DEBUG
            if !isXcodePreview, !Constants.isTestEnvironment {
                singleInstanceLock = SingleInstanceLock(identifier: "me.steipete.codelooper.instance")

                // Check single instance asynchronously
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    // Give the SingleInstanceLock time to check (reduced from 0.6 to 0.2 seconds)
                    try? await Task.sleep(for: .milliseconds(200))

                    guard let singleInstanceLock = self.singleInstanceLock else { return }

                    if !singleInstanceLock.isPrimaryInstance {
                        self.logger
                            .warning("Another instance of CodeLooper is already running. Terminating this instance.")
                        // Bring the other instance to the front and show settings
                        singleInstanceLock.activateExistingInstance()
                        NSApp.terminate(nil)
                    }
                }
            } else {
                logger.info("Running in Xcode preview mode or test environment - skipping single instance check")
            }
        #else
            logger.info("DEBUG build: Single instance check is disabled")
        #endif

        // Initialize core services FIRST
        initializeServices() // Ensure windowManager and other services are ready
        
        // Initialize status bar controller after services are ready
        statusBarController = StatusBarController.shared

        // Sync login item state with user preference after services are up
        if !Constants.isTestEnvironment {
            loginItemManager?.syncLoginItemWithPreference()
        }

        // Setup dock visibility based on user preference
        setupDockVisibility()

        // Apply global CodeLooper brand tint
        setupGlobalTint()

        // Setup main application components
        setupNotificationObservers()
        setupSupervision()

        // Restore window state or show welcome guide
        handleWindowRestorationAndFirstLaunch()

        // Ensure shared instance is set up for other parts of the app that might need it early.
        // However, direct access should be minimized in favor of dependency injection or notifications.
        // Self.shared = self // This is incorrect; shared is a get-only computed property.

        #if DEBUG
            if !Constants.isTestEnvironment {
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
            }
        #endif
    }

    public func applicationWillTerminate(_: Notification) {
        logger.info("Application is terminating")

        // Stop all supervision activities
        supervisionCoordinator?.stopSupervision()

        // Remove all notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        logger.info("Application termination cleanup completed")
    }

    // MARK: - Dock Icon Handling

    public func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.info("Dock icon clicked, hasVisibleWindows: \(flag)")

        // Always open/focus the settings window when dock icon is clicked
        Task { @MainActor in
            SettingsService.openSettingsSubject.send()
            logger.info("Requested settings window open/focus via dock icon click")
        }

        return true
    }

    // MARK: Internal

    // MARK: - Logger

    // Services - initialized directly in AppDelegate
    var loginItemManager: LoginItemManager?
    var axApplicationObserver: AXApplicationObserver?
    var sparkleUpdaterManager: SparkleUpdaterManager?
    var updaterViewModel: UpdaterViewModel?
    var windowManager: WindowManager?
    var supervisionCoordinator: AppSupervisionCoordinator?
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

    // MARK: - Menu Actions

    @IBAction func showAboutPanel(_: Any?) {
        logger.info("About menu item selected, showing custom About window")
        windowManager?.showAboutWindow()
    }

    @IBAction func orderFrontStandardAboutPanel(_: Any?) {
        logger.info("Standard About panel requested, redirecting to custom About window")
        windowManager?.showAboutWindow()
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
                    "Failed to initialize settings coordinator - missing required services"
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
        // Note: MenuBarIconManager removed - now using SwiftUI MenuBarExtra in CodeLooperApp.swift

        // Initialize Sparkle with error handling to prevent dialogs
        sparkleUpdaterManager = SparkleUpdaterManager()
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

        // Initialize the supervision coordinator
        supervisionCoordinator = AppSupervisionCoordinator()
        logger.info("AppSupervisionCoordinator initialized.")

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

        // Observer for showing settings when another instance is launched
        if !Constants.isTestEnvironment {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(handleShowSettingsNotification),
                name: NSNotification.Name("me.steipete.codelooper.showSettings"),
                object: nil
            )
        }

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

        // Initialize WelcomeWindowCoordinator to ensure it's listening for notifications
        _ = WelcomeWindowCoordinator.shared


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

    @objc private func handleShowSettingsNotification() {
        Task { @MainActor in
            logger.info("Received request to show settings from another instance")
            MainSettingsCoordinator.shared.showSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Supervision Setup

    private func setupSupervision() {
        logger.info("Setting up supervision")

        // Setup supervision using the coordinator
        supervisionCoordinator?.setupSupervision()

        // Start supervision if enabled - this is the key fix!
        supervisionCoordinator?.startSupervisionIfEnabled()
        
        // Initialize HTTP server
        Task { @MainActor in
            await HTTPServerService.shared.startIfEnabled()
        }
        
        // Observe changes to the global monitoring setting
        Defaults.observe(.isGlobalMonitoringEnabled) { [weak self] change in
            self?.logger.info("Global monitoring preference changed to: \(change.newValue)")

            Task { @MainActor in
                if change.newValue {
                    // Start supervision when enabled
                    self?.supervisionCoordinator?.startSupervisionIfEnabled()
                } else {
                    // Stop supervision when disabled
                    self?.supervisionCoordinator?.stopSupervision()
                }
            }
        }
        .tieToLifetime(of: self)
    }

    // MARK: - Monitoring State Management

    // New method to toggle monitoring state
    @objc private func toggleMonitoringState() {
        supervisionCoordinator?.toggleMonitoringState()
    }

    private func refreshUIStateAfterOnboarding() {
        logger.info("Onboarding complete. Refreshing UI state.")
    }

    // MARK: - Window Restoration

    private func handleWindowRestorationAndFirstLaunch() {
        logger.info("Handling window restoration and first launch")
        // Window restoration logic will be implemented here as needed
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


    // MARK: - Global Tint Setup

    private func setupGlobalTint() {
        logger.info("Applying CodeLooper brand tint globally")

        // The global tint is now applied via SwiftUI's .withDesignSystem() modifier
        // This ensures consistent brand tinting across the entire app

        logger.info("Global CodeLooper tint configured successfully")
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
