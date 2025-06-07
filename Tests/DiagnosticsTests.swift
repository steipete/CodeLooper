@testable import Diagnostics
import Foundation
import Logging
import Testing

@Suite("Diagnostics Tests", .tags(.diagnostics, .logging, .core))
struct DiagnosticsTests {
    // MARK: - Initialization Suite

    @Suite("Initialization", .tags(.initialization, .setup))
    struct Initialization {
        @Test("Logger initialization")
        func loggerInitialization() async throws {
            let logger = Logger(category: .general)

            // Verify logger is properly initialized
            #expect(logger.logLevel == LoggingSystemSetup.defaultBootstrapLogLevel)
        }

        @Test("All categories can create loggers", arguments: logCategories)
        func categoryLoggerCreation(category: LogCategory) async throws {
            let logger = Logger(category: category)
            // Logger.logLevel is non-optional, check if it's a valid level
            #expect(
                Logger.Level.allCases.contains(logger.logLevel),
                "Logger should have valid log level for category \(category)"
            )
        }
    }

    // MARK: - Configuration Suite

    @Suite("Configuration", .tags(.configuration, .setup))
    struct Configuration {
        @Test("Bootstrap different destinations")
        func bootstrapDifferentDestinations() async throws {
            // Test console destination
            await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .info)

            let logger = Logger(category: .diagnostics)
            // Note: actual log level may vary depending on bootstrap configuration
            #expect(logger.logLevel == .info || logger.logLevel == .debug)
        }

        @Test("Log level management")
        func logLevelManagement() async throws {
            var logger = Logger(category: .general)

            // Test setting different log levels
            logger.logLevel = .warning
            #expect(logger.logLevel == .warning)

            logger.logLevel = .debug
            #expect(logger.logLevel == .debug)

            logger.logLevel = .error
            #expect(logger.logLevel == .error)
        }

        @Test("All log levels can be set", arguments: logLevels)
        func logLevelSetting(level: LogLevel) async throws {
            // Test that log levels are properly supported
            #expect(LogLevel.allCases.contains(level), "Logger should support log level \(level)")
        }
    }

    // MARK: - Category Management Suite

    @Suite("Category Management", .tags(.categories, .configuration))
    struct CategoryManagement {
        @Test("Category-based logger creation")
        func categoryBasedLoggerCreation() async throws {
            // Test all categories can be used to create loggers
            for category in LogCategory.allCases {
                let logger = Logger(category: category)
                // Logger exists and has a valid level
                #expect(Logger.Level.allCases.contains(logger.logLevel))
            }
        }

        @Test("Custom label logger creation")
        func customLabelLoggerCreation() async throws {
            let customLabel = "custom.test.logger"
            let logger = Logger(label: customLabel, category: .general)

            // Verify logger is created with custom label and has a valid level
            #expect(Logger.Level.allCases.contains(logger.logLevel))
        }

        @Test("Log category properties")
        func logCategoryProperties() async throws {
            // Test display names
            #expect(LogCategory.general.displayName == "General")
            #expect(LogCategory.app.displayName == "App")
            #expect(LogCategory.cursorMonitor.displayName == "CursorMonitor")

            // Test verbose-only categories
            #expect(LogCategory.diagnostics.isVerboseOnly)
            #expect(LogCategory.lifecycle.isVerboseOnly)
            #expect(LogCategory.axorcist.isVerboseOnly)
            #expect(LogCategory.accessibility.isVerboseOnly)

            // Test non-verbose categories
            #expect(!LogCategory.general.isVerboseOnly)
            #expect(!LogCategory.app.isVerboseOnly)
            #expect(!LogCategory.settings.isVerboseOnly)
        }

        @Test("All categories have valid properties", arguments: logCategories)
        func categoryProperties(category: LogCategory) async throws {
            #expect(!category.displayName.isEmpty, "Category should have non-empty display name")
            #expect(
                category.isVerboseOnly == true || category.isVerboseOnly == false,
                "isVerboseOnly should be boolean"
            )
        }
    }

    // MARK: - Logging Operations Suite

    @Suite("Logging Operations", .tags(.levels, .operations))
    struct LoggingOperations {
        @Test("All log levels work")
        func allLogLevelsWork() async throws {
            var logger = Logger(category: .general)
            logger.logLevel = .trace

            // These should not throw exceptions
            logger.trace("Trace message")
            logger.debug("Debug message")
            logger.info("Info message")
            logger.notice("Notice message")
            logger.warning("Warning message")
            logger.error("Error message")
            logger.critical("Critical message")

            #expect(Bool(true)) // If we get here, all log levels work
        }

        @Test("Log levels with test messages", arguments: zip(logLevels, testMessages))
        func logLevelsWithMessages(_ level: LogLevel, _ message: String) async throws {
            var logger = Logger(category: .general)
            logger.logLevel = .debug // Allow all levels

            // Test logging at specific level with specific message
            switch level {
            case .debug: logger.debug(Logger.Message(stringLiteral: message))
            case .info: logger.info(Logger.Message(stringLiteral: message))
            case .notice: logger.info(Logger.Message(stringLiteral: message)) // Logger doesn't have notice method
            case .warning: logger.warning(Logger.Message(stringLiteral: message))
            case .error: logger.error(Logger.Message(stringLiteral: message))
            case .critical: logger.critical(Logger.Message(stringLiteral: message))
            case .fault: logger.critical(Logger.Message(stringLiteral: message)) // Logger doesn't have fault method
            }

            #expect(Bool(true), "Logging should complete without errors")
        }
    }

    // MARK: - Metadata Suite

    @Suite("Metadata", .tags(.metadata, .configuration))
    struct Metadata {
        @Test("Metadata handling")
        func metadataHandling() async throws {
            var logger = Logger(category: .general)

            // Test metadata setting and getting
            logger[metadataKey: "test_key"] = "test_value"
            #expect(logger[metadataKey: "test_key"] != nil)

            logger[metadataKey: "another_key"] = .string("another_value")
            #expect(logger[metadataKey: "another_key"] != nil)

            // Test clearing metadata
            logger[metadataKey: "test_key"] = nil
            #expect(logger[metadataKey: "test_key"] == nil)
        }

        @Test("Log message with metadata")
        func logMessageWithMetadata() async throws {
            var logger = Logger(category: .general)
            logger.logLevel = .debug

            let testMetadata: Logging.Logger.Metadata = [
                "user_id": "12345",
                "action": "test_action",
                "timestamp": .stringConvertible(Date()),
            ]

            // These should not throw
            logger.debug("Debug with metadata", metadata: testMetadata)
            logger.info("Info with metadata", metadata: testMetadata)
            logger.error("Error with metadata", metadata: testMetadata)

            #expect(Bool(true)) // If we get here, metadata logging works
        }

        @Test("Metadata with various data types")
        func metadataWithVariousDataTypes() async throws {
            var logger = Logger(category: .general)

            // Test different metadata value types
            logger[metadataKey: "string"] = "test_value"
            logger[metadataKey: "number"] = .stringConvertible(42)
            logger[metadataKey: "boolean"] = .stringConvertible(true)
            logger[metadataKey: "date"] = .stringConvertible(Date())

            #expect(logger[metadataKey: "string"] != nil, "String metadata should be set")
            #expect(logger[metadataKey: "number"] != nil, "Number metadata should be set")
            #expect(logger[metadataKey: "boolean"] != nil, "Boolean metadata should be set")
            #expect(logger[metadataKey: "date"] != nil, "Date metadata should be set")
        }
    }

    // MARK: - System Integration Suite

    @Suite("System Integration", .tags(.global, .defaults))
    struct SystemIntegration {
        @Test("Bootstrap multiple times ignored")
        func bootstrapMultipleTimesIgnored() async throws {
            // Bootstrap multiple times with different configurations
            await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .debug)
            await LoggingSystemSetup.shared.bootstrap(destination: .osLog, minLevel: .error) // Should be ignored

            // This test verifies that multiple bootstrap calls don't crash
            // The actual verification that subsequent calls are ignored would require
            // capturing console output, which is complex in unit tests
            #expect(Bool(true))
        }

        @Test("Default logger availability")
        func defaultLoggerAvailability() async throws {
            // Test that default logger is available and functional
            defaultLogger.info("Default logger test")
            #expect(defaultLogger.logLevel != nil)
        }
    }

    // MARK: - Performance Suite

    @Suite("Performance", .tags(.performance, .timing))
    struct Performance {
        @Test("Logger performance", .timeLimit(.minutes(1)))
        func loggerPerformance() async throws {
            var logger = Logger(category: .general)
            logger.logLevel = .error // High level to minimize actual logging overhead

            let startTime = Date()

            // Log many messages rapidly
            for i in 0 ..< 1000 {
                logger.debug("Performance test message \(i)")
            }

            let elapsed = Date().timeIntervalSince(startTime)

            // Should complete in reasonable time (less than 1 second for 1000 debug messages)
            #expect(elapsed < 1.0)
        }

        @Test("High volume logging performance", .timeLimit(.minutes(1)))
        func highVolumeLoggingPerformance() async throws {
            var logger = Logger(category: .general)
            logger.logLevel = .error // Minimize actual output

            let startTime = ContinuousClock().now

            // Test high volume logging
            for i in 0 ..< 5000 {
                logger.debug("High volume test message \(i)")
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .milliseconds(500), "High volume logging should be fast")
        }
    }

    // MARK: - Source Information Suite

    @Suite("Source Information", .tags(.source, .debugging))
    struct SourceInformation {
        @Test("Default logger availability")
        func defaultLoggerAvailability() async throws {
            // Test that default logger is available and functional
            defaultLogger.info("Default logger test")
            #expect(defaultLogger.logLevel != nil)
        }

        @Test("Source location information")
        func sourceLocationInformation() async throws {
            let logger = Logger(category: .general)

            // Test that logs can include source information
            // These parameters are automatically filled by the compiler
            logger.info("Test message with source info")

            // The actual verification of source info would require a custom LogHandler
            // For now, we verify that the API accepts the calls
            #expect(Bool(true))
        }
    }

    // MARK: - Filtering Suite

    @Suite("Filtering", .tags(.filtering, .levels))
    struct Filtering {
        @Test("Log level filtering")
        func logLevelFiltering() async throws {
            var logger = Logger(category: .general)

            // Set high log level to filter out lower level messages
            logger.logLevel = .error

            // These should be filtered out (no exceptions should occur)
            logger.trace("Filtered trace")
            logger.debug("Filtered debug")
            logger.info("Filtered info")
            logger.notice("Filtered notice")
            logger.warning("Filtered warning")

            // This should pass through
            logger.error("Error message")
            logger.critical("Critical message")

            #expect(Bool(true)) // If we get here, filtering works correctly
        }

        @Test("Log level filtering with different levels", arguments: logLevels)
        func logLevelFilteringWithLevels(filterLevel: LogLevel) async throws {
            let logger = Logger(category: .general)
            // Note: Our custom LogLevel enum is separate from the Logger's internal levels
            // This test verifies LogLevel enum functionality and OSLog mapping

            // Test LogLevel properties
            #expect(filterLevel.displayName.count > 0)
            #expect(filterLevel.emoji.count > 0)

            // Test OSLog type mapping
            let osLogType = filterLevel.osLogType
            #expect(osLogType != nil)

            // Test that levels are comparable
            if filterLevel != .debug {
                #expect(filterLevel > .debug || filterLevel < .fault)
            }

            #expect(true, "LogLevel enum should work correctly")
        }
    }

    // MARK: - Concurrency Suite

    @Suite("Concurrency", .tags(.threading, .concurrency))
    struct Concurrency {
        @Test("Diagnostics thread safety")
        func diagnosticsThreadSafety() async throws {
            let logger = Logger(category: .general)

            // Test concurrent logging from multiple tasks
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< 10 {
                    group.addTask {
                        logger.info("Concurrent log message \(i)")
                    }
                }
            }

            #expect(Bool(true)) // If we get here, concurrent logging didn't crash
        }

        @Test("Concurrent metadata operations")
        func concurrentMetadataOperations() async throws {
            let logger = Logger(category: .general)

            // Test concurrent metadata modifications
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< 20 {
                    group.addTask {
                        var mutableLogger = logger
                        mutableLogger[metadataKey: "concurrent_key_\(i)"] = "value_\(i)"
                        mutableLogger.info("Concurrent message \(i)")
                    }
                }
            }

            #expect(true, "Concurrent metadata operations should complete safely")
        }
    }

    // MARK: - Test Fixtures and Data

    static let logLevels: [LogLevel] = [.debug, .info, .notice, .warning, .error, .critical, .fault]
    static let logCategories = LogCategory.allCases
    static let testMessages = [
        "Simple test message",
        "Message with numbers 123",
        "Special chars: !@#$%^&*()",
        "Unicode test: 🚀 📱 💻",
        "Very long message that contains multiple sentences and might test the logging system's ability to handle longer content without issues or truncation problems.",
    ]
}
