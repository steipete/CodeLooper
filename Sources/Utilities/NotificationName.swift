import Foundation

// MARK: - NotificationNames

// Centralized definition of notification names used throughout the application

/// NotificationName defines all notification names used by the application.
/// This typealias matches the file name to satisfy SwiftLint file_name rule.
public typealias NotificationName = Notification.Name

public extension Notification.Name {
    // Preferences
    static let preferencesChanged = Notification.Name("preferencesChanged")

    // Authentication (placeholder for future functionality)
    // Authentication notifications can be added here when needed

    // Reset actions
    static let requestResetConfirmation = Notification.Name("requestResetConfirmation")
    static let showSettingsWindow = Notification.Name("showSettingsWindow")
    static let showWelcomeWindow = Notification.Name("showWelcomeWindow")

    // Settings navigation
    static let settingsTabSelected = Notification.Name("settingsTabSelected")

    // Debug/Development features
    static let debugModeChanged = Notification.Name("debugModeChanged")
    static let verboseLoggingChanged = Notification.Name("verboseLoggingChanged")
    static let menuBarVisibilityChanged = Notification.Name("menuBarVisibilityChanged")
    static let updateMenuBarExtras = NSNotification.Name("updateMenuBarExtras")

    // Notification handling
    static let highlightMenuBarIcon = Notification.Name("highlightMenuBarIcon")
    static let dismissWelcomeWindow = Notification.Name("dismissWelcomeWindow")
    static let themeDidChange = Notification.Name("themeDidChange")

    // Application-specific notifications
    static let userDataChanged = Notification.Name("me.steipete.codelooper.userDataChanged")
    static let themePreferenceChanged = Notification.Name("me.steipete.codelooper.themePreferenceChanged")

    // Debug notifications
    static let debugNotificationTest = Notification.Name("me.steipete.codelooper.debugNotificationTest")

    static let showMenuBarIcon = Notification.Name("showMenuBarIconNotification")
    static let hideMenuBarIcon = Notification.Name("hideMenuBarIconNotification")
    static let mcpSettingsChanged = Notification.Name("mcpSettingsChanged")

    // For AXpector
    static let showAXpectorWindow = Notification.Name("me.steipete.codelooper.showAXpectorWindow")
    
    // Accessibility
    static let accessibilityPermissionsChanged = Notification.Name("me.steipete.codelooper.accessibilityPermissionsChanged")
}
