import Foundation
import OSLog

/// Hierarchical log severity levels for diagnostic output.
///
/// LogLevel provides:
/// - Standard severity levels from debug to fault
/// - Integration with Apple's OSLog system
/// - Comparable implementation for filtering
/// - Formatted display names for UI presentation
///
/// Levels follow standard logging conventions where higher values
/// indicate more severe issues. Use debug for detailed diagnostic info,
/// info for general events, warning for potential issues, error for
/// failures, and critical/fault for severe system problems.
public enum LogLevel: Int, Comparable, Sendable, Codable, CaseIterable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case critical = 5
    case fault = 6

    // MARK: Public

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

    /// Allows comparing log levels to filter by minimum threshold
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
