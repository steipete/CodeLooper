import Foundation
import Logging // From swift-log dependency
import OSLog // For os.Logger

// MARK: - Log Destination Configuration

public enum LogDestination: Sendable {
    case console
    case osLog
    // case file(URL) // Future possibility
    case none
}

// MARK: - Logging System Setup

/// Manages the bootstrapping of the logging system.
/// This actor ensures that logging is set up safely and only once.
public actor LoggingSystemSetup {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    // Default log level if not specified during bootstrap
    #if DEBUG
        public static let defaultBootstrapLogLevel: Logging.Logger.Level = .debug
    #else
        public static let defaultBootstrapLogLevel: Logging.Logger.Level = .info
    #endif

    // Shared instance for the actor
    public static let shared = LoggingSystemSetup()

    public func bootstrap(destination: LogDestination, minLevel: Logging.Logger.Level? = nil) {
        guard !hasBeenBootstrapped else {
            print("Warning: LoggingSystem.bootstrap called multiple times. Ignoring subsequent calls.")
            return
        }

        let effectiveMinLevel = minLevel ?? Self.defaultBootstrapLogLevel

        LoggingSystem.bootstrap { label in
            var handlers: [LogHandler] = []

            switch destination {
            case .console:
                var consoleHandler = StreamLogHandler.standardOutput(label: label)
                consoleHandler.logLevel = effectiveMinLevel
                handlers.append(consoleHandler)
            case .osLog:
                var osLogHandler = MyOSLogHandler(
                    label: label,
                    subsystem: Bundle.main.bundleIdentifier ?? "me.steipete.codelooper"
                )
                osLogHandler.logLevel = effectiveMinLevel
                handlers.append(osLogHandler)
            // case .file(let url):
            // var fileHandler = try? FileLogHandler(label: label, localFile: url)
            // if var handler = fileHandler {
            //     handler.logLevel = effectiveMinLevel
            //     handlers.append(handler)
            // } else {
            //     // Fallback or error
            //     var fallbackHandler = StreamLogHandler.standardError(label: label)
            //     fallbackHandler.logLevel = .error
            //     handlers.append(fallbackHandler)
            //     print("Error: Could not initialize file logger at \(url). Falling back to stderr for \(label).")
            // }
            case .none:
                // Using SwiftLogNoOpLogHandler if it's available or simply an empty MultiplexLogHandler
                // For an empty MultiplexLogHandler, no logs will be processed.
                // If SwiftLogNoOpLogHandler is part of swift-log or a utility:
                // multiplexHandler.addHandler(SwiftLogNoOpLogHandler())
                // For now, an empty MultiplexLogHandler effectively means no logging for this setup.
                // We can also set a very high log level on a NOP handler if one existed to ensure nothing passes.
                // Effectively, an empty multiplex handler does the job of .none for now.
                break // No handlers added means no output.
            }
            return MultiplexLogHandler(handlers)
        }
        hasBeenBootstrapped = true
        print("Logging system bootstrapped to \(destination) with min level \(effectiveMinLevel).")
    }

    // MARK: Private

    // Ensures bootstrap is called only once.
    private var hasBeenBootstrapped = false
}

// Custom LogHandler that wraps os.Logger
private struct MyOSLogHandler: LogHandler {
    // MARK: Lifecycle

    public init(label: String, subsystem: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: label)
    }

    // MARK: Public

    public var metadata: Logging.Logger.Metadata = [:]
    public var logLevel: Logging.Logger.Level = .info

    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file _: String,
        function _: String,
        line _: UInt
    ) {
        guard level >= self.logLevel else { return }

        let effectiveMetadata = self.metadata.merging(metadata ?? [:]) { _, new in new }

        var richMessage = "[\(source)] \(message.description)"
        if !effectiveMetadata.isEmpty {
            richMessage += " " + effectiveMetadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        }

        // Map swift-log levels to os.LogType
        let osLogType: OSLogType = switch level {
        case .trace: // trace is the lowest, often for detailed debugging
            .debug // os.Logger doesn't have a direct 'trace', map to debug
        case .debug: // for debug-level messages
            .debug
        case .info: // for informational messages
            .info
        case .notice: // for conditions that are not error conditions, but might need attention
            .default // os.Logger 'notice' is often treated as default log level
        case .warning: // for warning conditions that might lead to errors
            .error // os.Logger doesn't have 'warning', map to error as it's more severe than .default
        case .error: // for error conditions
            .error
        case .critical: // for critical conditions that will likely lead to termination
            .fault // os.Logger 'critical' maps to fault
        }

        osLogger.log(level: osLogType, "\(richMessage, privacy: .public)")
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }

    // MARK: Private

    private let osLogger: os.Logger
}

