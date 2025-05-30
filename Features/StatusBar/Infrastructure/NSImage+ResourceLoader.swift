import AppKit
import Foundation

/// Extension providing resource loading capabilities for NSImage.
///
/// This extension provides menu bar icon loading functionality with:
/// - Multiple resource location fallback strategies
/// - Development and production resource path handling
/// - Circular dependency avoidance with ResourceLoader
/// - Bundle resource discovery and caching
/// - Error handling for missing assets
///
/// Used primarily by MenuBarIconManager for status icon loading.
extension NSImage {
    // This is a reimplementation that matches ResourceLoader's functionality
    @MainActor
    static func loadResourceImage(named name: String, fileExtension: String = "png") -> NSImage? {
        // Try various resource locations using portable approaches
        var potentialPaths: [String?] = [
            Bundle.main.path(forResource: name, ofType: fileExtension),
            Bundle.main.bundlePath + "/Contents/Resources/\(name).\(fileExtension)",
            // Relative paths from current directory for development
            "Resources/\(name).\(fileExtension)",
            // Add direct path to Resources directory
            Bundle.main.bundlePath + "/Resources/\(name).\(fileExtension)",
            // For development builds, try a more explicit path
            Bundle.main.bundlePath + "/mac/Resources/\(name).\(fileExtension)",
        ]

        // Add the resourceURL path if available
        if let resourceURL = Bundle.main.resourceURL {
            potentialPaths.append(resourceURL.appendingPathComponent("\(name).\(fileExtension)").path)
            // Also try Resources subdirectory
            potentialPaths.append(resourceURL.appendingPathComponent("Resources/\(name).\(fileExtension)").path)
        }

        // Filter out nil values
        let possiblePaths = potentialPaths.compactMap(\.self)

        // Try each path
        for path in possiblePaths where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                // Configure the image for menu bar if it's the logo, symbol, or menu-bar-icon
                if name == "logo" || name == "symbol" || name.contains("symbol-") || name == "menu-bar-icon" {
                    // For Retina support using standard size
                    image.size = NSSize(width: 22, height: 22)

                    // IMPORTANT: Always set template mode for menu bar icons
                    // This is critical for proper appearance in both light and dark mode
                    image.isTemplate = true

                    // Explicitly add accessibility description
                    image.accessibilityDescription = "CodeLooper Menu Icon"
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
