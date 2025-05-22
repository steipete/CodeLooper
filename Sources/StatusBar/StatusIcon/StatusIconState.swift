import Foundation

/// Enum representing all possible states of the status bar icon
@frozen
public enum StatusIconState: String, Sendable, Hashable, CaseIterable {
    /// Default idle state
    case idle

    /// Active syncing/uploading state
    case syncing

    /// Error state (e.g., upload failed)
    case error

    /// Success state (short-lived after successful operation)
    case success

    /// Authenticated state (shown briefly after auth)
    case authenticated

    /// Unauthenticated state (shown briefly after logout)
    case unauthenticated

    /// Returns a user-friendly description of the state
    public var description: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing"
        case .error:
            "Error"
        case .success:
            "Success"
        case .authenticated:
            "Authenticated"
        case .unauthenticated:
            "Not Logged In"
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
        case .success:
            "CodeLooper - Sync Successful"
        case .authenticated:
            "CodeLooper - Signed In"
        case .unauthenticated:
            "CodeLooper - Signed Out"
        }
    }

    /// Whether the state should use a template image (for menu bar)
    public var useTemplateImage: Bool {
        // Only the idle state should use a template image
        // This ensures proper dark mode handling while making
        // other states visually distinct
        self == .idle
    }
}
