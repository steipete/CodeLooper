import AppKit
import Foundation

// MARK: - SharedUserInfo

/// Shared user info structure that can be used for serialization
/// and data exchange throughout the app
struct SharedUserInfo {
    // MARK: Lifecycle

    init(name: String?, email: String, avatarURL: String? = nil, avatarData: Data? = nil) {
        self.name = name
        self.email = email
        self.avatarURL = avatarURL

        // Use the setter with validation
        if let avatarData {
            self.avatarData = avatarData
        }
    }

    // MARK: Internal

    var name: String?
    var email: String
    var avatarURL: String?

    // Property with validation logic
    var avatarData: Data? {
        get {
            _avatarData
        }
        set {
            guard let newData = newValue else {
                _avatarData = nil
                return
            }

            // Check size before storing
            if newData.count <= SharedUserInfo.maxAvatarSize {
                _avatarData = newData
            } else {
                // Just truncate if too large - simple approach to avoid complex imports
                _avatarData = newData.prefix(SharedUserInfo.maxAvatarSize)
                #if DEBUG
                    print("Warning: Avatar data too large (\(newData.count) bytes), " +
                        "truncating to \(SharedUserInfo.maxAvatarSize) bytes")
                #endif
            }
        }
    }

    // MARK: Private

    // Maximum size for avatar data: 1MB
    private static let maxAvatarSize = 1024 * 1024

    private var _avatarData: Data?
}

// MARK: - CodableUserInfo

/// Legacy codable user info for compatibility with older versions and serialization
struct CodableUserInfo: Codable {
    // MARK: Lifecycle

    // Initialize from SharedUserInfo
    init(from sharedInfo: SharedUserInfo) {
        name = sharedInfo.name
        email = sharedInfo.email
        avatarURL = sharedInfo.avatarURL
        avatarData = sharedInfo.avatarData
    }

    // Initialize directly
    init(name: String?, email: String, avatarURL: String? = nil, avatarData: Data? = nil) {
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.avatarData = avatarData
    }

    // MARK: Internal

    var name: String?
    var email: String
    var avatarURL: String?
    var avatarData: Data?
}
