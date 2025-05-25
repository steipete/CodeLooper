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
    ObservableObject {

    /// Shared singleton instance for global access
    public static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    // MARK: - Logger

    // Use custom Logger for categorized logging
    let logger = Logger(category: .appDelegate)
    private var singleInstanceLock: SingleInstanceLock? // For single instance check

    // MARK: - Properties

    // Services - initialized directly in AppDelegate
    var loginItemManager: LoginItemManager?
    var axApplicationObserver: AXApplicationObserver?
    var sparkleUpdaterManager: SparkleUpdaterManager?
    private var axorcist: AXorcist?
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

    // MARK: - App Lifecycle

    // This is managed by SwiftUI's application lifecycle, but it still works with the old setup
    public func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application finished launching.")
        sessionLogger.log(level: .info, message: "Application finished launching.")

        // Single instance check
        singleInstanceLock = SingleInstanceLock(identifier: "me.steipete.codelooper.instance")
        if !singleInstanceLock!.isPrimaryInstance {
            logger.warning("Another instance of CodeLooper is already running. Terminating this instance.")
            // Optionally, bring the other instance to the front
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != NSRunningApplication.current }) {
                runningApp.activate(options: [.activateAllWindows])
            }
            NSApp.terminate(nil)
            return // Important to return here
        }

        // Initialize core services FIRST
        initializeServices() // Ensure windowManager and other services are ready

        // Setup main application components
        setupNotificationObservers()
        // setupSupervision() // Commenting out for now - CursorMonitor.shared might handle its own start via Defaults observation

        // Restore window state or show welcome guide
        handleWindowRestorationAndFirstLaunch()
        
        // Ensure shared instance is set up for other parts of the app that might need it early.
        // However, direct access should be minimized in favor of dependency injection or notifications.
        // Self.shared = self // This is incorrect; shared is a get-only computed property.

        #if DEBUG
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
    }

    // MARK: - Window Management

    // private var aboutWindowController: NSWindowController? // Moved to WindowManager

    // @objc func showAboutWindow() { ... } // Moved to WindowManager

    @objc func showAXpectorWindow() { // New method
        logger.info("AppDelegate: Request to show AXpector window.")
        if windowManager == nil {
            logger.error("WindowManager is nil in AppDelegate when trying to show AXpector window!")
            return
        }
        windowManager?.showAXpectorWindow()
    }

    // MARK: - App Initialization Methods

    private func setupExceptionHandling() {
        logger.info("Setting up exception handling")
        // Configure global exception handler
        NSSetUncaughtExceptionHandler { exception in
            let exceptionLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "me.steipete.codelooper", category: "ExceptionHandler")
            exceptionLogger.critical("Uncaught exception: \(exception.name.rawValue), reason: \(exception.reason ?? "unknown")")

            // Get stack trace
            let callStack = exception.callStackSymbols
            exceptionLogger.critical("Stack trace: \(callStack.joined(separator: "\n"))")
        }
    }

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

    private func syncLoginItemStatus() {
        logger.info("Syncing login item status")
        guard let loginItemManager else {
            logger.error("Cannot sync login item status: loginItemManager is nil")
            return
        }
        loginItemManager.syncLoginItemWithPreference()
    }

    private func setupNotificationObservers() {
        logger.info("Setting up notification observers")

        let highlightMenuBarObserver = setupHighlightMenuBarObserver()

        notificationObservers.append(highlightMenuBarObserver)

        // Observer for showing AXpector Window
        let axpectorObserver = NotificationCenter.default.addObserver(forName: .showAXpectorWindow, object: nil, queue: .main) { [weak self] _ in
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

    // MARK: - Accessibility Permissions

    // /// Checks accessibility permissions and prompts the user if needed.
    // /// This function is essential for AXorcist to operate correctly.
    // func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) { ... } // Moved to WindowManager

    // MARK: - MenuManagerDelegate Conformance
    // Methods implemented in AppDelegate+MenuManagerDelegate.swift

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
    }

    // Helper function to refresh state after onboarding is complete
    private func refreshUIStateAfterOnboarding() {
        logger.info("Onboarding complete. Refreshing UI state.")
        if Defaults[.isGlobalMonitoringEnabled] && !CursorMonitor.shared.isMonitoringActive {
            logger.info("Global monitoring is enabled, starting monitor loop after onboarding.")
            CursorMonitor.shared.startMonitoringLoop()
        }
    }

    private func handleWindowRestorationAndFirstLaunch() {
        // ... existing code ...
    }
}

@MainActor
extension AppDelegate: WindowManagerDelegate {
    func windowManagerDidFinishOnboarding() {
        logger.info("WindowManagerDelegate: Onboarding finished. Performing any post-onboarding tasks.")
    }
    
