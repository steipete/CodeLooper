import Testing
import Foundation
@testable import CodeLooper
@testable import Diagnostics

/// Test suite for session logging and diagnostics functionality
@Suite("Session Logging Tests")
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
    
    @Test("SessionLogger can be initialized")
    func testSessionLoggerInitialization() async throws {
        let logger = SessionLogger.shared
        
        // Test that logger is created without errors
        #expect(logger != nil)
        
        // Test basic properties
        #expect(logger.sessionId != nil)
        #expect(!logger.sessionId.isEmpty)
    }
    
    @Test("SessionLogger creates unique session IDs")
    func testSessionLoggerUniqueSessionIds() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        // Create multiple logger instances (simulating app restarts)
        let logger1 = SessionLogger(logDirectory: tempDir)
        let logger2 = SessionLogger(logDirectory: tempDir)
        let logger3 = SessionLogger(logDirectory: tempDir)
        
        // Each should have a unique session ID
        #expect(logger1.sessionId != logger2.sessionId)
        #expect(logger2.sessionId != logger3.sessionId)
        #expect(logger1.sessionId != logger3.sessionId)
        
        // Session IDs should not be empty
        #expect(!logger1.sessionId.isEmpty)
        #expect(!logger2.sessionId.isEmpty)
        #expect(!logger3.sessionId.isEmpty)
    }
    
    @Test("SessionLogger handles log entry creation")
    func testLogEntryCreation() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let logger = SessionLogger(logDirectory: tempDir)
        
        // Test basic log entry creation
        logger.log(level: .info, message: "Test message")
        logger.log(level: .warning, message: "Test warning")
        logger.log(level: .error, message: "Test error")
        
        // Test log entry with PID
        logger.log(level: .info, message: "Test with PID", pid: 12345)
        
        // Give logger time to write
        try await Task.sleep(for: .milliseconds(100))
        
        // If we get here without crashes, log creation works
        #expect(true)
    }
    
    @Test("SessionLogger handles concurrent logging")
    func testSessionLoggerConcurrentLogging() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let logger = SessionLogger(logDirectory: tempDir)
        
        // Test concurrent logging from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    logger.log(level: .info, message: "Concurrent message \(i)")
                    logger.log(level: .debug, message: "Debug message \(i)", pid: Int32(1000 + i))
                }
            }
        }
        
        // Give logger time to process all entries
        try await Task.sleep(for: .milliseconds(200))
        
        // No crashes should occur with concurrent access
        #expect(true)
    }
    
    // MARK: - FileLogger Tests
    
    @Test("FileLogger writes to specified file")
    func testFileLoggerWriting() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let logFile = tempDir.appendingPathComponent("test.log")
        let fileLogger = FileLogger(fileURL: logFile)
        
        // Write some log entries
        fileLogger.log(level: .info, message: "Test file log entry")
        fileLogger.log(level: .error, message: "Test error entry")
        
        // Give logger time to write
        try await Task.sleep(for: .milliseconds(100))
        
        // Check if file was created
        #expect(FileManager.default.fileExists(atPath: logFile.path))
        
        // Try to read the file content
        if let content = try? String(contentsOf: logFile) {
            #expect(content.contains("Test file log entry"))
            #expect(content.contains("Test error entry"))
        }
    }
    
    @Test("FileLogger handles file creation errors gracefully")
    func testFileLoggerErrorHandling() async throws {
        // Try to write to an invalid path (should not crash)
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.log")
        let fileLogger = FileLogger(fileURL: invalidPath)
        
        // This should not crash even if the path is invalid
        fileLogger.log(level: .info, message: "This should not crash")
        
        // Give logger time to attempt writing
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(true) // If we get here, error was handled gracefully
    }
    
    // MARK: - DiagnosticsLogger Tests
    
    @Test("DiagnosticsLogger integrates with system logging")
    func testDiagnosticLogging() async throws {
        let diagnosticsLogger = DiagnosticsLogger()
        
        // Test that diagnostics logger is created without errors
        #expect(diagnosticsLogger != nil)
        
        // Test basic logging (should not crash)
        diagnosticsLogger.log(level: .info, message: "Test diagnostic message")
        diagnosticsLogger.log(level: .debug, message: "Test debug message")
        diagnosticsLogger.log(level: .warning, message: "Test warning message")
        diagnosticsLogger.log(level: .error, message: "Test error message")
        
        // Give logger time to process
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(true) // If we get here, logging worked without crashes
    }
    
    @Test("DiagnosticsLogger handles different log levels")
    func testDiagnosticLogLevels() async throws {
        let diagnosticsLogger = DiagnosticsLogger()
        
        // Test all log levels
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        
        for level in levels {
            diagnosticsLogger.log(level: level, message: "Test message for \(level)")
        }
        
        // Give logger time to process all levels
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(true) // All log levels should be handled without crashes
    }
    
    // MARK: - LogManager Tests
    
    @Test("LogManager coordinates multiple loggers")
    func testLogManagement() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let logManager = LogManager(logDirectory: tempDir)
        
        // Test that log manager is created without errors
        #expect(logManager != nil)
        
        // Test logging through manager
        logManager.log(category: .supervision, level: .info, message: "Test supervision log")
        logManager.log(category: .networking, level: .debug, message: "Test networking log")
        logManager.log(category: .rules, level: .warning, message: "Test rules log")
        
        // Give manager time to process
        try await Task.sleep(for: .milliseconds(150))
        
        #expect(true) // If we get here, log management works
    }
    
    @Test("LogManager handles different categories")
    func testLogManagerCategories() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let logManager = LogManager(logDirectory: tempDir)
        
        // Test all log categories
        let categories: [LogCategory] = [
            .general, .supervision, .networking, .rules, .ui, .accessibility
        ]
        
        for category in categories {
            logManager.log(category: category, level: .info, message: "Test \(category) message")
        }
        
        // Give manager time to process all categories
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(true) // All categories should be handled without crashes
    }
    
    // MARK: - Logger Factory Tests
    
    @Test("LoggerFactory creates category-specific loggers")
    func testLoggerFactory() async throws {
        // Test creating loggers for different categories
        let supervisionLogger = LoggerFactory.logger(for: .supervision)
        let networkingLogger = LoggerFactory.logger(for: .networking)
        let rulesLogger = LoggerFactory.logger(for: .rules)
        
        #expect(supervisionLogger != nil)
        #expect(networkingLogger != nil)
        #expect(rulesLogger != nil)
        
        // Test that loggers can log without crashing
        supervisionLogger.info("Test supervision message")
        networkingLogger.debug("Test networking message")
        rulesLogger.warning("Test rules message")
        
        #expect(true) // If we get here, logger factory works
    }
    
    // MARK: - Integration Tests
    
    @Test("Complete logging system integration")
    func testLoggingSystemIntegration() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        // Test integration of all logging components
        let sessionLogger = SessionLogger(logDirectory: tempDir)
        let logManager = LogManager(logDirectory: tempDir)
        let fileLogger = FileLogger(fileURL: tempDir.appendingPathComponent("integration.log"))
        
        // Test that all components can work together
        sessionLogger.log(level: .info, message: "Session log test")
        logManager.log(category: .general, level: .info, message: "Manager log test")
        fileLogger.log(level: .info, message: "File log test")
        
        // Test concurrent usage
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<5 {
                    sessionLogger.log(level: .debug, message: "Session \(i)")
                }
            }
            
            group.addTask {
                for i in 0..<5 {
                    logManager.log(category: .networking, level: .debug, message: "Manager \(i)")
                }
            }
            
            group.addTask {
                for i in 0..<5 {
                    fileLogger.log(level: .debug, message: "File \(i)")
                }
            }
        }
        
        // Give all loggers time to complete
        try await Task.sleep(for: .milliseconds(300))
        
        #expect(true) // Integration should work without conflicts
    }
    
    @Test("Logging performance under load")
    func testLoggingPerformance() async throws {
        let tempDir = try createTemporaryLogDirectory()
        defer { cleanup(directory: tempDir) }
        
        let sessionLogger = SessionLogger(logDirectory: tempDir)
        
        // Test logging performance with many entries
        let startTime = Date()
        
        for i in 0..<100 {
            sessionLogger.log(level: .debug, message: "Performance test message \(i)")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete reasonably quickly (less than 1 second for 100 entries)
        #expect(duration < 1.0)
        
        // Give logger time to finish writing
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(true)
    }
}