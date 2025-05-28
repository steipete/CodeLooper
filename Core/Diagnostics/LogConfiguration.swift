@preconcurrency import Foundation
import os.log

// We don't need to define verboseLoggingChanged here as it's already defined in NotificationName+App.swift
// This prevents duplicate definition errors
// extension Notification.Name {
//    static let verboseLoggingChanged = Notification.Name("verboseLoggingChanged")
// }

/// LogConfiguration provides centralized configuration for the logging system
/// allowing runtime adjustment of logging verbosity and filtering
@MainActor
public final class LogConfiguration: @unchecked Sendable {
    // MARK: Lifecycle

    // Observer for notification changes
    // private var notificationObserver: NSObjectProtocol? // REMOVED

    // MARK: - Initialization

    private init() {
        // Initialize with current setting from preferences
        updateVerbosity(false) // Start with false, will be updated from settings later

        // Note: We can't use Defaults observation here because DefaultsKeys are in the main target
        // The main app will need to notify us of changes

        // REMOVED old notification observer setup:
        // notificationObserver = NotificationCenter.default.addObserver(
        //     forName: .verboseLoggingChanged,
        //     object: nil,
        //     queue: .main
        // ) { [weak self] _ in
        //     // Dispatch to MainActor to access Defaults and call isolated method
        //     Task { @MainActor in
        //         guard let self else { return }
        //         let verbose = Defaults[.verboseLogging]
        //         self.updateVerbosity(verbose)
        //     }
        // }
    }

    deinit {
        // The deinit is non-isolated, so we can't directly access actor-isolated properties
        // This is a known pattern for cleanup in actors that need to handle deinit
        // let observer = notificationObserver // REMOVED
        // notificationObserver = nil // REMOVED

        // if let observer { // REMOVED
        //     Task { @MainActor in // REMOVED
        //         NotificationCenter.default.removeObserver(observer) // REMOVED
        //     } // REMOVED
        // } // REMOVED
    }

    // MARK: Public

    // Singleton instance
    public static let shared = LogConfiguration()

    /// Whether verbose logging is enabled
    public private(set) var verboseLogging: Bool = false

    /// Minimum log level that will be logged
    /// Debug logs are only shown when verboseLogging is true
    public private(set) var minimumLogLevel: LogLevel = .info

    /// Categories to exclude from logging
    public var excludedCategories: Set<LogCategory> = []

    // MARK: - Configuration Methods

    /// Update the verbosity setting and adjust minimum log level accordingly
    public func updateVerbosity(_ verbose: Bool) {
        verboseLogging = verbose
        minimumLogLevel = verbose ? .debug : .info
    }

    /// Check if a log message with the given level and category should be logged
    public func shouldLog(level: LogLevel, category: LogCategory) -> Bool {
        // Skip logging for excluded categories
        if excludedCategories.contains(category) {
            return false
        }

        // Enforce minimum log level
        if level < minimumLogLevel {
            return false
        }

        // Handle verbose-only categories
        if category.isVerboseOnly, !verboseLogging {
            return false
        }

        return true
    }

    /// Get a formatted prefix for log messages
    public func getLogPrefix(level: LogLevel, category: LogCategory) -> String {
        "\(level.emoji) [\(category.rawValue)] "
    }

    // MARK: - Helper Methods

    /// Map an OS Log Type to our LogLevel
    public func mapOSLogTypeToLogLevel(_ osLogType: os.OSLogType) -> LogLevel {
        switch osLogType {
        case .debug:
            .debug
        case .info:
            .info
        case .default:
            .notice
        case .error:
            .error
        case .fault:
            .fault
        default:
            .info
        }
    }
}
