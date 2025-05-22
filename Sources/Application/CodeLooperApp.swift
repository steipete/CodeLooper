import SwiftUI
import Defaults // Ensure Defaults is imported if MainSettingsViewModel uses it directly or indirectly
// import Diagnostics // For SessionLogger if it's in this module - Removed as Diagnostics sources are part of the main CodeLooper target

@main
struct CodeLooperApp: App {
    // Use the App Delegate for lifecycle events and managing non-SwiftUI parts
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ViewModel for settings, initialized as a StateObject to persist across settings views
    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(loginItemManager: LoginItemManager.shared)
    
    // SessionLogger, assuming it's an ObservableObject and can be a @StateObject
    // If SessionLogger.shared is a simple static instance and already an ObservableObject,
    // it can be passed directly or wrapped if @StateObject semantics are desired for its lifecycle here.
    @StateObject private var sessionLogger = SessionLogger.shared

    var body: some Scene {
        // The main application UI is primarily a MenuBarExtra app.
        // No main WindowGroup is defined here as per typical MenuBarExtra app structure.
        // If you had a main window, it would be defined here.

        // Define the Settings scene
        Settings {
            SettingsPanesContainerView()
                .environmentObject(mainSettingsViewModel)
                .environmentObject(sessionLogger) // Provide SessionLogger to the settings environment
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