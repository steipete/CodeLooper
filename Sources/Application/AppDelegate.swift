import AppKit
import AXorcist
import Combine
import Defaults
@preconcurrency import Foundation
@preconcurrency import OSLog
@preconcurrency import ServiceManagement
import Sparkle
import SwiftUI

// Import thread safety helpers
@objc(AppDelegate)
@objcMembers
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate,
    @unchecked Sendable,
    ObservableObject, MenuManagerDelegate {

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
    var axApplicationObserver: AXApplicationObserver? // Observer for app launch/terminate
    var popover: NSPopover?

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?
    public var welcomeWindowController: NSWindowController?

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    // Core services
    private let sessionLogger = SessionLogger.shared
    private lazy var locatorManager = LocatorManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var welcomeWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var updaterController: SPUStandardUpdaterController? // Sparkle updater controller

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
        // Add startup logging with new enhanced logger that writes to both system and file
        logger.info("Application starting up - logs are now stored in Application Support/CodeLooper/Logs")

        // Set up exception handling
        setupExceptionHandling()

        // Initialize core services (axorcist, cursorMonitor will be initialized here)
        logger.info("Initializing core services")
        initializeServices()

        // Initialize Sparkle updater
        logger.info("Initializing Sparkle updater")
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

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
            statusButton.image = NSImage(named: AppIconStateController.shared.currentIconState.imageName)
            statusButton.image?.isTemplate = true
        } else {
            logger.warning("menuManager.statusItem.button is nil, cannot set initial icon image.")
        }
        
        // Setup all notification observers
        setupNotificationObservers()

        // Setup AppleScript support
        setupAppleScriptSupport()

        // Handle first launch or welcome screen logic
        handleFirstLaunchOrWelcomeScreen()
        
        // Observe AppIconStateController state changes
        AppIconStateController.shared.$currentIconState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self = self else { return }
                self.logger.info("App icon state changed to: \\(String(describing: newState))")
                // Only update if not currently flashing, as flash has priority for the image
                if !AppIconStateController.shared.isFlashing {
                    self.menuManager?.statusItem?.button?.image = NSImage(named: newState.imageName)
                    self.menuManager?.statusItem?.button?.image?.isTemplate = true
                }
            }
            .store(in: &cancellables)

        // Observe AppIconStateController flash state
        AppIconStateController.shared.$isFlashing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFlashing in
                guard let self = self, let button = self.menuManager?.statusItem?.button else { return }
                
                if isFlashing {
                    self.logger.info("Icon flash started. Displaying flash_action icon.")
                    // Store the pre-flash image if needed, or rely on currentIconState to restore
                    // For simplicity, we will just set the flash image.
                    // The other observer will set the correct one when isFlashing becomes false.
                    button.image = NSImage(named: "status_icon_flash_action") // Assumed asset name
                    button.image?.isTemplate = true 
                } else {
                    self.logger.info("Icon flash ended. Restoring icon based on currentIconState.")
                    // Revert to the icon determined by the current persistent state
                    let currentPersistentState = AppIconStateController.shared.currentIconState
                    button.image = NSImage(named: currentPersistentState.imageName)
                    button.image?.isTemplate = true
                }
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

        logger.info("Application startup completed successfully")
    }

    // Called when app is initialized with SwiftUI lifecycle
    // This is an additional initializer to support SwiftUI app structure
    override public init() {
        super.init()
        // Minimal setup here, most logic deferred to applicationDidFinishLaunching
        // or specific methods called from there to avoid duplication.
        logger.info("AppDelegate initialized via SwiftUI lifecycle (minimal init, see applicationDidFinishLaunching)")
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

    public func applicationWillTerminate(_: Notification) {
        logger.info("Application is terminating")

        // Stop the Cursor monitoring loop
        CursorMonitor.shared.stopMonitoringLoop()

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

    func showSettingsWindow(_: Any?) {
        logger.info("Show settings window requested")

        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "CodeLooper Settings"
            window.styleMask = [.closable, .titled, .miniaturizable]
            window.isReleasedWhenClosed = false // Keep window instance around
            window.center()
            self.settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Bring app to front
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
        logger.info("Initializing services")

        // Login Item Manager - needs to be initialized early for settings
        loginItemManager = LoginItemManager() // Assuming public init
        logger.info("LoginItemManager initialized")
        
        // AXApplicationObserver - for general app monitoring if needed beyond Cursor
        axApplicationObserver = AXApplicationObserver(axorcist: CursorMonitor.shared.axorcist)
        logger.info("AXApplicationObserver initialized for Cursor.")

        // CursorMonitor is now a shared instance
        logger.info("Core services initialized.")
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

        if !Defaults[.hasShownWelcomeGuide] {
            logger.info("Showing welcome screen for the first time.")
            showWelcomeGuide()
        } else {
            // If welcome guide already shown, just check permissions silently or on an issue
            checkAndPromptForAccessibilityIfNeeded(isInteractive: false)
        }
    }

    @MainActor
    private func showWelcomeGuide() {
        if welcomeWindow == nil {
            let welcomeView = WelcomeGuideView(isPresented: .constant(true)) // Binding needs to close the window
            let hostingController = NSHostingController(rootView: welcomeView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome to CodeLooper"
            window.styleMask = [.closable, .titled]
            window.center()
            self.welcomeWindow = window
            
            // Modify the binding to close the window
            let newWelcomeView = WelcomeGuideView(isPresented: Binding(
                get: { true }, // Window is presented if this func is called
                set: { newValue, _ in 
                    if !newValue {
                        self.welcomeWindow?.close()
                        self.welcomeWindow = nil // Release window
                        Defaults[.hasShownWelcomeGuide] = true // Ensure flag is set
                        // Proceed to permission check after welcome guide is closed
                        self.checkAndPromptForAccessibilityIfNeeded(isInteractive: true)
                    }
                }
            ))
            self.welcomeWindow?.contentViewController = NSHostingController(rootView: newWelcomeView)
        }
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func checkAndPromptForAccessibilityIfNeeded(isInteractive: Bool) {
        let trustedCheckOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [trustedCheckOptionPromptKey: isInteractive]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !isTrusted {
            logger.warning("Accessibility permissions not granted.")
            if isInteractive {
                // Guide user to settings
                let alert = NSAlert()
                alert.messageText = "Accessibility Access Needed"
                alert.informativeText = "CodeLooper requires Accessibility permissions to supervise Cursor. " +
                    "Please enable CodeLooper in System Settings > Privacy & Security > Accessibility."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            logger.info("Accessibility permissions are granted.")
        }
    }

    // MARK: - MenuManagerDelegate Conformance

    func showSettings() {
        logger.info("MenuManagerDelegate: showSettings() called.")
        self.showSettingsWindow(nil)
    }

    func toggleStartAtLogin() {
        logger.info("MenuManagerDelegate: toggleStartAtLogin() called.")
        // Toggle start at login using LoginItemManager
        Defaults[.startAtLogin].toggle()
        loginItemManager?.syncLoginItemWithPreference()
        menuManager?.refreshMenu() // To update checkmark
    }

    func toggleDebugMenu() {
        logger.info("MenuManagerDelegate: toggleDebugMenu() called.")
        // Toggle debug menu visibility via Defaults
        Defaults[.showDebugMenu].toggle()
        menuManager?.refreshMenu() // To show/hide menu items
    }

    func showAbout() {
        logger.info("MenuManagerDelegate: showAbout() called.")
        // Show standard about panel
        // For now, standard about panel
        NSApp.orderFrontStandardAboutPanel(options: [:])
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

    // MARK: - Update Handling (Sparkle)

    func checkForUpdates() {
        logger.info("Check for updates triggered manually.")
        updaterController?.checkForUpdates(nil)
    }
}