public struct Logger: Sendable {
    // MARK: Lifecycle

    // Ensure bootstrap is called before any logger is initialized.
    // This is a bit of a safety net, but explicit bootstrap at app start is better.
    // private static let ensureBootstrap: Void = { // REMOVED
    //     // This will attempt to bootstrap with default if not already done.
    //     // Ideally, the app calls bootstrap explicitly first.
    //     Task { // Call bootstrap asynchronously
    //         await LoggingSystemSetup.shared.bootstrap(destination: .osLog) // Default to osLog if not explicitly set
    //     }
    //     return
    // }()

    public init(label: String? = nil, category: LogCategory) {
        // _ = Logger.ensureBootstrap // REMOVED: Ensures LoggingSystem.bootstrap has been called

        let effectiveLabel: String = if let label {
            label
        } else {
            // Construct a label from bundle ID and category if not provided
            "\(Bundle.main.bundleIdentifier ?? "me.steipete.codelooper").\(category.rawValue)"
        }
        self.swiftLogger = Logging.Logger(label: effectiveLabel)
        self.swiftLogger.logLevel = determineInitialLogLevel(for: category)
    }

    // Convenience initializer if label is derived from category
    public init(category: LogCategory) {
        self.init(label: nil, category: category)
    }

    // MARK: Public

    // Log level management
    public var logLevel: Logging.Logger.Level {
        get { swiftLogger.logLevel }
        set { swiftLogger.logLevel = newValue }
    }

    // Static bootstrap function to be called from the application's entry point
    public static func bootstrap(destination: LogDestination, minLevel: Logging.Logger.Level? = nil) {
        Task { // Call bootstrap asynchronously
            await LoggingSystemSetup.shared.bootstrap(destination: destination, minLevel: minLevel)
        }
    }

    // Forwarding methods to the underlying swift-log Logger instance
    // Trace
    public func trace(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.trace(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Debug
    public func debug(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.debug(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Info
    public func info(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.info(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Notice
    public func notice(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.notice(
            message(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    // Warning
    public func warning(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.warning(
            message(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    // Error
    public func error(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.error(message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    // Critical
    public func critical(
        _ message: @autoclosure () -> Logging.Logger.Message,
        metadata: @autoclosure () -> Logging.Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        swiftLogger.critical(
            message(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    // Metadata management
    public subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { swiftLogger[metadataKey: metadataKey] }
        set { swiftLogger[metadataKey: metadataKey] = newValue }
    }

    // MARK: Private

    private var swiftLogger: Logging.Logger // Changed to var

    private func determineInitialLogLevel(for _: LogCategory) -> Logging.Logger.Level {
        // Example: Set a default level, or customize based on category
        // For now, let's respect the handler's default, or set a global minimum.
        // This could also come from Defaults[.logLevel] if we had a global setting.
        #if DEBUG
            return .debug
        #else
            return .info // Or read from Defaults for this category / global
        #endif
    }
}

// Helper to create an OSLogHandler with a subsystem (optional)
// Note: OSLogHandler itself is part of the swift-log package when used on Apple platforms.
// We don't need to redefine it unless we want a custom one.
// If LoggingSystem.bootstrap uses OSLogHandler directly, this struct might not be needed.

// Default global logger instance if someone needs a quick logger without specific category.
// It's generally better to create specific logger instances with categories.
public let defaultLogger = Logger(category: .general)
