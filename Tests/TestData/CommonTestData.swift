import Foundation
@testable import CodeLooper

// MARK: - Common Test Data

/// Centralized test data to avoid Swift Testing macro processing issues
/// and to maintain DRY principles across test suites
enum CommonTestData {
    
    // MARK: - Debouncer Test Data
    
    enum DebouncerTestData {
        static let shortDelays: [TimeInterval] = [0.01, 0.02, 0.05]
        static let mediumDelays: [TimeInterval] = [0.1, 0.2, 0.3]
        static let longDelays: [TimeInterval] = [0.5, 1.0, 2.0]
        
        static let stressTestConfigurations = [
            (callCount: 100, delay: 0.01, expectedExecutions: 1),
            (callCount: 1000, delay: 0.001, expectedExecutions: 1),
            (callCount: 10, delay: 0.1, expectedExecutions: 1)
        ]
    }
    
    // MARK: - Cursor Monitor Test Data
    
    enum CursorMonitorTestData {
        static let testAppConfigurations = [
            (id: 1, displayName: "Cursor 1", status: DisplayStatus.active, windows: 2),
            (id: 2, displayName: "Cursor 2", status: DisplayStatus.idle, windows: 0),
            (id: 3, displayName: "Cursor 3", status: DisplayStatus.intervening, windows: 5)
        ]
        
        static let stateTransitions = [
            (from: DisplayStatus.idle, to: DisplayStatus.active, valid: true),
            (from: DisplayStatus.active, to: DisplayStatus.intervening, valid: true),
            (from: DisplayStatus.intervening, to: DisplayStatus.idle, valid: true),
            (from: DisplayStatus.idle, to: DisplayStatus.intervening, valid: false)
        ]
        
        static let interventionScenarios = [
            (type: RecoveryType.connection, priority: 80, category: "network"),
            (type: .stuck, priority: 70, category: "ui"),
            (type: .stopGenerating, priority: 60, category: "action"),
            (type: .forceStop, priority: 90, category: "critical")
        ]
    }
    
    // MARK: - AI Service Test Data
    
    enum AIServiceTestData {
        static let modelConfigurations = [
            (model: AIModel.gpt4o, provider: AIProvider.openAI, supportsVision: true),
            (model: .gpt4TurboVision, provider: .openAI, supportsVision: true),
            (model: .llava, provider: .ollama, supportsVision: true),
            (model: .bakllava, provider: .ollama, supportsVision: true)
        ]
        
        static let errorScenarios = [
            (error: AIServiceError.apiKeyMissing, recoverable: true),
            (error: .invalidImage, recoverable: false),
            (error: .serviceUnavailable, recoverable: true),
            (error: .networkError(URLError(.notConnectedToInternet)), recoverable: true)
        ]
        
        static let imageSizes = [
            (width: 64, height: 64, category: "thumbnail"),
            (width: 256, height: 256, category: "small"),
            (width: 512, height: 512, category: "medium"),
            (width: 1024, height: 768, category: "large"),
            (width: 2048, height: 1536, category: "xlarge")
        ]
    }
    
    // MARK: - String Test Data
    
    enum StringTestData {
        static let edgeCaseStrings = [
            "",
            " ",
            "\n",
            "\t",
            "Hello World",
            "Special chars: !@#$%^&*()",
            "Unicode: 🚀 📱 💻 测试 العربية",
            String(repeating: "a", count: 1000),
            "Line\nBreaks\nTest",
            "Quotes: \"double\" and 'single'",
            "Path: /Users/test/file.txt",
            "URL: https://example.com/path?query=value"
        ]
        
        static let pathStrings = [
            "/Users/test/project",
            "/home/user/workspace",
            "~/Documents/Projects",
            "./relative/path",
            "../parent/path",
            "/",
            "",
            "C:\\Windows\\Path" // Windows path
        ]
    }
    
    // MARK: - Performance Test Data
    
    enum PerformanceTestData {
        static let loadConfigurations = [
            (operations: 100, threads: 1, expectedThroughput: 1000.0),
            (operations: 1000, threads: 4, expectedThroughput: 4000.0),
            (operations: 10000, threads: 8, expectedThroughput: 8000.0)
        ]
        
        static let memoryTestSizes = [100, 1000, 10000, 100000]
        
        static let timeoutConfigurations = [
            (operation: "quick", timeout: Duration.milliseconds(100)),
            (operation: "normal", timeout: Duration.seconds(1)),
            (operation: "slow", timeout: Duration.seconds(10)),
            (operation: "very_slow", timeout: Duration.seconds(60))
        ]
    }
    
    // MARK: - Mock Data Generators
    
    enum MockDataGenerators {
        static func randomString(length: Int) -> String {
            let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            return String((0..<length).map { _ in letters.randomElement()! })
        }
        
        static func randomEmail() -> String {
            "\(randomString(length: 8))@test.com"
        }
        
        static func randomURL() -> URL {
            URL(string: "https://test.com/\(randomString(length: 10))")!
        }
        
        static func randomDate(daysFromNow: Int = 0) -> Date {
            Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        }
    }
}

// MARK: - Test Fixtures

enum TestFixtures {
    static func createMockUser(
        id: String = UUID().uuidString,
        name: String = "Test User",
        email: String? = nil
    ) -> MockUser {
        MockUser(
            id: id,
            name: name,
            email: email ?? CommonTestData.MockDataGenerators.randomEmail()
        )
    }
    
    struct MockUser: Sendable {
        let id: String
        let name: String
        let email: String
    }
}