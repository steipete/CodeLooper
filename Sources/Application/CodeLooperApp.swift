import Defaults
import Diagnostics
import KeyboardShortcuts
import os
import SwiftUI
import Logging

@main
struct CodeLooperApp: App {
    // MARK: - Properties

    // Use @NSApplicationDelegateAdaptor to connect AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    // Access the shared instance of CursorMonitor
    @StateObject private var cursorMonitor = CursorMonitor.shared
    @StateObject private var sessionLogger = SessionLogger.shared

    // Logger for CodeLooperApp
    private let logger = Logger(category: .app)

    // MARK: - Initialization

    init() {
        // Perform one-time setup for the logging system.
        Diagnostics.Logger.bootstrap(destination: .console, minLevel: .debug)
        // If osLog is also desired:
        // Diagnostics.Logger.bootstrap(destination: .osLog, minLevel: .debug)
        // Note: swift-log's LoggingSystem.bootstrap typically replaces the handler factory.
        // To use multiple handlers, MultiplexLogHandler should be configured within LoggingSystemSetup.

        logger.info("CodeLooperApp initialized. ScenePhase: \(scenePhase)")
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
    @Environment(\.openSettings) private var openSettings // For macOS 14+
    
    var body: some View {
        SettingsPanesContainerView()
            .environmentObject(mainSettingsViewModel)
            .onReceive(SettingsService.openSettingsSubject) { _ in
                openSettings()
            }
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
