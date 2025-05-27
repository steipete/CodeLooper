import AppKit
import Diagnostics
import Foundation
import OSLog

@MainActor
extension MenuBarIconManager {
    // Use a dedicated logger for debugging
    private var debugLogger: Diagnostics.Logger {
        Diagnostics.Logger(category: .statusBar)
    }

    /// Debug function to verify icon loading
    func debugIconLoading() {
        debugLogger.info("📊 Starting icon loading debug")

        // Try to load with standard methods
        if NSImage.loadResourceImage(named: Constants.menuBarIconName) != nil {
            debugLogger.info("📊 Successfully loaded icon '\(Constants.menuBarIconName)' with loadResourceImage")
        } else {
            debugLogger.warning("📊 Failed to load icon '\(Constants.menuBarIconName)' with loadResourceImage")
        }

        // Try named image method
        if NSImage(named: Constants.menuBarIconName) != nil {
            debugLogger.info("📊 Successfully loaded icon '\(Constants.menuBarIconName)' with NSImage(named:)")
        } else {
            debugLogger.warning("📊 Failed to load icon '\(Constants.menuBarIconName)' with NSImage(named:)")
        }

        // Try path-based loading
        if let resourcePath = Bundle.main.resourcePath {
            debugLogger.info("📊 Resource path: \(resourcePath)")

            let iconPath = "\(resourcePath)/\(Constants.menuBarIconName).png"
            if NSImage(contentsOfFile: iconPath) != nil {
                debugLogger.info("📊 Successfully loaded icon from path: \(iconPath)")
            } else {
                debugLogger.warning("📊 Failed to load icon from path: \(iconPath)")
            }

            // Try with system symbol
            let systemSymbol = "circle.dashed"
            if NSImage(systemSymbolName: systemSymbol, accessibilityDescription: nil) != nil {
                debugLogger.info("📊 Successfully loaded system symbol: \(systemSymbol)")
            } else {
                debugLogger.warning("📊 Failed to load system symbol: \(systemSymbol)")
            }
        }

        // Check additional resource paths
        if let resourceURL = Bundle.main.resourceURL {
            debugLogger.info("📊 Resource URL: \(resourceURL.path)")
        }

        debugLogger.info("📊 Completed icon loading debug")
    }

    /// Debug function to verify theme handling
    func debugThemeHandling() {
        debugLogger.info("🎨 Starting theme handling debug")

        // Check current appearance
        let appearance = NSApp.effectiveAppearance
        let isDarkMode = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        debugLogger.info("🎨 Current system appearance: \(isDarkMode ? "dark" : "light") mode")

        // Try accessing theme-specific resources
        let themeSuffix = isDarkMode ? "dark" : "light"
        let specificIconName = "symbol-\(themeSuffix)"

        if NSImage.loadResourceImage(named: specificIconName) != nil {
            debugLogger.info("🎨 Successfully loaded theme-specific icon: \(specificIconName)")
        } else {
            debugLogger.warning("🎨 Failed to load theme-specific icon: \(specificIconName)")
        }

        debugLogger.info("🎨 Completed theme handling debug")
    }

    /// Debug function to show available system symbols
    func listAvailableSystemSymbols() {
        debugLogger.info("📱 Checking common system symbols")

        let commonSymbols = [
            "circle.dashed",
            "globe",
            "person.circle",
            "star.circle",
            "exclamationmark.triangle",
            "envelope",
            "gear",
            "bell",
            "network"
        ]

        for symbolName in commonSymbols {
            if NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil {
                debugLogger.info("📱 System symbol available: \(symbolName)")
            } else {
                debugLogger.warning("📱 System symbol not available: \(symbolName)")
            }
        }

        debugLogger.info("📱 Completed system symbol check")
    }
}
