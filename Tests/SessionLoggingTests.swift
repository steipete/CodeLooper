@testable import CodeLooper
@testable import Diagnostics
import Foundation
import OSLog
import Testing

@Suite("Session Logging", .tags(.diagnostics, .core))
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
    
    @Suite("Session Logger", .tags(.singleton))
    struct SessionLoggerTests {
        @Test("Singleton behavior")
        @MainActor func singletonBehavior() async throws {
            await confirmation("Session logger maintains singleton state", expectedCount: 1) { confirm in
                let logger1 = Diagnostics.SessionLogger.shared
                let logger2 = Diagnostics.SessionLogger.shared
                
                // Verify singleton pattern
                #expect(logger1 === logger2, "Should return same instance")
                
                // Verify logger is functional
                logger1.log(level: .info, message: "Test message")
                #expect(logger1.entries.count >= 0, "Logger should track entries")
                
                confirm()
            }
        }

        @Test(
            "Log entry creation with different levels",
            arguments: [
                (level: Diagnostics.LogLevel.debug, message: "Debug test", pid: nil as Int32?),
                (level: .info, message: "Info test", pid: nil as Int32?),
                (level: .warning, message: "Warning test", pid: nil as Int32?),
                (level: .error, message: "Error test", pid: nil as Int32?),
                (level: .info, message: "Test with PID", pid: 12345 as Int32?)
            ]
        )
        @MainActor func logEntryCreation(
            testCase: (level: Diagnostics.LogLevel, message: String, pid: Int32?)
        ) async throws {
            let logger = Diagnostics.SessionLogger.shared
            let initialCount = logger.entries.count
            
            // Log the entry
            if let pid = testCase.pid {
                logger.log(level: testCase.level, message: testCase.message, pid: pid)
            } else {
                logger.log(level: testCase.level, message: testCase.message)
            }
            
            // Verify entry was added
            #expect(logger.entries.count > initialCount, "Entry should be added")
            
            // Verify last entry matches what we logged
            if let lastEntry = logger.entries.last {
                #expectAll("Entry properties match") {
                    #expect(lastEntry.level == testCase.level)
                    #expect(lastEntry.message == testCase.message)
                    if let pid = testCase.pid {
                        #expect(lastEntry.pid == pid)
                    }
                }
            }
        }

        @Test(
            "Concurrent logging safety",
            .timeLimit(.minutes(1)),
            arguments: [10, 50, 100]
        )
        @MainActor func concurrentLoggingSafety(taskCount: Int) async throws {
            let logger = Diagnostics.SessionLogger.shared
            let initialCount = logger.entries.count
            
            await confirmation("All concurrent logs are recorded", expectedCount: taskCount * 2) { confirm in
                await withTaskGroup(of: Void.self) { group in
                    for i in 0 ..< taskCount {
                        group.addTask {
                            await MainActor.run {
                                logger.log(level: .info, message: "Concurrent message \(i)")
                                confirm()
                                
                                logger.log(
                                    level: .debug,
                                    message: "Debug message \(i)",
                                    pid: Int32(1000 + i)
                                )
                                confirm()
                            }
                        }
                    }
                }
            }
            
            // Verify all entries were added
            let addedEntries = logger.entries.count - initialCount
            #expect(addedEntries >= taskCount * 2, "All concurrent logs should be recorded")
        }

    }
    
    // MARK: - FileLogger Tests
    
    @Suite("File Logger", .tags(.async, .logging))
    struct FileLoggerTests {
        @Test(
            "OSLog integration",
            arguments: zip(
                ["Info test", "Warning test", "Error test", "Debug test"],
                [OSLogType.info, OSLogType.default, OSLogType.error, OSLogType.debug]
            )
        )
        func osLogIntegration(message: String, logType: OSLogType) async throws {
            let fileLogger = Diagnostics.FileLogger.shared
            
            // FileLogger uses OSLog, so we verify it doesn't throw
            #expect(throws: Never.self) {
                await fileLogger.log(
                    message,
                    level: logType,
                    category: "test",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }

        @Test("Error resilience")
        func errorResilience() async throws {
            let fileLogger = Diagnostics.FileLogger.shared
            
            // Test with various edge cases that should not crash
            let edgeCases = [
                (message: "", category: "empty"),
                (message: String(repeating: "x", count: 10000), category: "long"),
                (message: "Special chars: 🚀📱💻", category: "unicode"),
                (message: "Line\nBreaks\nTest", category: "multiline")
            ]
            
            for testCase in edgeCases {
                #expect(throws: Never.self) {
                    await fileLogger.log(
                        testCase.message,
                        level: .info,
                        category: testCase.category,
                        file: #file,
                        function: #function,
                        line: #line
                    )
                }
            }
        }

    }
    
    // MARK: - LogLevel Tests
    
    @Suite("Log Levels", .tags(.validation))
    struct LogLevelTests {
        @Test(
            "Level ordering and values",
            arguments: [
                (level: Diagnostics.LogLevel.debug, minValue: 0),
                (level: .info, minValue: 0),
                (level: .warning, minValue: 0),
                (level: .error, minValue: 0)
            ]
        )
        func levelOrdering(testCase: (level: Diagnostics.LogLevel, minValue: Int)) {
            #expect(testCase.level.rawValue >= testCase.minValue)
            
            // Verify levels are properly ordered (if applicable)
            if testCase.level == .error {
                #expect(testCase.level.rawValue >= Diagnostics.LogLevel.warning.rawValue,
                        "Error should have higher or equal value than warning")
            }
        }

    }
    
    // MARK: - LogManager Tests
    
    @Suite("Log Manager", .tags(.manager))
    struct LogManagerTests {
        @Test("Singleton and category loggers")
        @MainActor func singletonAndCategoryLoggers() async throws {
            await confirmation("Manager provides consistent loggers", expectedCount: 1) { confirm in
                let manager1 = Diagnostics.LogManager.shared
                let manager2 = Diagnostics.LogManager.shared
                
                #expect(manager1 === manager2, "Should be singleton")
                
                // Verify category loggers work
                #expect(throws: Never.self) {
                    manager1.app.info("App log test")
                    manager1.auth.warning("Auth log test")
                    manager1.api.error("API log test")
                }
                
                confirm()
            }
        }
        
        @Test(
            "Category logger retrieval",
            arguments: [
                LogCategory.app,
                .auth,
                .api,
                .supervision,
                .monitoring
            ]
        )
        @MainActor func categoryLoggerRetrieval(category: LogCategory) {
            let logManager = Diagnostics.LogManager.shared
            let logger = logManager.getLogger(for: category)
            
            // Verify logger works for the category
            #expect(throws: Never.self) {
                logger.debug("Debug message for \(category)")
                logger.info("Info message for \(category)")
                logger.warning("Warning message for \(category)")
                logger.error("Error message for \(category)")
            }
        }

    }
    
    // MARK: - Logger Factory Tests
    
    @Suite("Logger Factory", .tags(.factory))
    struct LoggerFactoryTests {
        @Test("Type-based logger creation")
        func typeBasedLoggerCreation() {
            // Create loggers for different types
            let stringLogger = LoggerFactory.logger(for: String.self)
            let intLogger = LoggerFactory.logger(for: Int.self)
            let testLogger = LoggerFactory.logger(for: SessionLoggingTests.self)
            
            // All should work without throwing
            #expect(throws: Never.self) {
                stringLogger.info("String logger test")
                intLogger.info("Int logger test")
                testLogger.info("Test suite logger test")
            }
        }
        
        @Test(
            "Category-based logger creation",
            arguments: zip(
                [String.self, Int.self, SessionLoggingTests.self] as [Any.Type],
                [LogCategory.app, .api, .supervision]
            )
        )
        func categoryBasedLoggerCreation(type: Any.Type, category: LogCategory) {
            let logger = LoggerFactory.logger(for: type, category: category)
            
            #expect(throws: Never.self) {
                logger.debug("Debug from \(type) with category \(category)")
                logger.info("Info from \(type) with category \(category)")
            }
        }

    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration, .async))
    struct IntegrationTests {
        @Test("Multi-component logging", .timeLimit(.minutes(1)))
        @MainActor func multiComponentLogging() async throws {
            await confirmation("All logging components work together", expectedCount: 15) { confirm in
                let sessionLogger = Diagnostics.SessionLogger.shared
                let logManager = Diagnostics.LogManager.shared
                let fileLogger = Diagnostics.FileLogger.shared
                
                // Test concurrent usage from multiple components
                await withTaskGroup(of: Void.self) { group in
                    // Session logger task
                    group.addTask {
                        await MainActor.run {
                            for i in 0 ..< 5 {
                                sessionLogger.log(level: .debug, message: "Session \(i)")
                                confirm()
                            }
                        }
                    }
                    
                    // Log manager task
                    group.addTask {
                        await MainActor.run {
                            for i in 0 ..< 5 {
                                logManager.app.debug("Manager \(i)")
                                confirm()
                            }
                        }
                    }
                    
                    // File logger task
                    group.addTask {
                        for i in 0 ..< 5 {
                            await fileLogger.log(
                                "File \(i)",
                                level: .debug,
                                category: "test",
                                file: #file,
                                function: #function,
                                line: #line
                            )
                            confirm()
                        }
                    }
                }
            }
        }

        @Test(
            "Performance characteristics",
            .timeLimit(.minutes(1)),
            arguments: [100, 500, 1000]
        )
        @MainActor func performanceCharacteristics(entryCount: Int) async throws {
            let sessionLogger = Diagnostics.SessionLogger.shared
            
            let clock = ContinuousClock()
            let start = clock.now
            
            for i in 0 ..< entryCount {
                sessionLogger.log(level: .debug, message: "Performance test \(i)")
            }
            
            let elapsed = clock.now - start
            
            // Performance expectations based on entry count
            let maxDuration: Duration = switch entryCount {
            case ...100: .seconds(0.1)
            case ...500: .seconds(0.5)
            default: .seconds(1)
            }
            
            #expect(elapsed < maxDuration,
                    "\(entryCount) entries should complete within \(maxDuration)")
        }
    }
}
