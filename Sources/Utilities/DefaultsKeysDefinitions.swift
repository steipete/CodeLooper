@preconcurrency import Defaults
import Foundation

// MARK: - Default Keys Definitions

// Centralized location for all UserDefaults keys used in the application

/// DefaultsKeysDefinitions defines all UserDefaults keys used by the application.
/// This typealias matches the file name to satisfy SwiftLint file_name rule.
public typealias DefaultsKeysDefinitions = Defaults.Keys

@MainActor
extension Defaults.Keys {
    // MARK: - App Settings

    // Startup-related preferences
    static let startAtLogin = Key<Bool>("startAtLogin", default: false)
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)
    static let isFirstLaunch = Key<Bool>("isFirstLaunch", default: true)
    static let showWelcomeScreen = Key<Bool>("showWelcomeScreen", default: false)
    static let hasShownMenuBarHighlight = Key<Bool>("hasShownMenuBarHighlight", default: false)

    // MARK: - App Behavior Settings

    static let showNotifications = Key<Bool>("showNotifications", default: true)
    static let verboseLogging = Key<Bool>("verboseLogging", default: false)
    static let showInMenuBar = Key<Bool>("showInMenuBar", default: true)

    // MARK: - Permissions Settings

    static let contactsAccessState = Key<Constants.AccessState>("contactsAccessState", default: .notDetermined)

    // MARK: - Debug Settings

    static let showDebugMenu = Key<Bool>("showDebugMenu", default: false)
    static let debugModeEnabled = Key<Bool>("debugModeEnabled", default: false)
}
