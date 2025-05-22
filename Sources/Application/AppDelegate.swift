import AppKit
import Defaults
@preconcurrency import Foundation
@preconcurrency import OSLog
@preconcurrency import ServiceManagement

// Import thread safety helpers
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

    // Logger instance at class level for use throughout the class
    let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "AppDelegate")

    // MARK: - Properties

    // Services - initialized directly in AppDelegate
    var menuManager: MenuManager?
    var loginItemManager: LoginItemManager?

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?
    public var welcomeWindowController: NSWindowController?

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Add startup logging with new enhanced logger that writes to both system and file
        logger.info("Application starting up - logs are now stored in Application Support/CodeLooper/Logs")

        // Set up exception handling
        setupExceptionHandling()

        // Initialize core services
        logger.info("Initializing core services")
        initializeServices()

        // Sync login item preference with system status
        syncLoginItemStatus()

        // Initialize the menu bar and UI
        logger.info("Setting up menu bar")
        setupMenuBar()

        // Setup all notification observers
        setupNotificationObservers()
        
        // Setup AppleScript support
        setupAppleScriptSupport()

        // Handle first launch or welcome screen logic
        handleFirstLaunchOrWelcomeScreen()

        logger.info("Application startup completed successfully")
    }

    // Called when app is initialized with SwiftUI lifecycle
    // This is an additional initializer to support SwiftUI app structure
    override public init() {
        super.init()

        // Log startup
        logger.info("AppDelegate initialized via SwiftUI lifecycle")

        // Set up exception handling
        setupExceptionHandling()

        // Initialize core services
        logger.info("Initializing core services")
        initializeServices()

        // Sync login item preference with system status
        syncLoginItemStatus()

        // Initialize the menu bar and UI
        logger.info("Setting up menu bar")
        setupMenuBar()

        // Setup all notification observers
        setupNotificationObservers()
        
        // Setup AppleScript support
        setupAppleScriptSupport()

        // Handle first launch or welcome screen logic
        handleFirstLaunchOrWelcomeScreen()

        logger.info("Application startup completed successfully in SwiftUI lifecycle")
    }

    // MARK: - Settings Setup

    private func setupSettingsCoordinator() {
        logger.info("Setting up settings coordinator")

        // Initialize the main settings coordinator
        guard let loginItemManager else {
            logger.error("Failed to initialize settings coordinator - missing required services")
            return
        }

        mainSettingsCoordinator = MainSettingsCoordinator(
            loginItemManager: loginItemManager
        )

        logger.info("Settings functionality is ready")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application is terminating")

        // Clean up menu manager
        menuManager?.cleanup()
        
        // Clean up AppleScript support
        cleanupAppleScriptSupport()

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

    func showSettingsWindow(_ sender: Any?) {
        logger.info("Show settings window requested")

        // Use the native Settings framework
        logger.info("Using native Settings framework to open settings")
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }
    
    func showWelcomeWindow() {
        logger.info("Show welcome window requested")
        
        // Post notification to show welcome window
        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
    }

    // MARK: - App Initialization Methods

    private func setupExceptionHandling() {
        logger.info("Setting up exception handling")
        // Configure global exception handler
        NSSetUncaughtExceptionHandler { exception in
            let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "ExceptionHandler")
            logger.critical("Uncaught exception: \(exception.name.rawValue), reason: \(exception.reason ?? "unknown")")

            // Get stack trace
            let callStack = exception.callStackSymbols
            logger.critical("Stack trace: \(callStack.joined(separator: "\n"))")
        }
    }

    private func initializeServices() {
        logger.info("Initializing core services")

        // Initialize services directly in AppDelegate
        loginItemManager = LoginItemManager.shared

        // Verify required services are initialized
        guard let _ = loginItemManager else {
            logger.error("Failed to initialize one or more core services")
            return
        }

        // Create the settings coordinator
        setupSettingsCoordinator()

        logger.info("Core services initialized successfully")
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
        menuManager = MenuManager(delegate: self)

        // Check if menu bar icon should be shown based on user preference
        if !Defaults[.showInMenuBar] {
            logger.info("Menu bar icon is set to hidden in preferences")
            // If the status item exists but shouldn't be shown, remove it
            if let statusItem = menuManager?.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                menuManager?.statusItem = nil
            }
        }
        // Otherwise, MenuManager already calls setupMenuBar() in its initializer
    }

    private func setupNotificationObservers() {
        logger.info("Setting up notification observers")

        // Setup different categories of observers
        let menuBarObserver = setupMenuBarVisibilityObserver()
        let highlightMenuBarObserver = setupHighlightMenuBarObserver()

        // Add all observers to array for cleanup
        notificationObservers.append(contentsOf: [menuBarObserver, highlightMenuBarObserver])
    }

    private func setupHighlightMenuBarObserver() -> NSObjectProtocol {
        // Observer for highlighting menu bar icon
        NotificationCenter.default.addObserver(
            forName: .highlightMenuBarIcon,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.logger.info("Highlighting menu bar icon based on notification")
                self?.menuManager?.highlightMenuBarItem()
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

    private func handleFirstLaunchOrWelcomeScreen() {
        logger.info("Checking if we need to show welcome screen")

        // Show welcome screen on first launch or if explicitly requested
        if Defaults[.showWelcomeScreen] || Defaults[.isFirstLaunch] {
            logger.info("Showing welcome screen")
            Task { @MainActor in
                // Reset the flags
                Defaults[.showWelcomeScreen] = false
                if Defaults[.isFirstLaunch] {
                    Defaults[.isFirstLaunch] = false
                }

                // Show welcome window
                self.showWelcomeWindow()
            }
        }
    }

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
}