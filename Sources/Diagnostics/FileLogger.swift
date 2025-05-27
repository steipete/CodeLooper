import Foundation
import OSLog

/// FileLogger provides support for system-based logging functionality.
///
/// This is implemented as an actor to ensure thread safety across all operations.
/// This class uses OSLog/Logger exclusively for logging, but maintains the
/// diagnostic directory functionality for storing diagnostic reports.
actor FileLogger {
    // MARK: Lifecycle

    private init() {
        // Simple initialization
        Logger(label: "FileLogger", category: .utilities)
            .debug("FileLogger initialized - using OSLog for all logging")
    }

    // MARK: Internal

    static let shared = FileLogger()

    /// Log a message to the system log
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The log category
    ///   - file: The source file
    ///   - function: The function name
    ///   - line: The line number
    func log(_ message: String, level: OSLogType, category: String, file: String, function: String, line: Int) async {
        // Format message for system logging
        let filename = (file as NSString).lastPathComponent

        // Use OSLog directly - no file writing
        let logger = Logger(label: category, category: .utilities)

        // Format the message to include source location information
        let formattedMessage = "\(message) [\(filename):\(line) \(function)]"

        // Log to system log only
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .default:
            logger.notice("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .fault:
            logger.critical("\(formattedMessage)")
        default:
            logger.notice("\(formattedMessage)")
        }
    }

    /// Utility method to get the diagnostic directory URL
    /// This method doesn't access mutable actor state so it can be nonisolated
    ///
    /// Note: Application logs are not written to files and are only available
    /// through the system logging facility (Console.app). This method is used
    /// for storing diagnostic reports that can be shared with support.
    nonisolated func getLogDirectoryURL() -> URL? {
        guard let appSupportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let logDir = appSupportDir.appendingPathComponent("CodeLooper/Logs")

        // Ensure the directory exists
        do {
            if !FileManager.default.fileExists(atPath: logDir.path) {
                try FileManager.default.createDirectory(
                    at: logDir,
                    withIntermediateDirectories: true
                )
            }
        } catch {
            // In case of error, just log and return the path anyway
            let logger = Logger(label: "FileLogger", category: .utilities)
            logger.error("Failed to create log directory: \(error.localizedDescription)")
        }

        return logDir
    }
}
