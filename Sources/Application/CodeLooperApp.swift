import Defaults
import Diagnostics
import KeyboardShortcuts
import os
import SwiftUI
import Logging

@main
struct CodeLooperApp: App {
    // Use the App Delegate for lifecycle events and managing non-SwiftUI parts
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let appLifecycleManager = CursorMonitor.shared.appLifecycleManager
    private let initialLogger = Logger(category: .app)

    // Initialize SessionLogger first since it's an actor
    @StateObject private var sessionLogger = SessionLogger.shared

    init() {
        // Configure and bootstrap the logging system as early as possible.
        // Use a temporary logger for this initial setup phase if needed.
        // Bootstrap for console
        Diagnostics.Logger.bootstrap(destination: .console, minLevel: .debug)
        // Bootstrap for osLog as well, if desired (swift-log can have multiple handlers,
        // but this bootstrap function sets one system-wide handler at a time)
        // To have both, LoggingSystem.bootstrap would need to be called with a MultiplexLogHandler
        // that includes both. The current Logger.bootstrap replaces the handler.
        // For now, let's assume console is the primary one for this explicit call.
        // If osLog is desired by default, the Logger.ensureBootstrap does set .osLog.
        
        // You can add a log message here to confirm bootstrapping
        // Note: The initialLogger uses Diagnostics.Logger, which itself ensures bootstrapping.
        // So, the explicit bootstrap above might be for specific early setup if default isn't desired.
        let initialLogger = Logger(category: .app) // This Logger is from Diagnostics
        initialLogger.info("CodeLooperApp initialized and logger bootstrapped via explicit call (or ensureBootstrap).")
    }

    var body: some Scene {
        // The main application UI is primarily a MenuBarExtra app.
        // No main WindowGroup is defined here as per typical MenuBarExtra app structure.
        // If you had a main window, it would be defined here.

        // Define the Settings scene
        Settings {
            SettingsSceneView()
                .environmentObject(sessionLogger)
        }
    }
}

struct SettingsSceneView: View {
    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
    )
    
    var body: some View {
        SettingsPanesContainerView()
            .environmentObject(mainSettingsViewModel)
    }
}

// Ensure any necessary supporting structs or extensions (like KeyboardShortcuts.Name definitions
// or Notification.Name definitions if not globally available) are accessible.
// For example, if these are used by settings views:
// extension KeyboardShortcuts.Name {
//     static let toggleMonitoring = Self("toggleMonitoring", default: .init(.m, modifiers: [.command, .shift]))
// }
// extension Notification.Name {
//    static let menuBarVisibilityChanged = Notification.Name("menuBarVisibilityChanged")
// } 
