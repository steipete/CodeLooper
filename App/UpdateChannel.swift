import Foundation

/// Represents the different update channels available to users
public enum UpdateChannel: String, CaseIterable, Codable, Sendable {
    case stable
    case prerelease

    // MARK: Public

    /// Determines if the current app build is a pre-release
    /// - Returns: true if this is a pre-release build, false otherwise
    public static var isPrereleaseBuild: Bool {
        // Check the build-time flag first
        if let prereleaseFlag = Bundle.main.object(forInfoDictionaryKey: "IS_PRERELEASE_BUILD") as? String {
            return prereleaseFlag.lowercased() == "yes" || prereleaseFlag == "1"
        }

        // Fallback: Check version string
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return false
        }

        return defaultChannel(for: version) == .prerelease
    }

    /// User-friendly display name for the channel
    public var displayName: String {
        switch self {
        case .stable:
            "Stable"
        case .prerelease:
            "Pre-release"
        }
    }

    /// URL path for the appcast file
    public var appcastPath: String {
        switch self {
        case .stable:
            "appcast.xml"
        case .prerelease:
            "appcast-prerelease.xml"
        }
    }

    /// Full appcast URL for this channel
    public var appcastURL: String {
        let baseURL = "https://raw.githubusercontent.com/steipete/CodeLooper/main"
        return "\(baseURL)/\(appcastPath)"
    }

    /// Determines the default update channel based on the current app version and build flags
    /// - Parameter appVersion: The current app version string
    /// - Returns: The appropriate default channel
    public static func defaultChannel(for appVersion: String) -> UpdateChannel {
        // First check if this is a pre-release build via the build-time flag
        if let prereleaseFlag = Bundle.main.object(forInfoDictionaryKey: "IS_PRERELEASE_BUILD") as? String,
           prereleaseFlag.lowercased() == "yes" || prereleaseFlag == "1"
        {
            return .prerelease
        }

        // Fallback: Check version string for pre-release keywords
        let lowercaseVersion = appVersion.lowercased()
        let prereleaseKeywords = ["beta", "alpha", "rc", "dev", "nightly", "test"]

        for keyword in prereleaseKeywords where lowercaseVersion.contains(keyword) {
            return .prerelease
        }

        // Default to stable for production builds
        return .stable
    }
}
