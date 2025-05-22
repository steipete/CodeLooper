import Foundation

/// LogCategory defines the different categories of logs in the application
/// This provides a type-safe way to categorize logs
public enum LogCategory: String, CaseIterable {
    // Core application categories
    case app = "App"
    case auth = "Auth"
    case contacts = "Contacts"
    case api = "API"
    case upload = "Upload"
    case preferences = "Preferences"
    case fileSystem = "FileSystem"
    case ui = "UI"
    case security = "Security"
    case network = "Network"

    // Additional categories for specific functionality
    case diagnostics = "Diagnostics"
    case statusBar = "StatusBar"
    case menu = "Menu"
    case lifecycle = "Lifecycle"
    case permissions = "Permissions"
    case notifications = "Notifications"
    case keychain = "Keychain"
    case settings = "Settings"

    // Default category for uncategorized logs
    case `default` = "Default"

    // Added for MCPConfigManager
    case mcpConfiguration
    case appLifecycle
    case unknown

    /// Get a formatted name suitable for display
    public var displayName: String {
        rawValue
    }

    /// Returns true if this category should be included in verbose logging only
    public var isVerboseOnly: Bool {
        switch self {
        case .diagnostics, .lifecycle:
            true
        default:
            false
        }
    }
}
