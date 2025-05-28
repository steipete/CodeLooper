import Foundation

/// Enum representing all possible states of the status bar icon
@frozen
public enum StatusIconState: Sendable, Hashable {
    /// Default idle state
    case idle

    /// Active syncing/uploading state
    case syncing

    /// Error state (e.g., upload failed)
    case error
    
    /// Warning state
    case warning

    /// Success state (short-lived after successful operation)
    case success

    /// Authenticated state (shown briefly after auth)
    case authenticated

    /// Unauthenticated state (shown briefly after logout)
    case unauthenticated

    /// Critical system error (e.g., API key invalid)
    case criticalError

    /// Monitoring is paused
    case paused

    /// AI status counts
    case aiStatus(working: Int, notWorking: Int, unknown: Int)

    // MARK: Public
    
    /// Returns a raw string value for the state (used for logging and icon naming)
    public var rawValue: String {
        switch self {
        case .idle: return "idle"
        case .syncing: return "syncing"
        case .success: return "success"
        case .error: return "error"
        case .warning: return "warning"
        case .criticalError: return "criticalError"
        case .paused: return "paused"
        case .aiStatus: return "aiStatus"
        case .authenticated: return "authenticated"
        }
    }

    /// Returns a user-friendly description of the state
    public var description: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing"
        case .error:
            "Error"
        case .warning:
            "Warning"
        case .success:
            "Success"
        case .authenticated:
            "Authenticated"
        case .unauthenticated:
            "Not Logged In"
        case .criticalError:
            "Critical Error"
        case .paused:
            "Paused"
        case .aiStatus(let working, let notWorking, let unknown):
            "AI Status: \(working) working, \(notWorking) not working, \(unknown) unknown"
        }
    }

    /// Returns the tooltip text for this state
    public var tooltipText: String {
        switch self {
        case .idle:
            "CodeLooper"
        case .syncing:
            "CodeLooper - Syncing Contacts..."
        case .error:
            "CodeLooper - Sync Error"
        case .warning:
            "CodeLooper - Warning"
        case .success:
            "CodeLooper - Sync Successful"
        case .authenticated:
            "CodeLooper - Signed In"
        case .unauthenticated:
            "CodeLooper - Signed Out"
        case .criticalError:
            "CodeLooper: Critical Error - Check Settings"
        case .paused:
            "CodeLooper: Supervision Paused"
        case .aiStatus(let working, let notWorking, let unknown):
            "CodeLooper: AI Analysis - \(working) Working, \(notWorking) Not Working, \(unknown) Unknown"
        }
    }

    /// Whether the icon should use template rendering
    var useTemplateImage: Bool {
        switch self {
        case .idle, .authenticated, .unauthenticated, .syncing, .success, .error, .criticalError, .paused:
            return true // Standard states often use template images for macOS consistency
        case .warning:
            return true // Also use template for warning to allow system coloring (e.g. yellow tint on warning)
        case .aiStatus:
            return false // We want to draw specific colors for AI status numbers
        }
    }
}
