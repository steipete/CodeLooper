import Foundation

/// Defines hierarchical log categories for organized diagnostic output.
///
/// LogCategory enables:
/// - Structured logging with semantic categorization
/// - Filtering logs by functional area
/// - Consistent log organization across the codebase
/// - Easy identification of log sources
///
/// Categories are organized by functional area (app lifecycle, core features,
/// UI components, utilities) to make debugging and log analysis more efficient.
public enum LogCategory: String, CaseIterable, Sendable {
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
    case sound = "SoundEngine"
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
    case jshook = "JSHook"
    case intervention = "Intervention"
    case rules = "Rules"
    case aiAnalysis = "AIAnalysis"
    case networking = "Networking"
    case git = "Git"

    // MARK: Public

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
