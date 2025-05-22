import AppKit
import AXorcistLib
import Combine
import Defaults
// import HIServices // Removed as ApplicationServices should cover it
import ApplicationServices // Ensure ApplicationServices is imported
@preconcurrency import Foundation
import os // Import os for os.Logger
@preconcurrency import OSLog
@preconcurrency import ServiceManagement
// import Sparkle // Sparkle import is now managed by SparkleUpdaterManager
import SwiftUI
import KeyboardShortcuts // Added import

// Ensure line 14, 15, 16 related to AppAXTrustedCheckOptionPromptKey_Raw_CFRef are DELETED
// Ensure lines 60-66 related to static appAXTrustedCheckOptionPromptKeyString are DELETED

@objc(AppDelegate)
@objcMembers
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate,
    @unchecked Sendable,
    ObservableObject {

    /*
    // Use a nonisolated(unsafe) static computed property to access the C global.
    // This tells Swift that we are manually asserting the safety of this access,
    // which is acceptable here as kAXTrustedCheckOptionPrompt is an immutable C constant.
    private nonisolated(unsafe) static var axTrustedCheckOptionPromptKeyString: String {
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    }
    */

    /// Shared singleton instance for global access
    public static var shared: AppDelegate {
        guard let delegate = NSApp.delegate as? AppDelegate else {
            fatalError("AppDelegate not found as NSApp.delegate")
        }
        return delegate
    }

    // MARK: - Logger

    // Use os.Logger for categorized logging
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper", category: LogCategory.app.rawValue)

    // MARK: - Properties

    // Services - initialized directly in AppDelegate
    var menuManager: MenuManager?
    var loginItemManager: LoginItemManager?
    var axApplicationObserver: AXApplicationObserver? // Observer for app launch/terminate
    var popover: NSPopover?
    var sparkleUpdaterManager: SparkleUpdaterManager? // Added
    private var axorcist: AXorcistLib.AXorcist? // Added for AXApplicationObserver
    var updaterViewModel: UpdaterViewModel? // Added
    var windowManager: WindowManager? // Added

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?
    // public var welcomeWindowController: NSWindowController? // Moved to WindowManager

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    // Core services
    let sessionLogger = SessionLogger.shared
    private lazy var locatorManager = LocatorManager.shared
    private var cancellables = Set<AnyCancellable>()
    // private var welcomeWindow: NSWindow? // Moved to WindowManager
    private var settingsWindow: NSWindow?
    // private var updaterController: SPUStandardUpdaterController? // Removed, now in SparkleUpdaterManager

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
        logger.info("Application starting up - logs are now stored in Application Support/CodeLooper/Logs")

        // Set up exception handling
        setupExceptionHandling()

        // Initialize core services (axorcist, cursorMonitor will be initialized here)
        logger.info("Initializing core services")
        initializeServices() // This will now initialize sparkleUpdaterManager

        // Initialize Sparkle updater - MOVED to initializeServices, handled by SparkleUpdaterManager
        // logger.info("Initializing Sparkle updater")
        // updaterController = SPUStandardUpdaterController(
        // startingUpdater: true,
        // updaterDelegate: nil,
        // userDriverDelegate: nil
        // )

        // Setup AppIconStateController AFTER cursorMonitor is initialized
        AppIconStateController.shared.setup(cursorMonitor: CursorMonitor.shared)

        // Start the Cursor monitoring loop IF globally enabled (moved after cursorMonitor init)
        if Defaults[.isGlobalMonitoringEnabled] {
            logger.info("Global monitoring is enabled. Starting CursorMonitor loop.")
            CursorMonitor.shared.startMonitoringLoop()
        } else {
            logger.info(
                "Global monitoring is disabled. CursorMonitor loop not started initially."
            )
        }

        // Sync login item preference with system status
        syncLoginItemStatus()

        // Initialize the menu bar and UI
        logger.info("Setting up menu bar")
        setupMenuBar() // menuManager should be initialized here

        // Update initial status bar icon AFTER menuManager is set up
        if let statusButton = menuManager?.statusItem?.button {
            statusButton.image = NSImage(named: "MenuBarTemplateIcon")
            statusButton.image?.isTemplate = true
            statusButton.contentTintColor = AppIconStateController.shared.currentTintColor
        } else {
            logger.warning("menuManager.statusItem.button is nil, cannot set initial icon image.")
        }
        
        // Setup all notification observers
        setupNotificationObservers()

        // Handle first launch or welcome screen logic
        // handleFirstLaunchOrWelcomeScreen() // Moved to WindowManager initialization
        windowManager?.handleFirstLaunchOrWelcomeScreen()
        
        
        // Observe AppIconStateController tint color changes
        AppIconStateController.shared.$currentTintColor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTintColor in
                self?.menuManager?.statusItem?.button?.contentTintColor = newTintColor
                self?.logger.info("Menu bar icon tint color updated.")
            }
            .store(in: &cancellables)

        // Observe global monitoring toggle (moved here)
        Defaults.publisher(.isGlobalMonitoringEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self = self else { return }
                if change.newValue {
                    self.logger.info("Global monitoring toggled ON. Starting CursorMonitor loop.")
                    CursorMonitor.shared.startMonitoringLoop()
                } else {
                    self.logger.info("Global monitoring toggled OFF. Stopping CursorMonitor loop.")
                    CursorMonitor.shared.stopMonitoringLoop()
                }
            }
            .store(in: &cancellables)

        // Setup initial menu bar visibility

        // Setup KeyboardShortcuts listener for toggling monitoring
        KeyboardShortcuts.onKeyUp(for: .toggleMonitoring) { [weak self] in
            self?.toggleMonitoringState()
        }

        logger.info("Application startup completed successfully")
    }

    // Called when app is initialized with SwiftUI lifecycle
    // This is an additional initializer to support SwiftUI app structure
    override public init() {
        super.init()
        // Note: self.logger might not be available here yet if it's a let constant initialized later.
        // For safety, critical init logging can use os_log directly or defer to applicationDidFinishLaunching.
        os_log("AppDelegate initialized via SwiftUI lifecycle", log: OSLog.default, type: .info)
    }

    // MARK: - Settings Setup

    private func setupSettingsCoordinator() {
        logger.info("Setting up settings coordinator")

        // Initialize the main settings coordinator
        guard let loginItemManager, let updaterViewModel else {
            logger.error("Failed to initialize settings coordinator - missing required services (loginItemManager or updaterViewModel)")
            return
        }

        mainSettingsCoordinator = MainSettingsCoordinator(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        logger.info("Settings functionality is ready")
    }

    public func applicationWillTerminate(_: Notification) {
        logger.info("Application is terminating")

        // Stop the Cursor monitoring loop
        CursorMonitor.shared.stopMonitoringLoop()


        // Clean up menu manager
        menuManager?.cleanup()

        // Remove all notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        logger.info("Application termination cleanup completed")
    }

    func refreshUI() {
        logger.info("Refreshing UI components")
        // Ensure login item status is in sync
        loginItemManager?.syncLoginItemWithPreference()
        menuManager?.refreshMenu()
    }

    /// Updates the visibility of the menu bar icon
    /// - Parameter isVisible: Whether the menu bar icon should be visible
    func updateMenuBarVisibility(_ isVisible: Bool) {
        logger.info("Updating menu bar visibility: \(isVisible)")

        // If the status item should be hidden and it exists, remove it
        if !isVisible {
            if menuManager?.statusItem != nil {
                logger.info("Removing status item from menu bar")
                // Remove the status item from the system status bar
                if let statusItem = menuManager?.statusItem {
                    NSStatusBar.system.removeStatusItem(statusItem)
                    menuManager?.statusItem = nil
                }
            }
        } else if menuManager?.statusItem == nil {
            // If status item should be visible but doesn't exist, create it
            logger.info("Restoring status item to menu bar")
            menuManager?.setupMenuBar()
        } else {
            // If the status item exists and should be visible, ensure it's properly set up
            logger.info("Status item already exists and should be visible, refreshing menu")
            menuManager?.refreshMenu()
        }

        // Store the preference
        Defaults[.showInMenuBar] = isVisible

        // Log the change for debugging purposes
        let statusItemExists = menuManager?.statusItem != nil
        logger.info("Menu bar visibility updated: isVisible=\(isVisible), statusItem=\(String(describing: statusItemExists))")
    }

    // MARK: - Window Management

    // private var aboutWindowController: NSWindowController? // Moved to WindowManager

    // @objc func showAboutWindow() { ... } // Moved to WindowManager

    // MARK: - App Initialization Methods

    private func setupExceptionHandling() {
        logger.info("Setting up exception handling")
        // Configure global exception handler
        NSSetUncaughtExceptionHandler { exception in
            let exceptionLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper", category: "ExceptionHandler")
            exceptionLogger.critical("Uncaught exception: \(exception.name.rawValue), reason: \(exception.reason ?? "unknown")")

            // Get stack trace
            let callStack = exception.callStackSymbols
            exceptionLogger.critical("Stack trace: \(callStack.joined(separator: "\n"))")
        }
    }

    @MainActor
    private func initializeServices() {
        logger.info("Initializing essential services...")

        // Initialize AXorcist
        axorcist = AXorcistLib.AXorcist()
        if axorcist == nil {
            logger.error("Failed to initialize AXorcist instance.")
            // Depending on how critical AXorcist is, might need to handle this more gracefully
        }

        // Initialize AXApplicationObserver for app launch/terminate events
        axApplicationObserver = AXApplicationObserver(axorcist: self.axorcist)
        // axApplicationObserver?.delegate = self // Ensure AppDelegate conforms to AXApplicationObserverDelegate - REMOVED

        // Initialize Login Item Manager
        loginItemManager = LoginItemManager.shared

        // Initialize Locator Manager (already a lazy var, but ensure it's accessed if needed early)
        _ = self.locatorManager
        logger.info("LocatorManager accessed.")
        
        // Initialize SparkleUpdaterManager (New)
        sparkleUpdaterManager = SparkleUpdaterManager()
        logger.info("SparkleUpdaterManager initialized.")

        // Initialize UpdaterViewModel (New)
        if let sparkleManager = self.sparkleUpdaterManager {
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: sparkleManager)
            logger.info("UpdaterViewModel initialized.")
        } else {
            logger.error("SparkleUpdaterManager was nil, cannot initialize UpdaterViewModel.")
            // Initialize with nil if SparkleUpdaterManager couldn't be created for some reason
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: nil)
        }

        // Initialize CursorMonitor (depends on axorcist, sessionLogger, locatorManager)
        // Ensure AXorcistLib.AXorcist() is initialized and passed if needed, or CursorMonitor handles it.
        // CursorMonitor.shared is already initialized with its dependencies by its static initializer.
        logger.info("CursorMonitor shared instance already initialized.")

        // Initialize other services that might depend on the above
        // For example, if MenuManager depends on CursorMonitor or other services, initialize it here or ensure dependencies are met.
        // MenuManager initialization is currently in setupMenuBar, which is called later.

        // Setup settings coordinator (depends on loginItemManager)
        setupSettingsCoordinator()
        logger.info("MainSettingsCoordinator initialized.")

        // Initialize WindowManager (New)
        if let loginMgr = self.loginItemManager {
            windowManager = WindowManager(loginItemManager: loginMgr, sessionLogger: self.sessionLogger, delegate: self)
            logger.info("WindowManager initialized.")
        } else {
            logger.error("LoginItemManager was nil, cannot initialize WindowManager.")
            // Handle error or provide a fallback if necessary for WindowManager
        }

        logger.info("Essential services initialization complete.")
    }

    private func syncLoginItemStatus() {
        logger.info("Syncing login item status")
        guard let loginItemManager else {
            logger.error("Cannot sync login item status: loginItemManager is nil")
            return
        }
        loginItemManager.syncLoginItemWithPreference()
    }

    private func setupMenuBar() {
        logger.info("Setting up menu bar")

        // Initialize MenuManager if it's not already (e.g., if restored)
        if menuManager == nil {
            menuManager = MenuManager(delegate: self)
        }

        // Ensure statusItem is created via MenuManager's init
        // menuManager?.setupStatusItem() // This was correctly commented out, init handles it.

        if let statusButton = menuManager?.statusItem?.button {
            statusButton.action = #selector(togglePopover(_:))
            statusButton.target = self // Ensure target is self for the action
            logger.info("Status bar item action set to togglePopover")
        } else {
            logger.error("Status bar item button not found after setup. Cannot set action.")
        }
        
        // Setup Popover
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 380, height: 450) // As per MainPopoverView frame
            popover?.behavior = .transient
            popover?.animates = true
            // Use a hosting controller for the SwiftUI view
            popover?.contentViewController = NSHostingController(rootView: MainPopoverView())
            logger.info("Popover initialized with MainPopoverView")
        } else {
            logger.info("Popover already exists")
        }

        menuManager?.refreshMenu() // Refresh menu items if needed after setup
        logger.info("Menu bar setup complete")
    }

    func togglePopover(_ sender: AnyObject?) {
        guard let popover = self.popover else {
            logger.error("Toggle Popover: Popover is nil")
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            logger.debug("Popover closed")
        } else {
            guard let button = menuManager?.statusItem?.button else {
                logger.error("Toggle Popover: Status item button is nil, cannot show popover.")
                return
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            logger.debug("Popover shown")
            // Optional: popover.contentViewController?.view.window?.becomeKey()
        }
    }

    private func setupNotificationObservers() {
        logger.info("Setting up notification observers")

        // Setup different categories of observers
        let menuBarObserver = setupMenuBarVisibilityObserver()
        let highlightMenuBarObserver = setupHighlightMenuBarObserver()

        // Add all observers to array for cleanup
        notificationObservers.append(contentsOf: [menuBarObserver, highlightMenuBarObserver])

        logger.info("Application startup completed successfully")
    }

    private func setupHighlightMenuBarObserver() -> NSObjectProtocol {
        // Observer for highlighting menu bar icon
        NotificationCenter.default.addObserver(
            forName: .highlightMenuBarIcon,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in // Ensure self is captured weakly here as well
                self?.logger.info("Highlighting menu bar icon based on notification (.highlightMenuBarIcon received)")
                AppIconStateController.shared.flashIcon() // Corrected method name
            }
        }
    }

    private func setupMenuBarVisibilityObserver() -> NSObjectProtocol {
        // Observer for menu bar visibility changes
        NotificationCenter.default.addObserver(
            forName: .menuBarVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            if let userInfo = notification.userInfo,
                let isVisible = userInfo["visible"] as? Bool {
                // Use a Task to call the MainActor-isolated method
                Task { @MainActor in
                    self.updateMenuBarVisibility(isVisible)
                }
            }
        }
    }

    // @objc func showWelcomeWindow() { ... } // Moved to WindowManager

    // MARK: - Accessibility Permissions

    // /// Checks accessibility permissions and prompts the user if needed.
    // /// This function is essential for AXorcist to operate correctly.
    // func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) { ... } // Moved to WindowManager

    // MARK: - MenuManagerDelegate Conformance

    // Removed duplicate methods that are in AppDelegate+MenuManagerDelegate.swift
    /*
    func showSettings() { ... }
    func toggleStartAtLogin() { ... }
    func toggleDebugMenu() { ... }
    func showAbout() { ... }
    */

    deinit {
        // In deinit, we need direct synchronous cleanup
        // Clean up notification observers directly
        // Using MainActor.assumeIsolated for safe access in nonisolated context
        MainActor.assumeIsolated {
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()

            self.logger.info("AppDelegate deinit - notification resources cleaned up")
        }

        // Cancel any timers owned by AppDelegate
        // Note: Each manager is responsible for cleaning up its own timers

        self.logger.info("AppDelegate deinit - resources cleaned up")
    }

    // MARK: - Update Handling (Sparkle)

    @IBAction func checkForUpdates(_ sender: Any?) {
        sparkleUpdaterManager?.updaterController.checkForUpdates(sender)
    }

    // Placeholder for debug overlay functionality
    // TODO: Implement actual debug overlay logic if needed
    func toggleDebugOverlay() {
        logger.info("Debug Overlay Toggled (Placeholder - No UI Change)")
        // Example: self.debugOverlayWindow.toggleVisibility() or post a notification
    }

    // func setupAppleScriptSupport() { /* Placeholder removed, implemented in extension */ }
    // func cleanupAppleScriptSupport() { /* Placeholder removed, implemented in extension */ }


    // MARK: - AXServices and Permissions Management

    // New method to toggle monitoring state
    @objc private func toggleMonitoringState() {
        Defaults[.isGlobalMonitoringEnabled].toggle()
        let state = Defaults[.isGlobalMonitoringEnabled] ? "enabled" : "disabled"
        logger.info("Global monitoring toggled via shortcut: \(state)")
        menuManager?.refreshMenu() // Call refreshMenu to update menu items
    }

    // Helper function to refresh state after onboarding is complete
    private func refreshUIStateAfterOnboarding() {
        logger.info("Onboarding complete. Refreshing UI state.")
        // Example: Ensure monitoring starts if it's globally enabled and was awaiting onboarding completion.
        if Defaults[.isGlobalMonitoringEnabled] && !CursorMonitor.shared.isMonitoringActive {
            logger.info("Global monitoring is enabled, starting monitor loop after onboarding.")
            CursorMonitor.shared.startMonitoringLoop()
        }
        // Refresh menu, etc.
        menuManager?.refreshMenu()
    }
}

