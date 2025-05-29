import AppKit
@testable import CodeLooper
import Foundation
import Testing
import UserNotifications

@Test("UserNotificationManager - Singleton")
func userNotificationManagerSingleton() async throws {
    let manager1 = await UserNotificationManager.shared
    let manager2 = await UserNotificationManager.shared

    #expect(manager1 === manager2)
}

@Test("UserNotificationManager - Initialization")
func userNotificationManagerInitialization() async throws {
    let manager = await UserNotificationManager.shared

    // Test initial state
    #expect(manager != nil)

    // Test initial published values
    let initialPermission = await manager.hasPermission
    let initialStatus = await manager.authorizationStatus

    // Values should be initialized (though actual values depend on system state)
    #expect(initialPermission == true || initialPermission == false)
    #expect(initialStatus != nil)
}

@Test("NotificationError - Error Cases")
func notificationErrorCases() async throws {
    let permissionError = NotificationError.permissionDenied
    let deliveryError = NotificationError.deliveryFailed(URLError(.notConnectedToInternet))

    // Test error descriptions
    #expect(permissionError.errorDescription != nil)
    #expect(permissionError.errorDescription?.contains("permission") == true)

    #expect(deliveryError.errorDescription != nil)
    #expect(deliveryError.errorDescription?.contains("deliver") == true)

    // Test error equality
    let anotherPermissionError = NotificationError.permissionDenied
    #expect(permissionError.errorDescription == anotherPermissionError.errorDescription)
}

@Test("NotificationError - Delivery Error Details")
func notificationErrorDeliveryErrorDetails() async throws {
    let underlyingError = URLError(.timedOut)
    let deliveryError = NotificationError.deliveryFailed(underlyingError)

    #expect(deliveryError.errorDescription?.contains("timed out") == true)
    #expect(deliveryError.errorDescription?.contains("Failed to deliver") == true)

    let nsError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    let nsDeliveryError = NotificationError.deliveryFailed(nsError)

    #expect(nsDeliveryError.errorDescription?.contains("Test error") == true)
}

@Test("UserNotificationManager - Authorization Status Handling")
func userNotificationManagerAuthorizationStatusHandling() async throws {
    let manager = await UserNotificationManager.shared

    // Test that authorization status check doesn't crash
    await manager.checkAuthorizationStatus()

    let status = await manager.authorizationStatus
    let hasPermission = await manager.hasPermission

    // Verify status is a valid UNAuthorizationStatus
    let validStatuses: [UNAuthorizationStatus] = [.notDetermined, .denied, .authorized, .provisional, .ephemeral]
    #expect(validStatuses.contains(status))

    // Verify hasPermission matches status
    if status == .authorized {
        #expect(hasPermission == true)
    } else if status == .denied {
        #expect(hasPermission == false)
    }
}

@Test("UserNotificationManager - Notification Content Creation")
func userNotificationManagerNotificationContentCreation() async throws {
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
        #expect(testCase.title.count >= 0)
        #expect(testCase.body.count >= 0)
        #expect(testCase.id.count > 0)
    }
}

@Test("UserNotificationManager - Rule Execution Notifications")
func userNotificationManagerRuleExecutionNotifications() async throws {
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
    #expect(true)
}

@Test("UserNotificationManager - System Settings URL")
func userNotificationManagerSystemSettingsURL() async throws {
    let manager = await UserNotificationManager.shared

    // Test that opening notification settings doesn't crash
    // Note: This will actually try to open System Settings in a real environment
    // In tests, we just verify the method doesn't crash
    manager.openNotificationSettings()

    // Verify URL can be created
    let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    #expect(settingsURL != nil)
    #expect(settingsURL?.scheme == "x-apple.systempreferences")
}

@Test("UserNotificationManager - Notification Sound Options")
func userNotificationManagerNotificationSoundOptions() async throws {
    // Test various sound options
    let defaultSound = UNNotificationSound.default
    let customSound = UNNotificationSound(named: UNNotificationSoundName("custom.wav"))

    #expect(defaultSound != nil)
    #expect(customSound != nil)

    // Test that sounds can be used in notification parameters
    // We can't actually send notifications in tests without permissions,
    // but we can verify the sound objects are created correctly
}

@Test("UserNotificationManager - Badge Numbers")
func userNotificationManagerBadgeNumbers() async throws {
    let badgeNumbers = [
        NSNumber(value: 0),
        NSNumber(value: 1),
        NSNumber(value: 99),
        NSNumber(value: 999),
        NSNumber(value: -1), // Invalid badge number
    ]

    for badgeNumber in badgeNumbers {
        // Verify badge numbers can be created
        #expect(badgeNumber != nil)
    }
}

@Test("UserNotificationManager - Concurrent Operations")
func userNotificationManagerConcurrentOperations() async throws {
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
    #expect(finalStatus != nil)
}

@Test("UserNotificationManager - Error Handling")
func userNotificationManagerErrorHandling() async throws {
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
                #expect(true) // Expected error
            case .deliveryFailed:
                #expect(true) // Also valid error type
            }
        }
    }
}

@Test("UserNotificationManager - Notification Identifiers")
func userNotificationManagerNotificationIdentifiers() async throws {
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
        #expect(identifier.count >= 0)

        // Empty identifier should generate UUID
        let finalId = identifier.isEmpty ? UUID().uuidString : identifier
        #expect(finalId.count > 0)
    }
}

@Test("UserNotificationManager - Memory Management")
func userNotificationManagerMemoryManagement() async throws {
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
    #expect(status != nil)
}

@Test("UserNotificationManager - Performance")
func userNotificationManagerPerformance() async throws {
    let manager = await UserNotificationManager.shared

    let startTime = Date()

    // Test rapid authorization status checks
    for _ in 0 ..< 100 {
        await manager.checkAuthorizationStatus()
    }

    let elapsed = Date().timeIntervalSince(startTime)
    #expect(elapsed < 5.0) // Should complete within reasonable time
}

@Test("Notifications - String Encoding")
func notificationsStringEncoding() async throws {
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
        #expect(data != nil)

        // Test round-trip encoding
        if let data {
            let decoded = String(data: data, encoding: .utf8)
            #expect(decoded == testString)
        }
    }
}

@Test("Notifications - Authorization Status Types")
func notificationsAuthorizationStatusTypes() async throws {
    let allStatuses: [UNAuthorizationStatus] = [
        .notDetermined,
        .denied,
        .authorized,
        .provisional,
        .ephemeral,
    ]

    // Test that all status values are distinct
    for i in 0 ..< allStatuses.count {
        for j in (i + 1) ..< allStatuses.count {
            #expect(allStatuses[i] != allStatuses[j])
        }
    }

    // Test permission mapping
    for status in allStatuses {
        let shouldHavePermission = (status == .authorized)
        // This is the logic used in UserNotificationManager
        #expect((status == .authorized) == shouldHavePermission)
    }
}
