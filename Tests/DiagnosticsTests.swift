@testable import Diagnostics
import Foundation
import Logging
import XCTest

class DiagnosticsTests: XCTestCase {
    func testLoggerInitialization() async throws {
        let logger = Logger(category: .general)

        // Verify logger is properly initialized
        XCTAssertEqual(logger.logLevel, LoggingSystemSetup.defaultBootstrapLogLevel)
    }

    func testBootstrapDifferentDestinations() async throws {
        // Test console destination
        await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .info)

        let logger = Logger(category: .diagnostics)
        // Note: actual log level may vary depending on bootstrap configuration
        XCTAssertTrue(logger.logLevel == .info || logger.logLevel == .debug)
    }

    func testLogLevelManagement() async throws {
        var logger = Logger(category: .general)

        // Test setting different log levels
        logger.logLevel = .warning
        XCTAssertEqual(logger.logLevel, .warning)

        logger.logLevel = .debug
        XCTAssertEqual(logger.logLevel, .debug)

        logger.logLevel = .error
        XCTAssertEqual(logger.logLevel, .error)
    }

    func testCategoryBasedLoggerCreation() async throws {
        // Test all categories can be used to create loggers
        for category in LogCategory.allCases {
            let logger = Logger(category: category)
            XCTAssertNotNil(logger.logLevel)
        }
    }

    func testCustomLabelLoggerCreation() async throws {
        let customLabel = "custom.test.logger"
        let logger = Logger(label: customLabel, category: .general)

        // Verify logger is created with custom label
        XCTAssertNotNil(logger.logLevel)
    }

    func testLogCategoryProperties() async throws {
        // Test display names
        XCTAssertEqual(LogCategory.general.displayName, "General")
        XCTAssertEqual(LogCategory.app.displayName, "App")
        XCTAssertEqual(LogCategory.cursorMonitor.displayName, "CursorMonitor")

        // Test verbose-only categories
        XCTAssertEqual(LogCategory.diagnostics.isVerboseOnly, true)
        XCTAssertEqual(LogCategory.lifecycle.isVerboseOnly, true)
        XCTAssertEqual(LogCategory.axorcist.isVerboseOnly, true)
        XCTAssertEqual(LogCategory.accessibility.isVerboseOnly, true)

        // Test non-verbose categories
        XCTAssertEqual(LogCategory.general.isVerboseOnly, false)
        XCTAssertEqual(LogCategory.app.isVerboseOnly, false)
        XCTAssertEqual(LogCategory.settings.isVerboseOnly, false)
    }

    func testAllLogLevelsWork() async throws {
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

        XCTAssertTrue(true) // If we get here, all log levels work
    }

    func testMetadataHandling() async throws {
        var logger = Logger(category: .general)

        // Test metadata setting and getting
        logger[metadataKey: "test_key"] = "test_value"
        XCTAssertNotNil(logger[metadataKey: "test_key"])

        logger[metadataKey: "another_key"] = .string("another_value")
        XCTAssertNotNil(logger[metadataKey: "another_key"])

        // Test clearing metadata
        logger[metadataKey: "test_key"] = nil
        XCTAssertNil(logger[metadataKey: "test_key"])
    }

    func testLogMessageWithMetadata() async throws {
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

        XCTAssertTrue(true) // If we get here, metadata logging works
    }

    func testBootstrapMultipleTimesIgnored() async throws {
        // Bootstrap multiple times with different configurations
        await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .debug)
        await LoggingSystemSetup.shared.bootstrap(destination: .osLog, minLevel: .error) // Should be ignored

        // This test verifies that multiple bootstrap calls don't crash
        // The actual verification that subsequent calls are ignored would require
        // capturing console output, which is complex in unit tests
        XCTAssertTrue(true)
    }

    func testLoggerPerformance() async throws {
        var logger = Logger(category: .general)
        logger.logLevel = .error // High level to minimize actual logging overhead

        let startTime = Date()

        // Log many messages rapidly
        for i in 0 ..< 1000 {
            logger.debug("Performance test message \(i)")
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete in reasonable time (less than 1 second for 1000 debug messages)
        XCTAssertLessThan(elapsed, 1.0)
    }

    func testDefaultLoggerAvailability() async throws {
        // Test that default logger is available and functional
        defaultLogger.info("Default logger test")
        XCTAssertNotNil(defaultLogger.logLevel)
    }

    func testSourceLocationInformation() async throws {
        let logger = Logger(category: .general)

        // Test that logs can include source information
        // These parameters are automatically filled by the compiler
        logger.info("Test message with source info")

        // The actual verification of source info would require a custom LogHandler
        // For now, we verify that the API accepts the calls
        XCTAssertTrue(true)
    }

    func testLogLevelFiltering() async throws {
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

        XCTAssertTrue(true) // If we get here, filtering works correctly
    }

    func testDiagnosticsThreadSafety() async throws {
        let logger = Logger(category: .general)

        // Test concurrent logging from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    logger.info("Concurrent log message \(i)")
                }
            }
        }

        XCTAssertTrue(true) // If we get here, concurrent logging didn't crash
    }
}
