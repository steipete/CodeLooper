import AppKit
import Foundation

// Class for resource and configuration loading
// All methods are static with no mutable state, so can properly conform to Sendable
public final class ResourceLoader: Sendable {
    // Get a value from Info.plist with type safety
    public static func getInfoPlistValue<T>(for key: String) -> T? {
        Bundle.main.infoDictionary?[key] as? T
    }

    // Get a value from the NSAppTransportSecurity dictionary with specific type
    public static func getAppTransportSecurityBoolValue(for key: String) -> Bool? {
        guard let atsDict = Bundle.main.infoDictionary?[InfoKey.NSAppTransportSecurity.key] as? [String: Bool] else {
            return nil
        }
        return atsDict[key]
    }

    // Get URL scheme from Info.plist
    public static func getURLScheme() -> String? {
        guard let urlTypes = Bundle.main.infoDictionary?[InfoKey.Bundle.urlTypes] as? [[String: String]],
              let firstUrlType = urlTypes.first,
              let scheme = firstUrlType[InfoKey.CFBundleURL.schemes]
        else {
            return nil
        }
        return scheme
    }

    // Get app name from Info.plist
    public static func getAppName() -> String? {
        getInfoPlistValue(for: InfoKey.Bundle.name) as String?
    }

    // Get bundle identifier from Info.plist
    public static func getBundleIdentifier() -> String? {
        Bundle.main.bundleIdentifier
    }

    /// Get the app version from Info.plist
    /// - Returns: The app version as string
    public static func getAppVersion() -> String {
        (getInfoPlistValue(for: InfoKey.Bundle.shortVersionString) as String?) ?? "Unknown"
    }

    /// Get the current macOS version
    /// - Returns: macOS version as a string
    public static func getMacOSVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    /// Check if arbitrary network loads are allowed in the app
    /// - Returns: Boolean indicating if NSAllowsArbitraryLoads is enabled
    public static func allowsArbitraryNetworkLoads() -> Bool {
        getAppTransportSecurityBoolValue(for: InfoKey.NSAppTransportSecurity.allowsArbitraryLoads) ?? false
    }
}

// MARK: - Image Resource Loading

extension ResourceLoader {
    // Load an image from various resource locations
    // Making this function sendable-compatible for Swift 6
    @MainActor
    public static func loadImageResource(named name: String, fileExtension: String = "png") -> NSImage? {
        // Try various resource locations using portable approaches
        var potentialPaths: [String?] = [
            Bundle.main.path(forResource: name, ofType: fileExtension),
            Bundle.main.bundlePath + "/Contents/Resources/\(name).\(fileExtension)",
            // Relative paths from current directory for development
            "Resources/\(name).\(fileExtension)",
            // Add direct path to Resources directory
            Bundle.main.bundlePath + "/Resources/\(name).\(fileExtension)",
            // For development builds, try a more explicit path
            Bundle.main.bundlePath + "/mac/Resources/\(name).\(fileExtension)"
        ]

        // Add the resourceURL path if available
        if let resourceURL = Bundle.main.resourceURL {
            potentialPaths.append(resourceURL.appendingPathComponent("\(name).\(fileExtension)").path)
            // Also try Resources subdirectory
            potentialPaths.append(resourceURL.appendingPathComponent("Resources/\(name).\(fileExtension)").path)
        }

        // Filter out nil values
        let possiblePaths = potentialPaths.compactMap { $0 }

        // Try each path
        for path in possiblePaths where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                // Configure the image for menu bar if it's the logo, symbol, or menu-bar-icon
                if name == "logo" || name == "symbol" || name.contains("symbol-") || name == "menu-bar-icon" {
                    // For Retina support, we're now using 44x44 images but displaying at 22x22
                    // This ensures sharp icons on Retina displays
                    image.size = Constants.menuBarIconSize

                    // IMPORTANT: Always set template mode for menu bar icons
                    // This is critical for proper appearance in both light and dark mode
                    image.isTemplate = true

                    // Explicitly add accessibility description
                    image.accessibilityDescription = "FriendshipAI Menu Icon"

                    print("Successfully loaded menu bar icon: \(name) from path: \(path)")
                }
                return image
            }
        }

        // Try loading from bundle by name
        if let image = NSImage(named: name) {
            return image
        }

        return nil
    }
}

// Constants extension to add a helpful method for logo loading
extension Constants {
    // Load the app logo icon - making it MainActor-bound for Swift 6 concurrency safety
    @MainActor
    public static func loadAppLogo() -> NSImage? {
        let logoImage = NSImage.loadResourceImage(named: "menu-bar-icon") ??
            NSImage.loadResourceImage(named: "symbol") ??
            NSImage.loadResourceImage(named: "logo")

        return logoImage ?? NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "FriendshipAI")
    }
}
