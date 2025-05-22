import Foundation

/// Strongly typed definitions for Info.plist keys.
///
/// This enum provides type-safe access to Info.plist values, replacing
/// string-based dictionary lookups with strongly typed properties.
/// It centralizes all Info.plist key definitions in one place for better
/// maintainability and type safety.
public enum InfoKey {
    /// Keys for URL types in Info.plist
    public enum CFBundleURL {
        /// The key for URL schemes array in a URL type dictionary
        public static let schemes = "CFBundleURLSchemes"
        /// The key for URL name in a URL type dictionary
        public static let name = "CFBundleURLName"
        /// The key for URL role in a URL type dictionary
        public static let role = "CFBundleTypeRole"
    }

    /// Keys for app transport security settings
    public enum NSAppTransportSecurity {
        /// The root dictionary key for app transport security settings
        public static let key = "NSAppTransportSecurity"
        /// Allow arbitrary loads key
        public static let allowsArbitraryLoads = "NSAllowsArbitraryLoads"
        /// Allow arbitrary loads in web content key
        public static let allowsArbitraryLoadsInWebContent = "NSAllowsArbitraryLoadsInWebContent"
        /// Forward secrecy key
        public static let requiresForwardSecrecy = "NSRequiresForwardSecrecy"
        /// Exception domains dictionary key
        public static let exceptionDomains = "NSExceptionDomains"

        /// Keys for exception domain configuration
        public enum ExceptionDomain {
            /// Allow insecure HTTP loads
            public static let allowsInsecureHTTPLoads = "NSAllowsInsecureHTTPLoads"
            /// Include subdomains
            public static let includesSubdomains = "NSIncludesSubdomains"
            /// Require forward secrecy
            public static let requiresForwardSecrecy = "NSRequiresForwardSecrecy"
            /// Minimum TLS version
            public static let minimumTLSVersion = "NSMinimumTLSVersion"
        }
    }

    /// Keys for app permissions
    public enum Privacy {
        /// Contacts usage description
        public static let contactsUsageDescription = "NSContactsUsageDescription"
        /// Location usage description
        public static let locationUsageDescription = "NSLocationUsageDescription"
        /// Calendar usage description
        public static let calendarUsageDescription = "NSCalendarUsageDescription"
    }

    /// Standard bundle keys
    public enum Bundle {
        /// Bundle display name
        public static let displayName = "CFBundleDisplayName"
        /// Bundle name
        public static let name = "CFBundleName"
        /// Bundle identifier
        public static let identifier = "CFBundleIdentifier"
        /// Bundle version string
        public static let shortVersionString = "CFBundleShortVersionString"
        /// Bundle build number
        public static let version = "CFBundleVersion"
        /// URL types array
        public static let urlTypes = "CFBundleURLTypes"
        /// Bundle executable
        public static let executable = "CFBundleExecutable"
        /// Bundle development region
        public static let developmentRegion = "CFBundleDevelopmentRegion"
        /// Bundle info dictionary version
        public static let infoDictionaryVersion = "CFBundleInfoDictionaryVersion"
        /// Bundle package type
        public static let packageType = "CFBundlePackageType"
    }

    /// Application-specific keys
    public enum Application {
        /// Is agent (menu bar) application
        public static let isAgent = "LSUIElement"
        /// Application category type
        public static let categoryType = "LSApplicationCategoryType"
        /// Minimum system version
        public static let minimumSystemVersion = "LSMinimumSystemVersion"
        /// Main nib file
        public static let mainNibFile = "NSMainNibFile"
        /// Main storyboard file
        public static let mainStoryboardFile = "NSMainStoryboardFile"
        /// Principal class
        public static let principalClass = "NSPrincipalClass"
    }
}
