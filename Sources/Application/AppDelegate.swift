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
import Sparkle
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

    // View models and coordinators
    public var mainSettingsCoordinator: MainSettingsCoordinator?
    public var welcomeWindowController: NSWindowController?

    // Observer tokens for proper notification cleanup
    @MainActor private var notificationObservers: [NSObjectProtocol] = []

    // Core services
    let sessionLogger = SessionLogger.shared
    private lazy var locatorManager = LocatorManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var welcomeWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var updaterController: SPUStandardUpdaterController? // Sparkle updater controller

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_: Notification) {
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
            statusButton.image = NSImage(named: "MenuBarTemplateIcon")
            statusButton.image?.isTemplate = true
            statusButton.contentTintColor = AppIconStateController.shared.currentTintColor
        } else {
            logger.warning("menuManager.statusItem.button is nil, cannot set initial icon image.")
        }
        
        // Setup all notification observers
        setupNotificationObservers()

        // Handle first launch or welcome screen logic
        handleFirstLaunchOrWelcomeScreen()
        
        
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

    private var aboutWindowController: NSWindowController?

    @objc func showAboutWindow() {
        logger.info("Showing About Window.")
        if aboutWindowController == nil {
            let aboutView = AboutView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), // Match AboutView frame
                styleMask: [.titled, .closable], // Non-resizable, closable
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "About CodeLooper"
            window.isReleasedWhenClosed = false // We manage its lifecycle
            window.contentView = NSHostingView(rootView: aboutView)
            aboutWindowController = NSWindowController(window: window)
        }
        aboutWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

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

    private func initializeServices() {
        logger.info("Initializing services")

        // Initialize login item manager first as other services may depend on it
        loginItemManager = LoginItemManager.shared // Use shared instance for consistency

        // Setup AXorcist and AXApplicationObserver - these should be early
        let axorcistInstance = AXorcistLib.AXorcist() // Qualified with AXorcistLib
        axApplicationObserver = AXApplicationObserver(axorcist: axorcistInstance) // Pass the instance
        logger.info("AXorcistLib and AXApplicationObserver initialized.")

        // Initialize CursorMonitor with the AXorcist instance
        _ = CursorMonitor.shared // Ensures shared instance is initialized, using the one from its static let
        logger.info("CursorMonitor initialized.")

        // Initialize settings coordinator after dependent services
        setupSettingsCoordinator()

        // Initial check for accessibility, can prompt if needed
        // Note: This Task will run on the MainActor due to initializeServices being called from MainActor context
        Task {
            // let keyString = AppDelegate.axTrustedCheckOptionPromptKeyString // Commented out
            // let options = [keyString: true] // Commented out
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(nil) // Pass nil for options
            if accessibilityEnabled {
                logger.info("Accessibility permissions are granted.")
            } else {
                logger.warning("Accessibility permissions are NOT granted (or prompt was dismissed). AXorcist may not function.")
            }
        }
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

    private func handleFirstLaunchOrWelcomeScreen() {
        logger.info("Checking if welcome guide should be shown.")
        if !Defaults[.hasShownWelcomeGuide] {
            logger.info("Welcome guide has not been shown. Displaying now.")
            showWelcomeWindow()
        } else {
            logger.info("Welcome guide already shown. Checking accessibility permissions.")
            // If welcome guide was shown, check permissions directly
            // This is important if the app was quit before granting permissions after welcome.
            checkAndPromptForAccessibilityPermissions()
        }
    }

    @objc func showWelcomeWindow() {
        logger.info("Showing Welcome Window.")
        if welcomeWindowController == nil {
            // Use the WelcomeViewModel
            let welcomeViewModel = WelcomeViewModel(loginItemManager: LoginItemManager.shared) { [weak self] in
                // This completion is called when WelcomeViewModel.finishOnboarding() is executed
                self?.welcomeWindowController?.close()
                self?.welcomeWindowController = nil // Release the window controller
                self?.logger.info("Welcome onboarding flow finished. Accessibility should have been handled within the flow.")
                // No need to call checkAndPromptForAccessibilityPermissions() here if it's part of the WelcomeView flow.
                // Ensure that the app continues normal operation. For example, refresh UI or ensure monitoring starts if enabled.
                self?.refreshUIStateAfterOnboarding()
            }
            // Use WelcomeView with the viewModel
            let welcomeView = WelcomeView(viewModel: welcomeViewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600), // Adjusted size
                styleMask: [.titled, .closable], // Non-resizable, closable
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Welcome to CodeLooper"
            window.isReleasedWhenClosed = false // We manage its lifecycle
            window.contentView = NSHostingView(rootView: welcomeView)
            welcomeWindowController = NSWindowController(window: window)
        }
        welcomeWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true) // Bring app to front for the welcome guide
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Accessibility Permissions

    /// Checks accessibility permissions and prompts the user if needed.
    /// This function is essential for AXorcist to operate correctly.
    func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) {
        logger.info("Checking accessibility permissions.")
        var debugLogs: [String] = []
        var permissionsGranted = false
        do {
            // Check without auto-prompting first using the new global function
            try AXorcistLib.checkAccessibilityPermissions(isDebugLoggingEnabled: false, currentDebugLogs: &debugLogs)
            permissionsGranted = true
            logger.info("Accessibility permissions already granted.")
            Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted.") }
        } catch let error as AccessibilityError {
            if case .notAuthorized = error, showPromptIfNeeded {
                logger.warning("Accessibility permissions not granted. Will attempt to prompt. Error: \(error.localizedDescription)")
                Task { await sessionLogger.log(level: .warning, message: "Accessibility permissions not granted, prompting. Error: \(error.localizedDescription)") }
                debugLogs.removeAll() // Clear logs for the next call
                
                // Attempt to prompt the user
                do {
                    try AXorcistLib.checkAccessibilityPermissions(isDebugLoggingEnabled: false, currentDebugLogs: &debugLogs) // This call will prompt if not trusted
                    permissionsGranted = true // If it doesn't throw, permissions were granted (or already were)
                    logger.info("Accessibility permissions granted after prompt (or were already granted).")
                    Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted after prompt.") }
                } catch let promptError {
                    logger.error("Failed to obtain accessibility permissions after prompt: \(promptError.localizedDescription)")
                    Task { await sessionLogger.log(level: .error, message: "Failed to obtain accessibility permissions after prompt: \(promptError.localizedDescription)") }
                    // As a fallback or alternative, construct the URL to guide the user
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                // Handle other AccessibilityError cases or if showPromptIfNeeded is false
                logger.error("Error checking accessibility permissions: \(error.localizedDescription)")
                Task { await sessionLogger.log(level: .error, message: "Error checking accessibility permissions: \(error.localizedDescription)") }
                if showPromptIfNeeded { // Still guide to settings for other errors if prompting was intended
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } catch {
            // Catch any other non-AccessibilityError types
            logger.error("An unexpected error occurred while checking accessibility permissions: \(error.localizedDescription)")
            Task { await sessionLogger.log(level: .error, message: "Unexpected error checking accessibility permissions: \(error.localizedDescription)") }
            if showPromptIfNeeded {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        if permissionsGranted {
            // Perform any actions needed once permissions are confirmed
        }
    }

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

    func checkForUpdates() {
        logger.info("Check for updates triggered manually.")
        updaterController?.checkForUpdates(nil)
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
