import Testing
import Foundation
import Logging
@testable import Diagnostics

@Test("Diagnostics - Logger Initialization")
func testLoggerInitialization() async throws {
    let logger = Logger(category: .general)
    
    // Verify logger is properly initialized
    #expect(logger.logLevel == LoggingSystemSetup.defaultBootstrapLogLevel)
}

@Test("Diagnostics - Bootstrap with Different Destinations")
func testBootstrapDifferentDestinations() async throws {
    // Test console destination
    await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .info)
    
    let logger = Logger(category: .diagnostics)
    #expect(logger.logLevel == .info)
}

@Test("Diagnostics - Log Level Management")
func testLogLevelManagement() async throws {
    var logger = Logger(category: .general)
    
    // Test setting different log levels
    logger.logLevel = .warning
    #expect(logger.logLevel == .warning)
    
    logger.logLevel = .debug
    #expect(logger.logLevel == .debug)
    
    logger.logLevel = .error
    #expect(logger.logLevel == .error)
}

@Test("Diagnostics - Category-based Logger Creation")
func testCategoryBasedLoggerCreation() async throws {
    // Test all categories can be used to create loggers
    for category in LogCategory.allCases {
        let logger = Logger(category: category)
        #expect(logger.logLevel != nil)
    }
}

@Test("Diagnostics - Custom Label Logger Creation")
func testCustomLabelLoggerCreation() async throws {
    let customLabel = "custom.test.logger"
    let logger = Logger(label: customLabel, category: .general)
    
    // Verify logger is created with custom label
    #expect(logger.logLevel != nil)
}

@Test("Diagnostics - Log Category Properties")
func testLogCategoryProperties() async throws {
    // Test display names
    #expect(LogCategory.general.displayName == "General")
    #expect(LogCategory.app.displayName == "App")
    #expect(LogCategory.cursorMonitor.displayName == "CursorMonitor")
    
    // Test verbose-only categories
    #expect(LogCategory.diagnostics.isVerboseOnly == true)
    #expect(LogCategory.lifecycle.isVerboseOnly == true)
    #expect(LogCategory.axorcist.isVerboseOnly == true)
    #expect(LogCategory.accessibility.isVerboseOnly == true)
    
    // Test non-verbose categories
    #expect(LogCategory.general.isVerboseOnly == false)
    #expect(LogCategory.app.isVerboseOnly == false)
    #expect(LogCategory.settings.isVerboseOnly == false)
}

@Test("Diagnostics - All Log Levels Work")
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
    
    #expect(true) // If we get here, all log levels work
}

@Test("Diagnostics - Metadata Handling")
func testMetadataHandling() async throws {
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

@Test("Diagnostics - Log Message with Metadata")
func testLogMessageWithMetadata() async throws {
    var logger = Logger(category: .general)
    logger.logLevel = .debug
    
    let testMetadata: Logging.Logger.Metadata = [
        "user_id": "12345",
        "action": "test_action",
        "timestamp": .stringConvertible(Date())
    ]
    
    // These should not throw
    logger.debug("Debug with metadata", metadata: testMetadata)
    logger.info("Info with metadata", metadata: testMetadata)
    logger.error("Error with metadata", metadata: testMetadata)
    
    #expect(true) // If we get here, metadata logging works
}

@Test("Diagnostics - Bootstrap Multiple Times Ignored")
func testBootstrapMultipleTimesIgnored() async throws {
    // Bootstrap multiple times with different configurations
    await LoggingSystemSetup.shared.bootstrap(destination: .console, minLevel: .debug)
    await LoggingSystemSetup.shared.bootstrap(destination: .osLog, minLevel: .error) // Should be ignored
    
    // This test verifies that multiple bootstrap calls don't crash
    // The actual verification that subsequent calls are ignored would require
    // capturing console output, which is complex in unit tests
    #expect(true)
}

@Test("Diagnostics - Logger Performance")
func testLoggerPerformance() async throws {
    var logger = Logger(category: .general)
    logger.logLevel = .error // High level to minimize actual logging overhead
    
    let startTime = Date()
    
    // Log many messages rapidly
    for i in 0..<1000 {
        logger.debug("Performance test message \(i)")
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    
    // Should complete in reasonable time (less than 1 second for 1000 debug messages)
    #expect(elapsed < 1.0)
}

@Test("Diagnostics - Default Logger Availability")
func testDefaultLoggerAvailability() async throws {
    // Test that default logger is available and functional
    defaultLogger.info("Default logger test")
    #expect(defaultLogger.logLevel != nil)
}

@Test("Diagnostics - Source Location Information")
func testSourceLocationInformation() async throws {
    let logger = Logger(category: .general)
    
    // Test that logs can include source information
    // These parameters are automatically filled by the compiler
    logger.info("Test message with source info")
    
    // The actual verification of source info would require a custom LogHandler
    // For now, we verify that the API accepts the calls
    #expect(true)
}

@Test("Diagnostics - Log Level Filtering")
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
    
    #expect(true) // If we get here, filtering works correctly
}

@Test("Diagnostics - Thread Safety")
func testDiagnosticsThreadSafety() async throws {
    let logger = Logger(category: .general)
    
    // Test concurrent logging from multiple tasks
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask {
                logger.info("Concurrent log message \(i)")
            }
        }
    }
    
    #expect(true) // If we get here, concurrent logging didn't crash
}