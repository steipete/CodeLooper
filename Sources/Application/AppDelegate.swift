import AppKit
import AXorcistLib
import Combine
import Defaults
import ApplicationServices
@preconcurrency import Foundation
import os
@preconcurrency import OSLog
@preconcurrency import ServiceManagement
import SwiftUI
import KeyboardShortcuts

@objc(AppDelegate)
@objcMembers
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate,
    @unchecked Sendable,
    ObservableObject {

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
    var axApplicationObserver: AXApplicationObserver?
    var sparkleUpdaterManager: SparkleUpdaterManager?
    private var axorcist: AXorcistLib.AXorcist?
    var updaterViewModel: UpdaterViewModel?
    var windowManager: WindowManager?

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    // Core services
    let sessionLogger = SessionLogger.shared
    private lazy var locatorManager = LocatorManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
        logger.info("Application starting up - logs are now stored in Application Support/CodeLooper/Logs")

        setupExceptionHandling()

        logger.info("Initializing core services")
        initializeServices()

        AppIconStateController.shared.setup(cursorMonitor: CursorMonitor.shared)

        if Defaults[.isGlobalMonitoringEnabled] {
            logger.info("Global monitoring is enabled. Starting CursorMonitor loop.")
            CursorMonitor.shared.startMonitoringLoop()
        } else {
            logger.info("Global monitoring is disabled. CursorMonitor loop not started initially.")
        }

        syncLoginItemStatus()

        logger.info("Setting up menu bar")
        setupMenuBar()

        if let statusButton = menuManager?.statusItem?.button {
            statusButton.image = NSImage(named: "MenuBarTemplateIcon")
            statusButton.image?.isTemplate = true
            statusButton.contentTintColor = AppIconStateController.shared.currentTintColor
        } else {
            logger.warning("menuManager.statusItem.button is nil, cannot set initial icon image.")
        }
        
        setupNotificationObservers()

        windowManager?.handleFirstLaunchOrWelcomeScreen()
        
        AppIconStateController.shared.$currentTintColor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTintColor in
                self?.menuManager?.statusItem?.button?.contentTintColor = newTintColor
                self?.logger.info("Menu bar icon tint color updated.")
            }
            .store(in: &cancellables)

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

        axorcist = AXorcistLib.AXorcist()
        if axorcist == nil {
            logger.error("Failed to initialize AXorcist instance.")
        }

        axApplicationObserver = AXApplicationObserver(axorcist: self.axorcist)

        loginItemManager = LoginItemManager.shared

        _ = self.locatorManager
        logger.info("LocatorManager accessed.")
        
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
            logger.info("WindowManager initialized.")
        } else {
            logger.error("LoginItemManager was nil, cannot initialize WindowManager.")
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

        if menuManager == nil {
            menuManager = MenuManager(delegate: self)
        }

        logger.info("Menu bar setup complete - MenuManager handles popover")
    }

    // Remove togglePopover from AppDelegate - MenuManager handles this

    private func setupNotificationObservers() {
        logger.info("Setting up notification observers")

        let menuBarObserver = setupMenuBarVisibilityObserver()
        let highlightMenuBarObserver = setupHighlightMenuBarObserver()

        notificationObservers.append(contentsOf: [menuBarObserver, highlightMenuBarObserver])

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

    private func setupMenuBarVisibilityObserver() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .menuBarVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            if let userInfo = notification.userInfo,
                let isVisible = userInfo["visible"] as? Bool {
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

    /*
    func showSettings() { ... }
    func toggleStartAtLogin() { ... }
    func toggleDebugMenu() { ... }
    func showAbout() { ... }
    */

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

    // MARK: - Update Handling (Sparkle)

    @IBAction func checkForUpdates(_ sender: Any?) {
        sparkleUpdaterManager?.updaterController.checkForUpdates(sender)
    }

    // Placeholder for debug overlay functionality
    // TODO: Implement actual debug overlay logic if needed
    func toggleDebugOverlay() {
        logger.info("Debug Overlay Toggled (Placeholder - No UI Change)")
    }



    // MARK: - AXServices and Permissions Management

    // New method to toggle monitoring state
    @objc private func toggleMonitoringState() {
        Defaults[.isGlobalMonitoringEnabled].toggle()
        let state = Defaults[.isGlobalMonitoringEnabled] ? "enabled" : "disabled"
        logger.info("Global monitoring toggled via shortcut: \(state)")
        menuManager?.refreshMenu()
    }

    // Helper function to refresh state after onboarding is complete
    private func refreshUIStateAfterOnboarding() {
        logger.info("Onboarding complete. Refreshing UI state.")
        if Defaults[.isGlobalMonitoringEnabled] && !CursorMonitor.shared.isMonitoringActive {
            logger.info("Global monitoring is enabled, starting monitor loop after onboarding.")
            CursorMonitor.shared.startMonitoringLoop()
        }
        menuManager?.refreshMenu()
    }
}

extension AppDelegate: WindowManagerDelegate {
    func windowManagerDidFinishOnboarding() {
        refreshUIStateAfterOnboarding()
    }

    func windowManagerRequestsAccessibilityPermissions(showPromptIfNeeded: Bool) {
        logger.info("WindowManager requested accessibility check. WindowManager will handle it.")
        windowManager?.checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: showPromptIfNeeded)
    }
}
