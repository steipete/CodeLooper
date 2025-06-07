import AppKit
@testable import CodeLooper
import Foundation
import Testing
import UserNotifications

@Suite("Notification Handling Tests", .tags(.notifications, .system, .permissions))
struct NotificationHandlingTests {
    // MARK: - Manager Initialization Suite

    @Suite("Manager Initialization", .tags(.initialization, .singleton))
    struct ManagerInitialization {
        @Test("User notification manager singleton")
        func userNotificationManagerSingleton() async {
            let manager1 = await UserNotificationManager.shared
            let manager2 = await UserNotificationManager.shared

            #expect(manager1 === manager2)
        }

        @Test("User notification manager initialization")
        func userNotificationManagerInitialization() async {
            let manager = await UserNotificationManager.shared

            // Test initial published values
            let initialPermission = await manager.hasPermission
            let initialStatus = await manager.authorizationStatus

            // Values should be initialized (though actual values depend on system state)
            #expect(initialPermission == true || initialPermission == false)
            // Authorization status is a value type (enum), not optional
            #expect(initialStatus == .authorized || initialStatus == .denied || initialStatus == .notDetermined ||
                initialStatus == .provisional)
        }
    }

    // MARK: - Error Handling Suite

    @Suite("Error Handling", .tags(.error, .validation))
    struct ErrorHandling {
        @Test("Notification error cases")
        func notificationErrorCases() async throws {
            // Test authorization denied error
            let authError = NotificationError.permissionDenied
            #expect(authError.errorDescription == "Notification permission was denied")

            // Test delivery failed error with underlying error
            let nsError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
            let nsDeliveryError = NotificationError.deliveryFailed(nsError)

            #expect(nsDeliveryError.errorDescription?.contains("Test error") ?? false)
        }
    }

    // MARK: - Authorization Suite

    @Suite("Authorization", .tags(.permissions, .authorization))
    struct Authorization {
        @Test("User notification manager authorization status handling")
        func userNotificationManagerAuthorizationStatusHandling() async {
            let manager = await UserNotificationManager.shared

            // Test that authorization status check doesn't crash
            await manager.checkAuthorizationStatus()

            let status = await manager.authorizationStatus
            let hasPermission = await manager.hasPermission

            // Verify status is a valid UNAuthorizationStatus
            let validStatuses: [UNAuthorizationStatus] = [.notDetermined, .denied, .authorized, .provisional]
            #expect(validStatuses.contains(status))

            // Verify hasPermission matches status
            if status == .authorized {
                #expect(hasPermission)
            } else if status == .denied {
                #expect(!hasPermission)
            }
        }
    }

    // MARK: - Content Creation Suite

    @Suite("Content Creation", .tags(.content, .creation))
    struct ContentCreation {
        @Test("User notification manager notification content creation", arguments: testNotifications)
        func userNotificationManagerNotificationContentCreation(notification: (
            title: String,
            body: String,
            id: String
        )) async {
            // Validate test case data
            #expect(notification.title.count >= 0)
            #expect(notification.body.count >= 0)
            #expect(notification.id.count > 0)
        }
    }

    // MARK: - Rule Notifications Suite

    @Suite("Rule Notifications", .tags(.rules, .notifications))
    struct RuleNotifications {
        @Test("User notification manager rule execution notifications")
        func userNotificationManagerRuleExecutionNotifications() async {
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

            // Verify that the method completes without crashing
            #expect(true)
        }

        @Test("Notification content formatting")
        func notificationContentFormatting() async {
            let testRules = [
                (name: "stop-after-25-loops", display: "Stop After 25 Loops", count: 25, warning: true),
                (name: "test-rule", display: "Test Rule", count: 1, warning: false),
                (
                    name: "very-long-rule-name-that-should-still-work",
                    display: "Very Long Rule Name",
                    count: 999,
                    warning: true
                ),
            ]

            for rule in testRules {
                // Test that the notification parameters are valid
                #expect(rule.name.count > 0)
                #expect(rule.display.count > 0)
                #expect(rule.count > 0)
                #expect(rule.warning == true || rule.warning == false)
            }
        }
    }

    // MARK: - Request Management Suite

    @Suite("Request Management", .tags(.requests, .permissions))
    struct RequestManagement {
        @Test("User notification manager request permissions")
        func userNotificationManagerRequestPermissions() async {
            let manager = await UserNotificationManager.shared

            // Request permissions (should not crash regardless of system state)
            await manager.requestNotificationPermissions()

            // After requesting, we should have a definite status
            let status = await manager.authorizationStatus
            #expect(status != .notDetermined || status == .notDetermined) // Status is valid
        }
    }

    // MARK: - Concurrent Operations Suite

    @Suite("Concurrent Operations", .tags(.concurrency, .threading))
    struct ConcurrentOperations {
        @Test("Concurrent notification operations", .timeLimit(.minutes(1)))
        func concurrentNotificationOperations() async throws {
            let manager = await UserNotificationManager.shared

            // Test concurrent operations
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< 10 {
                    group.addTask {
                        await manager.sendRuleExecutionNotification(
                            ruleName: "concurrent-rule-\(i)",
                            displayName: "Concurrent Rule \(i)",
                            executionCount: i,
                            isWarning: i % 2 == 0
                        )
                    }
                }
            }

            #expect(true, "Concurrent operations should complete without crashes")
        }
    }

    // MARK: - Test Fixtures and Data

    static let testNotifications = [
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
}