    // Removed windowManagerRequestsAccessibilityPermissions as WindowManager handles it directly now
}

// MARK: - Menu Actions

// REMOVING MenuManagerDelegate extension as MenuBarExtra handles menu actions directly
/*
extension AppDelegate: MenuManagerDelegate {
    func showSettings() {
        logger.info("Settings menu item clicked (from old delegate path)")
        // This path might still be used if other AppKit parts call it.
        // Otherwise, MenuBarExtra uses SettingsLink or appKitOpenSettingsSubject.
        SettingsService.appKitOpenSettingsSubject.send()
        logger.info("Requested settings open via SettingsService from menu (AppKit bridge - old delegate path).")
    }

    func toggleStartAtLogin() {
        logger.info("Toggle Start at Login menu item clicked (from old delegate path)")
        Defaults[.startAtLogin].toggle()
        loginItemManager?.syncLoginItemWithPreference()
    }

    func toggleDebugMenu() {
        logger.info("Toggle Debug Menu item clicked (from old delegate path)")
        Defaults[.showDebugMenu].toggle()
        refreshUI() 
    }

    func showAbout() {
        logger.info("About menu item clicked (from old delegate path)")
        windowManager?.showAboutWindow()
    }
}
*/

// MARK: - Other App Actions

/// A helper class to ensure only one instance of the application is running.
/// This uses a file lock to detect other instances.
@MainActor
private class SingleInstanceLock {
    private let identifier: String
    private var fileHandle: FileHandle?
    let isPrimaryInstance: Bool

    init(identifier: String) {
        self.identifier = identifier
        #if !DEBUG // Only enforce single instance lock in Release builds
        let lockFileName = "\(identifier).lock"
        let tempDir = FileManager.default.temporaryDirectory
        let lockFilePath = tempDir.appendingPathComponent(lockFileName).path

        if FileManager.default.fileExists(atPath: lockFilePath) {
            // Try to open the lock file for reading. If it succeeds, another instance holds the lock.
            // If it fails, the other instance might have crashed without cleaning up.
            if let handle = FileHandle(forReadingAtPath: lockFilePath) {
                // Check if the process holding the lock is still running
                // This is a basic check; more robust methods might involve PID checking.
                // For simplicity, we assume if the file exists and is readable, another instance is active.
                self.isPrimaryInstance = false
                handle.closeFile() // Close the handle, we don't need to keep it open.
                self.fileHandle = nil // This instance doesn't hold the lock
                AppDelegate.shared?.logger.info("Lock file exists at \(lockFilePath). Another instance is likely running.")
                return
            } else {
                // File exists but can't be opened for reading (e.g., stale lock file)
                // Attempt to remove it and become the primary.
                AppDelegate.shared?.logger.warning("Stale lock file found at \(lockFilePath). Attempting to remove.")
                try? FileManager.default.removeItem(atPath: lockFilePath)
            }
        }

        // Attempt to create and lock the file
        if FileManager.default.createFile(atPath: lockFilePath, contents: nil, attributes: nil) {
            self.fileHandle = FileHandle(forWritingAtPath: lockFilePath)
            if self.fileHandle != nil {
                // Successfully created and got a handle to the lock file. This is the primary instance.
                self.isPrimaryInstance = true
                AppDelegate.shared?.logger.info("Successfully acquired instance lock at \(lockFilePath). This is the primary instance.")
            } else {
                // Failed to get a handle even after creating the file (should be rare)
                self.isPrimaryInstance = false
                AppDelegate.shared?.logger.error("Failed to get file handle for lock file at \(lockFilePath) even after creation.")
            }
        } else {
            // Failed to create the lock file (e.g., permissions issue, or another instance just created it)
            self.isPrimaryInstance = false
            AppDelegate.shared?.logger.error("Failed to create lock file at \(lockFilePath).")
        }
        #else // For DEBUG builds, always assume primary instance
        self.isPrimaryInstance = true
        self.fileHandle = nil // No actual file lock in debug
        AppDelegate.shared?.logger.info("DEBUG build: Single instance lock is bypassed.")
        #endif
    }

    deinit {
        #if !DEBUG // Only manage lock file in Release builds
        // Release the lock if this was the primary instance
        if isPrimaryInstance, let handle = fileHandle {
            handle.closeFile()
            let lockFileName = "\(identifier).lock"
            let tempDir = FileManager.default.temporaryDirectory
            let lockFilePath = tempDir.appendingPathComponent(lockFileName).path
            try? FileManager.default.removeItem(atPath: lockFilePath)
            Task { @MainActor in
                AppDelegate.shared?.logger.info("Released instance lock and removed lock file at \(lockFilePath).")
            }
        }
        #endif
    }
}
