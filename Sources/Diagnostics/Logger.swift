import Foundation
import Logging // From swift-log dependency
import OSLog // For os.Logger

// Global logging system setup
private enum LoggingSetup {
    static let initialized: Bool = {
        LoggingSystem.bootstrap { label in
            // Use our custom OSLogHandler
            var handler = MyOSLogHandler(label: label, subsystem: Bundle.main.bundleIdentifier ?? "me.steipete.codelooper")
            
            // Set log level based on global settings or build configuration
            #if DEBUG
            handler.logLevel = .debug
            #else
            // TODO: Make this configurable via Defaults or a global setting
            handler.logLevel = .info 
            #endif
            
            return handler
        }
        return true
    }()
}

// Custom LogHandler that wraps os.Logger
private struct MyOSLogHandler: LogHandler {
    private let osLogger: os.Logger
    public var metadata: Logging.Logger.Metadata = [:]
    public var logLevel: Logging.Logger.Level = .info

    public init(label: String, subsystem: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: label)
    }

    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let effectiveMetadata = self.metadata.merging(metadata ?? [:], uniquingKeysWith: { (_, new) in new })
        
        var logMessage = message.description
        if !effectiveMetadata.isEmpty {
            logMessage += " " + effectiveMetadata.map { element in "\\(element.key): \\(element.value)" }.joined(separator: ", ")
        }

        // Map swift-log levels to os.LogType
        let osLogType: OSLogType
        switch level {
        case .trace:
            osLogType = .debug // os.Logger doesn't have a direct 'trace', map to debug
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .notice:
            osLogType = .default // os.Logger 'notice' is often treated as default
        case .warning:
            osLogType = .error // os.Logger doesn't have 'warning', map to error
        case .error:
            osLogType = .error
        case .critical:
            osLogType = .fault // os.Logger 'critical' maps to fault
        }
        
        // Include file, function, and line for more context, similar to how print captures it.
        // os_log can take printf-style arguments.
        osLogger.log(level: osLogType, "\\(file):\\(line) \\(function) - \\(logMessage, privacy: .public)")
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }
}

public struct Logger: Sendable {
    private var swiftLogger: Logging.Logger // Changed to var

    public init(label: String? = nil, category: LogCategory) {
        _ = LoggingSetup.initialized // Ensures LoggingSystem.bootstrap is called at least once
        
        let effectiveLabel: String
        if let label = label {
            effectiveLabel = label
        } else {
            // Construct a label from bundle ID and category if not provided
            effectiveLabel = "\\(Bundle.main.bundleIdentifier ?? \"me.steipete.codelooper\").\\(category.rawValue)"
        }
        self.swiftLogger = Logging.Logger(label: effectiveLabel)
        self.swiftLogger.logLevel = determineInitialLogLevel(for: category)
    }

    // Convenience initializer if label is derived from category
    public init(category: LogCategory) {
        self.init(label: nil, category: category)
    }

    private func determineInitialLogLevel(for category: LogCategory) -> Logging.Logger.Level {
        // Example: Set a default level, or customize based on category
        // For now, let's respect the handler's default, or set a global minimum.
        // This could also come from Defaults[.logLevel] if we had a global setting.
        #if DEBUG
        return .debug
        #else
        return .info // Or read from Defaults for this category / global
        #endif
    }

    // Forwarding methods to the underlying swift-log Logger instance
    // Trace
    public func trace(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.trace(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Debug
    public func debug(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.debug(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Info
    public func info(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.info(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Notice
    public func notice(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.notice(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Warning
    public func warning(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.warning(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Error
    public func error(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.error(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Critical
    public func critical(_ message: @autoclosure () -> Logging.Logger.Message, metadata: @autoclosure () -> Logging.Logger.Metadata? = nil, source: @autoclosure () -> String? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        swiftLogger.critical(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    
    // Log level management
    public var logLevel: Logging.Logger.Level {
        get { swiftLogger.logLevel }
        set { swiftLogger.logLevel = newValue }
    }
    
    // Metadata management
    public subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { swiftLogger[metadataKey: metadataKey] }
        set { swiftLogger[metadataKey: metadataKey] = newValue }
    }
}

// Helper to create an OSLogHandler with a subsystem (optional)
// Note: OSLogHandler itself is part of the swift-log package when used on Apple platforms.
// We don't need to redefine it unless we want a custom one.
// If LoggingSystem.bootstrap uses OSLogHandler directly, this struct might not be needed.

// Default global logger instance if someone needs a quick logger without specific category.
// It's generally better to create specific logger instances with categories.
public let defaultLogger = Logger(category: .general)