// MARK: - WindowManagerDelegate
extension AppDelegate: WindowManagerDelegate {
    func windowManagerDidFinishOnboarding() {
        refreshUIStateAfterOnboarding()
    }

    func windowManagerRequestsAccessibilityPermissions(showPromptIfNeeded: Bool) {
        // This check is now internal to WindowManager if it directly uses AXorcistLib.
        // If AppDelegate needs to trigger its own check method, it can be called here.
        // For now, assuming WindowManager handles the check via its own method.
        // If a distinct AppDelegate method for permissions is still required, it would be:
        // self.checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: showPromptIfNeeded)
        // But since that logic was moved, we might not need this callback if WindowManager calls AXorcistLib directly.
        // However, if the *intent* is that AppDelegate *triggers* its own (now removed) permission logic via this delegate, that's a circular dependency.
        // Assuming the new WindowManager.checkAndPrompt... is the source of truth for this action.
        logger.info("WindowManager requested accessibility check. WindowManager will handle it.")
        // If WindowManager needs to call a specific AppDelegate method to perform the check (that wasn't moved),
        // this delegate method could call that. For now, WindowManager.checkAndPromptForAccessibilityPermissions is self-contained.
        // If the AppDelegate's version of checkAndPromptForAccessibilityPermissions was intended to be kept and called by WindowManager,
        // then this delegate is correct, but the method shouldn't have been fully removed from AppDelegate.
        // Given the refactor, it seems WindowManager's own method is now primary.
        // So, this delegate might be for other callbacks or could be simplified if WindowManager is fully autonomous for this.
        // Let's assume for now that WindowManager's own check is sufficient and this delegate call is a notification.
        // If there's a specific AppDelegate method that needs to run, it would be called here. Example:
        // self.performAppDelegateSpecificPermissionRelatedAction()
        // For now, let's assume the primary check logic resides in WindowManager.
        // A direct call from WindowManager if it holds an axorcist instance:
        windowManager?.checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: showPromptIfNeeded)

    }
}
