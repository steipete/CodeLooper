import Foundation

// MARK: - NotificationNames

// Centralized definition of notification names used throughout the application

/// NotificationName defines all notification names used by the application.
/// This typealias matches the file name to satisfy SwiftLint file_name rule.
public typealias NotificationName = Notification.Name

extension Notification.Name {
    // Preferences
    public static let preferencesChanged = Notification.Name("preferencesChanged")

    // Authentication (placeholder for future functionality)
    // Authentication notifications can be added here when needed

    // Reset actions
    public static let requestResetConfirmation = Notification.Name("requestResetConfirmation")
    public static let showSettingsWindow = Notification.Name("showSettingsWindow")
    public static let openSettingsWindow = Notification.Name("openSettingsWindow")
    public static let showWelcomeWindow = Notification.Name("showWelcomeWindow")

    // Settings navigation
    public static let settingsTabSelected = Notification.Name("settingsTabSelected")

    // Debug/Development features
    public static let debugModeChanged = Notification.Name("debugModeChanged")
    public static let verboseLoggingChanged = Notification.Name("verboseLoggingChanged")
    public static let menuBarVisibilityChanged = Notification.Name("menuBarVisibilityChanged")

    // Notification handling
    public static let highlightMenuBarIcon = Notification.Name("highlightMenuBarIcon")
    public static let dismissWelcomeWindow = Notification.Name("dismissWelcomeWindow")
    public static let themeDidChange = Notification.Name("themeDidChange")

    // Application-specific notifications
    public static let userDataChanged = Notification.Name("ai.amantusmachina.codelooper.userDataChanged")
    public static let themePreferenceChanged = Notification.Name("ai.amantusmachina.codelooper.themePreferenceChanged")
    
    // Debug notifications
    public static let debugNotificationTest = Notification.Name("ai.amantusmachina.codelooper.debugNotificationTest")

}
