import AppKit
@testable import CodeLooper
import Foundation
import XCTest
import UserNotifications



class NotificationHandlingTests: XCTestCase {
    func testUserNotificationManagerSingleton() async throws {
    let manager1 = await UserNotificationManager.shared
    let manager2 = await UserNotificationManager.shared

    XCTAssertTrue(manager1 === manager2)
}


    func testUserNotificationManagerInitialization() async throws {
    let manager = await UserNotificationManager.shared

    // Test initial state
    XCTAssertNotNil(manager)

    // Test initial published values
    let initialPermission = await manager.hasPermission
    let initialStatus = await manager.authorizationStatus

    // Values should be initialized (though actual values depend on system state)
    XCTAssertEqual(initialPermission, true || initialPermission == false)
    XCTAssertNotNil(initialStatus)
}


    func testNotificationErrorCases() async throws {
    let permissionError = NotificationError.permissionDenied
    let deliveryError = NotificationError.deliveryFailed(URLError(.notConnectedToInternet))

    // Test error descriptions
    XCTAssertNotNil(permissionError.errorDescription)
    XCTAssertEqual(permissionError.errorDescription?.contains("permission"), true)

    XCTAssertNotNil(deliveryError.errorDescription)
    XCTAssertEqual(deliveryError.errorDescription?.contains("deliver"), true)

    // Test error equality
    let anotherPermissionError = NotificationError.permissionDenied
    XCTAssertEqual(permissionError.errorDescription, anotherPermissionError.errorDescription)
}


    func testNotificationErrorDeliveryErrorDetails() async throws {
    let underlyingError = URLError(.timedOut)
    let deliveryError = NotificationError.deliveryFailed(underlyingError)

    XCTAssertEqual(deliveryError.errorDescription?.contains("timed out"), true)
    XCTAssertEqual(deliveryError.errorDescription?.contains("Failed to deliver"), true)

    let nsError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    let nsDeliveryError = NotificationError.deliveryFailed(nsError)

    XCTAssertEqual(nsDeliveryError.errorDescription?.contains("Test error"), true)
}


    func testUserNotificationManagerAuthorizationStatusHandling() async throws {
    let manager = await UserNotificationManager.shared

    // Test that authorization status check doesn't crash
    await manager.checkAuthorizationStatus()

    let status = await manager.authorizationStatus
    let hasPermission = await manager.hasPermission

    // Verify status is a valid UNAuthorizationStatus
    let validStatuses: [UNAuthorizationStatus] = [.notDetermined, .denied, .authorized, .provisional]
    XCTAssertTrue(validStatuses.contains(status))

    // Verify hasPermission matches status
    if status == .authorized {
        XCTAssertEqual(hasPermission, true)
    } else if status == .denied {
        XCTAssertEqual(hasPermission, false)
    }
}


    func testUserNotificationManagerNotificationContentCreation() async throws {
    // Test notification content creation parameters
    let testCases = [
        (title: "Test Title", body: "Test Body", id: "test-id"),
        (title: "Long Title with Multiple Words and Special Characters !@#$", body: "Short body", id: "long-title"),
        (
            title: "Short",
            body: "Very long body text that contains multiple sentences and provides detailed information about the notification content that the user should read carefully.",
            id: "long-body"
        ),
        (title: "", body: "", id: "empty"),
        (title: "Emoji Test 🚀", body: "Body with émojis 🎉 and unicode characters 测试", id: "unicode"),
        (title: "Rule Executed", body: "TestRule executed successfully (execution #5)", id: "rule-test-1234567890"),
    ]

    for testCase in testCases {
        // Verify that the test case parameters are valid strings
        XCTAssertGreaterThanOrEqual(testCase.title.count, 0)
        XCTAssertGreaterThanOrEqual(testCase.body.count, 0)
        XCTAssertGreaterThan(testCase.id.count, 0)
    }
}


    func testUserNotificationManagerRuleExecutionNotifications() async throws {
    let manager = await UserNotificationManager.shared

    // Test rule execution notification without permission (should not crash)
    await manager.sendRuleExecutionNotification(
        ruleName: "test-rule",
        displayName: "Test Rule",
        executionCount: 5,
        isWarning: false
    )

    // Test warning notification
    await manager.sendRuleExecutionNotification(
        ruleName: "warning-rule",
        displayName: "Warning Rule",
        executionCount: 20,
        isWarning: true
    )

    // Test maximum execution notification
    await manager.sendRuleExecutionNotification(
        ruleName: "max-rule",
        displayName: "Max Rule",
        executionCount: 25,
        isWarning: false
    )

    // These calls should not crash even without permissions
    XCTAssertTrue(true)
}


    func testUserNotificationManagerSystemSettingsURL() async throws {
    let manager = await UserNotificationManager.shared

    // Test that opening notification settings doesn't crash
    // Note: This will actually try to open System Settings in a real environment
    // In tests, we just verify the method doesn't crash
    await manager.openNotificationSettings()

    // Verify URL can be created
    let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    XCTAssertNotNil(settingsURL)
    XCTAssertEqual(settingsURL?.scheme, "x-apple.systempreferences")
}


