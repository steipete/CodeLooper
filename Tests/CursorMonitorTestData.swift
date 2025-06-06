import Foundation
@testable import CodeLooper

// MARK: - Test Data
// Separate enum to hold test data to avoid Swift Testing macro expansion issues

enum CursorMonitorTestData {
    static let testAppConfigurations: [(id: Int, name: String, status: DisplayStatus)] = [
        (12345, "Test Cursor", .active),
        (54321, "Cursor Preview", .idle),
        (98765, "Development Cursor", .positiveWork),
        (11111, "Production Cursor", .active),
        (22222, "Debug Cursor", .notRunning)
    ]
    
    static let performanceTestSizes: [Int] = [1, 10, 50, 100, 500]
    
    static let windowCountMatrix: [(appCount: Int, windowsPerApp: Int)] = [
        (1, 1),
        (5, 3),
        (10, 5),
        (20, 10)
    ]
    
    static let testAppIds: [Int] = [12345, 54321, 98765, 11111, 22222]
    
    static let testDisplayNames: [String] = ["Test Cursor", "Cursor Preview", "Development Cursor", "Production Cursor", "Debug Cursor"]
}

// Test data for other test files
enum AccessibilityTestData {
    static let permissionTypes = ["accessibility", "automation", "screen_recording", "notifications"]
    
    static let settingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
    ]
}

enum DebouncerTestData {
    static let shortDelays: [TimeInterval] = [0.01, 0.05, 0.1]
    static let mediumDelays: [TimeInterval] = [0.2, 0.5, 1.0]
}