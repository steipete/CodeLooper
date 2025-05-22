import Foundation
import OSLog
import Defaults

/// LogLevel defines the different levels of logs in the application
/// This provides a type-safe way to categorize logs by severity
public enum LogLevel: Int, Comparable, Sendable, Codable, CaseIterable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case critical = 5
    case fault = 6

    /// Allows comparing log levels to filter by minimum threshold
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Get a formatted name suitable for display
    public var displayName: String {
        switch self {
        case .debug: "Debug"
        case .info: "Info"
        case .notice: "Notice"
        case .warning: "Warning"
        case .error: "Error"
        case .critical: "Critical"
        case .fault: "Fault"
        }
    }

    /// Convert to OSLogType for Apple's logging system
    public var osLogType: OSLogType {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .notice:
            .default
        case .warning:
            .error // OSLog doesn't have a warning level, so we map to error
        case .error:
            .error
        case .critical, .fault:
            .fault
        }
    }

    /// Emoji prefix for visual log level identification in log output
    public var emoji: String {
        switch self {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .notice: "📝"
        case .warning: "⚠️"
        case .error: "❌"
        case .critical: "🚨"
        case .fault: "💥"
        }
    }
}

// Add explicit conformance to Defaults.Serializable
extension LogLevel: Defaults.Serializable {}
