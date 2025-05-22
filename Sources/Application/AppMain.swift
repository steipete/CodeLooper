import AppKit
import Combine
import Defaults
import Foundation
import OSLog
import SwiftUI

/**
 * SwiftUI entry point for the FriendshipAI application.
 * This is the modern recommended approach for macOS app structure.
 * Uses an adapter pattern to interface with existing AppKit-based code.
 */
@main
struct AppMain: App {
    private let logger = Logger(subsystem: "com.friendshipai.mac", category: "AppMain")

    // AppDelegate remains the core controller but is now managed by SwiftUI lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    // Use StateObject to ensure the environment persists throughout the app lifecycle
    @StateObject private var appEnvironment = AppEnvironment()

    // No longer needed - we use the OpenSettingsObserver instead

    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        logger.info("Initializing AppMain with SwiftUI lifecycle")

        // Configure app as menu bar app - this is still needed even with SwiftUI
        NSApplication.shared.setActivationPolicy(.accessory)

        // For a struct initializer, we need to avoid async calls that capture self
        // Ensure single instance logic is applied without capturing self
        let appIdentifier = "com.friendshipai.mac.instance"
        let isDebug = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"]?.contains("Xcode") == true ||
            ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let appLogger = logger // Capture logger before passing to Task

        if !isDebug {
            // Set up instance check in the background without awaiting
            Task.detached {
                let instanceExists = await checkForExistingInstance(appIdentifier: appIdentifier)
                if instanceExists {
                    appLogger.warning("Another instance is already running - requesting it to show settings")
                    // Instead of exiting, notify the existing instance to open settings
                    requestPrimaryInstanceShowSettings(appIdentifier: appIdentifier)
                    // Then exit after sending the request
                    exit(0)
                } else {
                    // Register as primary instance
                    setupInstanceListener(appIdentifier: appIdentifier)
                }
            }
        }

        // Check if welcome screen should be shown
        checkWelcomeScreen()

        logger.info("AppMain initialization complete")
    }

    var body: some Scene {
        WindowGroup("FriendshipAI") {
            // Use a ContentView that routes to other views based on state
            EmptyView()
                .frame(width: 0, height: 0)
                .environmentObject(appEnvironment)
                .withSettingsObserver()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)

        // Add the native macOS Settings scene with fixed width
        Settings {
            SettingsView(
                viewModel: MainSettingsViewModel(
                    loginItemManager: appDelegate.loginItemManager ?? LoginItemManager.shared
                )
            )
            .navigationTitle(Constants.appName)
            .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 340)
        }
        .defaultSize(width: 560, height: 340)
    }

    /// Check if welcome screen should be shown based on defaults
    /// This method centralizes the logic for welcome screen display to prevent divergence
    private func checkWelcomeScreen() {
        // Access defaults directly
        let defaults = UserDefaults.standard

        // Check if welcome screen should be shown (first launch or explicitly requested)
        let showWelcomeScreen = defaults.bool(forKey: "showWelcomeScreen")
        let isFirstLaunch = defaults.bool(forKey: "isFirstLaunch")

        if showWelcomeScreen || isFirstLaunch {
            logger.info("Will show welcome screen with SwiftUI lifecycle")

            // Reset the first launch flag if needed
            if isFirstLaunch {
                defaults.set(false, forKey: "isFirstLaunch")
            }

            // Schedule the welcome screen to appear via notification
            NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
        }
    }

    // Set up notification observers for welcome window management
    // NOTE: This method is no longer called from init() to avoid self-capture issues
    // Window observers are handled by WelcomeWindowCoordinator
    private func setupNotificationObservers() {
        // For a struct, we can't use self-capturing closures in init()
        // This is intentionally empty - we rely on WelcomeWindowCoordinator to show the window
    }
}

// MARK: - Global helper functions for the single instance check

