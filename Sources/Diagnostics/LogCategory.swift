import Foundation

/// LogCategory defines the different categories of logs in the application
/// This provides a type-safe way to categorize logs
public enum LogCategory: String, CaseIterable {
    // Application lifecycle and general app events
    case app = "App"
    case appDelegate = "AppDelegate"
    
    // Core functionality
    case axorcist = "AXorcist"
    case accessibility = "Accessibility"
    case cursorMonitor = "CursorMonitor"
    case interventionEngine = "InterventionEngine"
    case supervision = "Supervision"
    
    // UI and Settings
    case settings = "Settings"
    case statusBar = "StatusBar"
    case ui = "UI"
    
    // Managers and Utilities
    case defaults = "Defaults"
    case mcpConfig = "MCPConfigManager"
    case sound = "SoundManager"
    case utilities = "Utilities"
    
    // Specific features or components
    case onboarding = "Onboarding"
    case updates = "Updates"
    case diagnostics = "Diagnostics"
    
    // Default or general purpose
    case general = "General"

    // Additional categories for specific functionality
    case auth = "Auth"
    case contacts = "Contacts"
    case api = "API"
    case upload = "Upload"
    case preferences = "Preferences"
    case fileSystem = "FileSystem"
    case menu = "Menu"
    case lifecycle = "Lifecycle"
    case permissions = "Permissions"
    case notifications = "Notifications"
    case keychain = "Keychain"

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
        case .diagnostics, .lifecycle, .axorcist, .accessibility:
            true
        default:
            false
        }
    }
}
