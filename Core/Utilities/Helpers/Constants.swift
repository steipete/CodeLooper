import AppKit
@preconcurrency import Defaults
import Foundation
import SwiftUI

/// Protocol defining standard UI dimensions and constants for consistent application design.
///
/// UIConstantsProvider ensures all UI components use standardized dimensions,
/// animation durations, and layout parameters for a cohesive user experience.
public protocol UIConstantsProvider: Sendable {
    /// Standard window size for settings
    static var settingsWindowSize: NSSize { get }

    /// Navigation bar height
    static var navBarHeight: CGFloat { get }

    /// Default sidebar width
    static var sidebarWidth: CGFloat { get }

    /// Standard content padding
    static var contentPadding: CGFloat { get }

    /// Default animation duration
    static var defaultAnimationDuration: Double { get }

    /// Fast animation duration
    static var fastAnimationDuration: Double { get }
}

/// Central configuration hub for application-wide constants and settings.
///
/// Constants provides:
/// - UI dimensions and layout parameters
/// - External URLs and links
/// - App metadata and identifiers
/// - File paths and resources
/// - Animation timings
/// - Default configuration values
///
/// This enum serves as a single source of truth for all static configuration,
/// making it easy to maintain consistency and update values across the app.
public enum Constants: UIConstantsProvider {
    // MARK: - External Links & Info

    public static let githubRepositoryURL = "https://github.com/codelooper/codelooper"
    public static let githubUsername = "steipete"
    public static let appAuthor = "Peter Steinberger"

    // MARK: - UI Constants

    /// Size of the icon in the menu bar (22x22 for menu bar standard)
    public static let menuBarIconSize = NSSize(width: 22, height: 22)

    /// Name of the icon image resource
    public static let menuBarIconName = "menu-bar-icon"

    /// Standard size for settings windows
    public static let settingsWindowSize = NSSize(width: 350, height: 440)

    // MARK: - UI Colors

    /// Success color for UI elements
    public static let successColorValue: Color = .successGreen

    /// Error color for UI elements
    public static let errorColorValue: Color = .errorRed

    /// Primary color for UI elements
    public static let primaryColorValue: Color = .primaryBlue

    // MARK: - App constants

    /// The application name from the bundle
    public static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CodeLooper"
    }

    /// The application bundle identifier
    public static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "me.steipete.codelooper"
    }

    // MARK: - Test Environment

    /// Check if running in test mode to disable UI interactions and permissions
    public static var isTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.arguments.contains("--test-mode") ||
            NSClassFromString("XCTest") != nil
    }

    // UIConstantsProvider implementation
    public static var navBarHeight: CGFloat { 48 }
    public static var sidebarWidth: CGFloat { 240 }
    public static var contentPadding: CGFloat { 16 }
    public static var defaultAnimationDuration: Double { 0.3 }
    public static var fastAnimationDuration: Double { 0.15 }
}

// Adding Color support for UI elements
extension Color {
    static let successGreen = Color(red: 0, green: 0.8, blue: 0)
    static let errorRed = Color(red: 0.8, green: 0, blue: 0)
    static let primaryBlue = Color(red: 0, green: 0, blue: 0.8)
}

// UI Constants extension for general use
public enum UserInterfaceConstants {
    /// The current UI constants provider to use throughout the app
    public static let constants: any UIConstantsProvider.Type = Constants.self
}

// MARK: - Permission Types

/// Available permission types for the app
public enum PermissionType {
    case contacts
}

// MARK: - Access States

public extension Constants {
    /// Access state for permissions and services
    enum AccessState: String, CaseIterable, Codable, Defaults.Serializable {
        case authorized
        case denied
        case restricted
        case notDetermined
        case unknown
    }
}