/// Checks if another instance of the app is already running
/// - Returns: true if another instance exists (which will show its settings window), false otherwise
private func checkForExistingInstance(appIdentifier: String) async -> Bool {
    let logger = Logger(subsystem: Constants.bundleIdentifier, category: "AppMain")
    let notificationCenter = DistributedNotificationCenter.default()
    let notificationName = Notification.Name(appIdentifier)

    // Get our own process ID to identify ourselves
    let ourProcessID = ProcessInfo.processInfo.processIdentifier

    // Use an actor-isolated property to track instance existence
    let instanceTracker = InstanceTracker()

    let observer = notificationCenter.addObserver(
        forName: notificationName,
        object: nil,
        queue: .main
    ) { notification in
        // Check if this is from another process by looking at the process ID
        if let senderPID = notification.userInfo?["pid"] as? Int,
           senderPID != ourProcessID {
            Task {
                await instanceTracker.markInstanceExists()
                logger.info("Received response from existing instance (PID: \(senderPID))")
            }
        }
    }

    // Post notification to see if another instance responds, include our PID
    notificationCenter.postNotificationName(
        notificationName,
        object: nil,
        userInfo: ["action": "check", "pid": ourProcessID],
        deliverImmediately: true
    )

    // Small delay to allow for responses - using Task.sleep with Duration in async contexts
    try? await Task.sleep(for: .milliseconds(500)) // 0.5 seconds

    // Remove observer
    notificationCenter.removeObserver(observer)

    // Return whether an instance exists
    return await instanceTracker.instanceExists()
}

/// Sets up a listener for instance check requests from other instances
private func setupInstanceListener(appIdentifier: String) {
    let logger = Logger(subsystem: Constants.bundleIdentifier, category: "AppMain")
    let notificationCenter = DistributedNotificationCenter.default()
    let notificationName = Notification.Name(appIdentifier)
    let ourProcessID = ProcessInfo.processInfo.processIdentifier

    logger.info("Registering as primary instance (PID: \(ourProcessID))")

    // Register permanent observer to respond to future checks
    notificationCenter.addObserver(
        forName: notificationName,
        object: nil,
        queue: .main
    ) { notification in
        if let senderInfo = notification.userInfo,
           let action = senderInfo["action"] as? String,
           let senderPID = senderInfo["pid"] as? Int,
           senderPID != ourProcessID {
            switch action {
            case "check":
                // Respond to the notification to signal we are running
                logger.info("Received instance check from another instance (PID: \(senderPID))")
                notificationCenter.postNotificationName(
                    notificationName,
                    object: nil,
                    userInfo: ["action": "response", "pid": ourProcessID],
                    deliverImmediately: true
                )

            case "showSettings":
                // Handle explicit request to show settings window
                logger.info("Received request to show settings from another instance (PID: \(senderPID))")

                // Activate this instance and show settings window on main thread
                Task { @MainActor in
                    NSApp.activate(ignoringOtherApps: true)

                    // Show settings window when requested by another instance
                    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                }

            default:
                logger.info("Received unknown action '\(action)' from another instance (PID: \(senderPID))")
            }
        }
    }
}

/// Requests the primary instance to show its settings window
private func requestPrimaryInstanceShowSettings(appIdentifier: String) {
    let logger = Logger(subsystem: Constants.bundleIdentifier, category: "AppMain")
    let notificationCenter = DistributedNotificationCenter.default()
    let notificationName = Notification.Name(appIdentifier)
    let ourProcessID = ProcessInfo.processInfo.processIdentifier

    logger.info("Requesting primary instance to show settings window")

    // Send a notification to the primary instance to show settings
    notificationCenter.postNotificationName(
        notificationName,
        object: nil,
        userInfo: ["action": "showSettings", "pid": ourProcessID],
        deliverImmediately: true
    )

    // Short delay to ensure notification is delivered before terminating
    Thread.sleep(forTimeInterval: 0.3)
}

// MARK: - Actor for thread-safe instance tracking

/// Simple actor to safely track instance state across threads
actor InstanceTracker {
    private var exists = false

    /// Marks that another instance of the app exists
    func markInstanceExists() {
        exists = true
    }

    /// Returns whether another instance of the app exists
    func instanceExists() -> Bool {
        exists
    }
}
