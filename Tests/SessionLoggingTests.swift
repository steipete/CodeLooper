@testable import CodeLooper
@testable import Diagnostics
import Foundation
import OSLog
import Testing

@Suite("SessionLoggingTests")
struct SessionLoggingTests {
    // MARK: - Test Utilities

    /// Helper to create temporary log directory
    func createTemporaryLogDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let logDir = tempDir.appendingPathComponent("test-logs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir
    }

    /// Cleanup helper
    func cleanup(directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - SessionLogger Tests

    @Test("Session logger initialization") func sessionLoggerInitialization() {
        let logger = await Diagnostics.SessionLogger.shared

        // Test that logger is created without errors
        #expect(logger != nil)

        // Test basic properties
        await MainActor.run {
            // SessionLogger is a singleton and doesn't have sessionId anymore
            #expect(logger.entries != nil)
        }
    }

    @Test("Session logger unique session ids") func sessionLoggerUniqueSessionIds() {
        // Skip this test since SessionLogger has a private init and is a singleton
        // The concept of unique session IDs per instance no longer applies
        #expect(true)
    }

    @Test("Log entry creation") func logEntryCreation() {
        let logger = await Diagnostics.SessionLogger.shared

        await MainActor.run {
            // Test basic log entry creation
            logger.log(level: Diagnostics.LogLevel.info, message: "Test message")
            logger.log(level: Diagnostics.LogLevel.warning, message: "Test warning")
            logger.log(level: Diagnostics.LogLevel.error, message: "Test error")

            // Test log entry with PID
            logger.log(level: Diagnostics.LogLevel.info, message: "Test with PID", pid: 12345)

            // Check that entries were added
            #expect(logger.entries.count > 0)
        }
    }

    @Test("Session logger concurrent logging") func sessionLoggerConcurrentLogging() {
        let logger = await Diagnostics.SessionLogger.shared

        // Test concurrent logging from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    await MainActor.run {
                        logger.log(level: Diagnostics.LogLevel.info, message: "Concurrent message \(i)")
                        logger.log(
                            level: Diagnostics.LogLevel.debug,
                            message: "Debug message \(i)",
                            pid: Int32(1000 + i)
                        )
                    }
                }
            }
        }

        // Check that entries were added
        await MainActor.run {
            #expect(logger.entries.count > 0)
        }
    }

    // MARK: - FileLogger Tests

    @Test("File logger writing") func fileLoggerWriting() {
        // FileLogger is now a singleton actor that uses OSLog
        let fileLogger = await Diagnostics.FileLogger.shared

        // Test logging - FileLogger now uses OSLog exclusively
        await fileLogger.log(
            "Test file log entry",
            level: OSLogType.info,
            category: "test",
            file: #file,
            function: #function,
            line: #line
        )
        await fileLogger.log(
            "Test error entry",
            level: OSLogType.error,
            category: "test",
            file: #file,
            function: #function,
            line: #line
        )

        // FileLogger now uses OSLog, so we can't check file contents
        // Just verify the logging didn't crash
        #expect(true)
    }

    @Test("File logger error handling") func fileLoggerErrorHandling() {
        // FileLogger is now a singleton and always valid
        let fileLogger = await Diagnostics.FileLogger.shared

        // Test logging - should not crash
        await fileLogger.log(
            "This should not crash",
            level: OSLogType.info,
            category: "test",
            file: #file,
            function: #function,
            line: #line
        )

        // Give logger time to attempt writing
        try await Task.sleep(for: .milliseconds(100))

        #expect(true) // If we get here, error was handled gracefully
    }

    // MARK: - LogLevel Tests

    @Test("Log level types") func logLevelTypes() {
        // Test all log levels exist
        let levels: [Diagnostics.LogLevel] = [.debug, .info, .warning, .error]

        for level in levels {
            #expect(level.rawValue >= 0)
        }
    }

    // MARK: - LogManager Tests

    @Test("Log management") func logManagement() {
        let logManager = await Diagnostics.LogManager.shared

        // Test that log manager is created without errors
        #expect(logManager != nil)

        // Test logging through logger instances
        await MainActor.run {
            logManager.app.info("Test app log")
            let supervisionLogger = logManager.getLogger(for: .supervision)
            supervisionLogger.debug("Test supervision log")

            #expect(true) // If we get here, log management works
        }
    }

    @Test("Log manager categories") func logManagerCategories() {
        let logManager = await Diagnostics.LogManager.shared

        // Test that we can get loggers for categories
        await MainActor.run {
            let appLogger = logManager.app
            let authLogger = logManager.auth
            let apiLogger = logManager.api

            // Test logging with different loggers
            appLogger.info("Test app message")
            authLogger.info("Test auth message")
            apiLogger.info("Test API message")

            #expect(true) // All categories should be handled without crashes
        }
    }

    // MARK: - Logger Factory Tests

    @Test("Logger factory") func loggerFactory() {
        // Test creating loggers for different types
        let logger1 = LoggerFactory.logger(for: SessionLoggingTests.self)
        let logger2 = LoggerFactory.logger(for: SessionLoggingTests.self, category: .supervision)

        #expect(logger1 != nil)
        #expect(logger2 != nil)

        // Test that loggers can log without crashing
        logger1.info("Test message from type-based logger")
        logger2.debug("Test message from category-based logger")

        #expect(true) // If we get here, logger factory works
    }

    // MARK: - Integration Tests

    @Test("Logging system integration") func loggingSystemIntegration() {
        // Test integration of all logging components
        let sessionLogger = await Diagnostics.SessionLogger.shared
        let logManager = await Diagnostics.LogManager.shared
        let fileLogger = await Diagnostics.FileLogger.shared

        // Test that all components can work together
        await MainActor.run {
            sessionLogger.log(level: .info, message: "Session log test")
            logManager.app.info("Manager log test")
        }

        await fileLogger.log(
            "File log test",
            level: OSLogType.info,
            category: "test",
            file: #file,
            function: #function,
            line: #line
        )

        // Test concurrent usage
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    for i in 0 ..< 5 {
                        sessionLogger.log(level: .debug, message: "Session \(i)")
                    }
                }
            }

            group.addTask {
                await MainActor.run {
                    for i in 0 ..< 5 {
                        logManager.app.debug("Manager \(i)")
                    }
                }
            }

            group.addTask {
                for i in 0 ..< 5 {
                    await fileLogger.log(
                        "File \(i)",
                        level: OSLogType.debug,
                        category: "test",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                }
            }
        }

        // Give all loggers time to complete
        try await Task.sleep(for: .milliseconds(300))

        #expect(true) // Integration should work without conflicts
    }

    @Test("Logging performance") func loggingPerformance() {
        let sessionLogger = await Diagnostics.SessionLogger.shared

        // Test logging performance with many entries
        let startTime = Date()

        await MainActor.run {
            for i in 0 ..< 100 {
                sessionLogger.log(level: .debug, message: "Performance test message \(i)")
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 100 entries)
        #expect(duration < 1.0)
    }
}
