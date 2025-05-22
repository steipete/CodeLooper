import Foundation
import os.log
import OSLog

/// LogManager provides a centralized logging system for the application
/// Since this is already MainActor-isolated, we can safely conform to Sendable
@MainActor
public final class LogManager {
    // MARK: - Singleton access

    /// Shared instance of the LogManager
    public static let shared = LogManager()

    // MARK: - Properties

    /// The OSLog subsystem identifier, typically the bundle identifier
    private let subsystem: String

    /// A map of category-specific loggers
    private var loggers: [LogCategory: Logger] = [:]

    /// File logger for persistent logging
    private let fileLogger: FileLogger

    /// Configuration for logging behavior
    private let configuration: LogConfiguration

    // MARK: - Initialization

    /// Initialize the LogManager with a subsystem
    /// - Parameter subsystem: The OSLog subsystem identifier (typically bundle ID)
    private init(subsystem: String = Constants.bundleIdentifier) {
        self.subsystem = subsystem
        fileLogger = FileLogger.shared
        configuration = LogConfiguration.shared

        // Pre-initialize loggers for all categories
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
    }

    // MARK: - Logger Access

    /// Get a logger for a specific category
    /// - Parameter category: The log category
    /// - Returns: An OSLog Logger for the specified category
    public func getLogger(for category: LogCategory) -> Logger {
        // Return cached logger if available
        if let logger = loggers[category] {
            return logger
        }

        // Create and cache a new logger if needed
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }

    // MARK: - Convenience Loggers

    /// App logger for general application logs
    public var app: Logger {
        getLogger(for: .app)
    }

    /// Auth logger for authentication-related logs
    public var auth: Logger {
        getLogger(for: .auth)
    }

    /// Contacts logger for contacts-related logs
    public var contacts: Logger {
        getLogger(for: .contacts)
    }

    /// API logger for API-related logs
    public var api: Logger {
        getLogger(for: .api)
    }

    /// Upload logger for upload-related logs
    public var upload: Logger {
        getLogger(for: .upload)
    }

    /// Preferences logger for preferences-related logs
    public var preferences: Logger {
        getLogger(for: .preferences)
    }

    /// StatusBar logger for menu bar and status icon logs
    public var statusBar: Logger {
        getLogger(for: .statusBar)
    }

    /// Permissions logger for access-related logs
    public var permissions: Logger {
        getLogger(for: .permissions)
    }

    /// Menu logger for menu item logs
    public var menu: Logger {
        getLogger(for: .menu)
    }

    // MARK: - Generic Logging

    /// Log a message with the specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check if this log should be filtered based on level and category
        guard configuration.shouldLog(level: level, category: category) else {
            return
        }

        // Get the logger for this category
        let logger = getLogger(for: category)

        // Format the file name for display
        let filename = URL(fileURLWithPath: file).lastPathComponent

        // Format the message with appropriate context
        let prefix = configuration.getLogPrefix(level: level, category: category)
        let formattedMessage

            // Show more context for debug logs
            = if level == .debug {
            "\(prefix)\(message) [\(filename):\(line) \(function)]"
        } else {
            "\(prefix)\(message) [\(filename):\(line)]"
        }

        // Log to the OSLog system with the appropriate level
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .notice:
            logger.notice("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .critical, .fault:
            logger.critical("\(formattedMessage)")
        }

        // Log asynchronously to file logger without blocking
        // Capture needed variables to avoid MainActor isolation issues
        let categoryValue = category.rawValue
        let osLogLevel = level.osLogType

        Task.detached { @Sendable in
            await self.fileLogger.log(
                message,
                level: osLogLevel,
                category: categoryValue,
                file: file,
                function: function,
                line: line
            )
        }
    }

    // MARK: - Extended Logging

    /// Log a message with debug level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func debug(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Log a message with info level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func info(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Log a message with notice level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func notice(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .notice, category: category, file: file, function: function, line: line)
    }

    /// Log a message with warning level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func warning(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Log a message with error level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func error(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Log a message with critical level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func critical(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    /// Log a message with fault level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The source file (auto-filled)
    ///   - function: The function name (auto-filled)
    ///   - line: The line number (auto-filled)
    public func fault(
        _ message: String,
        category: LogCategory = .default,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Logger Extensions

extension Logger {
    /// Add method to get the log category from a Logger
    var logCategory: String {
        @MainActor get {
            Mirror(reflecting: self)
                .children
                .first { $0.label == "category" }?
                .value as? String ?? "Default"
        }
    }
}

// MARK: - Global Logger

/// Shared application-wide logger
@MainActor public let log = LogManager.shared
