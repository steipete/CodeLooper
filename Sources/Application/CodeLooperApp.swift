import Defaults
import KeyboardShortcuts
import os
import SwiftUI

@main
struct CodeLooperApp: App {
    // Use the App Delegate for lifecycle events and managing non-SwiftUI parts
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Initialize SessionLogger first since it's an actor
    @StateObject private var sessionLogger = SessionLogger.shared

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