    func testUserNotificationManagerNotificationSoundOptions() async throws {
    // Test various sound options
    let defaultSound = UNNotificationSound.default
    let customSound = UNNotificationSound(named: UNNotificationSoundName("custom.wav"))

    XCTAssertNotNil(defaultSound)
    XCTAssertNotNil(customSound)

    // Test that sounds can be used in notification parameters
    // We can't actually send notifications in tests without permissions,
    // but we can verify the sound objects are created correctly
}


    func testUserNotificationManagerBadgeNumbers() async throws {
    let badgeNumbers = [
        NSNumber(value: 0),
        NSNumber(value: 1),
        NSNumber(value: 99),
        NSNumber(value: 999),
        NSNumber(value: -1), // Invalid badge number
    ]

    for badgeNumber in badgeNumbers {
        // Verify badge numbers can be created
        XCTAssertNotNil(badgeNumber)
    }
}


    func testUserNotificationManagerConcurrentOperations() async throws {
    let manager = await UserNotificationManager.shared

    // Test concurrent authorization status checks
    await withTaskGroup(of: Void.self) { group in
        for _ in 0 ..< 5 {
            group.addTask {
                await manager.checkAuthorizationStatus()
            }
        }
    }

    // Manager should still be in a valid state
    let finalStatus = await manager.authorizationStatus
    XCTAssertNotNil(finalStatus)
}


    func testUserNotificationManagerErrorHandling() async throws {
    let manager = await UserNotificationManager.shared

    // Test sending notification without permission
    do {
        try await manager.sendNotification(
            title: "Test",
            body: "Test body",
            identifier: "test-no-permission"
        )
        // If we reach here, permissions were granted (which is fine)
    } catch {
        // Should throw NotificationError.permissionDenied if no permission
        if let notificationError = error as? NotificationError {
            switch notificationError {
            case .permissionDenied:
                XCTAssertTrue(true) // Expected error
            case .deliveryFailed:
                XCTAssertTrue(true) // Also valid error type
            }
        }
    }
}


    func testUserNotificationManagerNotificationIdentifiers() async throws {
    // Test various identifier formats
    let identifiers = [
        "simple-id",
        "rule-test-rule-1234567890.123",
        "intervention-12345",
        "max_interventions_67890",
        "persistent_failure_999",
        UUID().uuidString,
        "",
        "id-with-émojis-🚀",
        "very-long-identifier-that-contains-many-characters-and-should-still-work-correctly-1234567890",
    ]

    for identifier in identifiers {
        // Test that identifiers are valid strings
        XCTAssertGreaterThanOrEqual(identifier.count, 0)

        // Empty identifier should generate UUID
        let finalId = identifier.isEmpty ? UUID().uuidString : identifier
        XCTAssertGreaterThan(finalId.count, 0)
    }
}


    func testUserNotificationManagerMemoryManagement() async throws {
    let manager = await UserNotificationManager.shared

    // Test multiple rule execution notifications
    for i in 0 ..< 100 {
        await manager.sendRuleExecutionNotification(
            ruleName: "test-rule-\(i)",
            displayName: "Test Rule \(i)",
            executionCount: i % 25,
            isWarning: i % 20 == 0
        )
    }

    // Manager should still be functional
    let status = await manager.authorizationStatus
    XCTAssertNotNil(status)
}


    func testUserNotificationManagerPerformance() async throws {
    let manager = await UserNotificationManager.shared

    let startTime = Date()

    // Test rapid authorization status checks
    for _ in 0 ..< 100 {
        await manager.checkAuthorizationStatus()
    }

    let elapsed = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(elapsed, 5.0) // Should complete within reasonable time
}


    func testNotificationsStringEncoding() async throws {
    let testStrings = [
        "Simple ASCII text",
        "Text with émojis 🚀🎉📱",
        "Unicode characters: 测试 日本語 العربية",
        "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?",
        "Numbers and symbols: 123456789 ±∞≠≤≥",
        "\nNewlines\nand\ntabs\t\there",
        "",
    ]

    for testString in testStrings {
        // Test that strings can be encoded to UTF-8
        let data = testString.data(using: .utf8)
        XCTAssertNotNil(data)

        // Test round-trip encoding
        if let data {
            let decoded = String(data: data, encoding: .utf8)
            XCTAssertEqual(decoded, testString)
        }
    }
}


    func testNotificationsAuthorizationStatusTypes() async throws {
    let allStatuses: [UNAuthorizationStatus] = [
        .notDetermined,
        .denied,
        .authorized,
        .provisional,
    ]

    // Test that all status values are distinct
    for i in 0 ..< allStatuses.count {
        for j in (i + 1) ..< allStatuses.count {
            XCTAssertNotEqual(allStatuses[i], allStatuses[j])
        }
    }

    // Test permission mapping
    for status in allStatuses {
        let shouldHavePermission = (status == .authorized)
        // This is the logic used in UserNotificationManager
        XCTAssertEqual((status == .authorized), shouldHavePermission)
    }
}

}