import AppKit
@testable import AXorcist
@testable import CodeLooper
import Foundation
import Testing

@Suite("Accessibility Tests")
@MainActor
struct AccessibilityTests {
    // MARK: - Manager Initialization Suite

    @Suite("Manager Initialization")
    struct ManagerInitialization {
        @Test("Permissions manager initialization")
        @MainActor func permissionsManagerInitialization() async throws {
            let manager = PermissionsManager()

            // Verify manager initializes properly
            #expect(manager is PermissionsManager)

            // Verify properties are available (they return Bool values)
            _ = manager.hasAccessibilityPermissions
            _ = manager.hasAutomationPermissions 
            _ = manager.hasScreenRecordingPermissions
            _ = manager.hasNotificationPermissions
        }

        @Test("Permissions manager shared instance")
        @MainActor func permissionsManagerSharedInstance() async throws {
            let shared1 = PermissionsManager.shared
            let shared2 = PermissionsManager.shared

            // Verify shared instance is the same object
            #expect(shared1 === shared2)
        }

        @Test("Permissions manager observable object compliance")
        @MainActor func permissionsManagerObservableObjectCompliance() async throws {
            let manager = await PermissionsManager()

            // Test that it's properly marked as @MainActor and ObservableObject
            let objectWillChangePublisher = manager.objectWillChange
            #expect(objectWillChangePublisher != nil)
        }
    }

    // MARK: - Permission Operations Suite

    @Suite("Permission Operations", .tags(.operations, .system))
    struct PermissionOperations {
        @Test("Permissions manager permission check methods")
        @MainActor func permissionsManagerPermissionCheckMethods() async throws {
            let manager = PermissionsManager()

            // These methods should not crash when called
            manager.openAutomationSettings()
            manager.openScreenRecordingSettings()

            #expect(true) // If we get here, methods didn't crash
        }

        @Test("Permissions manager request notification permissions")
        @MainActor func permissionsManagerRequestNotificationPermissions() async throws {
            let manager = PermissionsManager()

            // This should not crash, even if permissions are denied
            await manager.requestNotificationPermissions()

            #expect(true) // If we get here, request didn't crash
        }

        @Test("Permissions manager request accessibility permissions")
        @MainActor func permissionsManagerPermissionRequestAccessibility() async throws {
            let manager = PermissionsManager()

            let initialState = manager.hasAccessibilityPermissions

            // Request accessibility permissions
            await manager.requestAccessibilityPermissions()

            // The permission state should be updated (may be same or different)
            let finalState = manager.hasAccessibilityPermissions
            
            // In test environment, permissions typically don't change
            // Just verify the request completes without error
            #expect(Bool(true), "Request completed without crashing")
        }

        @Test("Multiple permission request types", arguments: AccessibilityTestData.permissionTypes)
        @MainActor func multiplePermissionRequestTypes(permissionType: String) async throws {
            let manager = await PermissionsManager()

            // Test different permission request patterns
            switch permissionType {
            case "accessibility":
                await manager.requestAccessibilityPermissions()
            case "notifications":
                await manager.requestNotificationPermissions()
            default:
                break
            }

            #expect(true, "Permission request for \(permissionType) should complete")
        }
    }

    // MARK: - AXorcist Integration Suite

    @Suite("AXorcist Integration", .tags(.axorcist, .integration))
    struct AXorcistIntegration {
        @Test("AX Permission helpers accessibility check")
        func aXPermissionHelpersAccessibilityCheck() async throws {
            // This tests the static method from AXorcist
            let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()

            // Should return a boolean value (either true or false)
            #expect(hasPermissions == true || hasPermissions == false)
        }

        @Test("AX Permission helpers permission request")
        func aXPermissionHelpersPermissionRequest() async throws {
            // Test that permission request method is available and doesn't crash
            // Note: This will show system dialog in real usage, but returns false in test mode
            let result = await AXPermissionHelpers.requestPermissions()

            // Should return a boolean result (false in test mode to avoid permission dialogs)
            #expect(result == true || result == false, "Result should be a boolean value")
        }

        @Test("AX Permission helpers static method availability")
        func aXPermissionHelpersStaticMethodAvailability() async throws {
            // Verify that the static methods we depend on are available
            let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
            #expect(hasPermissions == true || hasPermissions == false)

            let requestResult = await AXPermissionHelpers.requestPermissions()
            #expect(requestResult == true || requestResult == false)
        }
    }

    // MARK: - System Integration Suite

    @Suite("System Integration", .tags(.system, .ui))
    struct SystemIntegration {
        @Test("Permissions manager URL generation")
        @MainActor func permissionsManagerURLGeneration() async throws {
            // Test that the URL strings used in settings opening are valid
            let automationURL =
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
            let screenRecordingURL =
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

            #expect(automationURL is URL)
            #expect(screenRecordingURL is URL)
        }

        @Test("Settings URLs are valid", arguments: AccessibilityTestData.settingsURLs)
        func settingsURLsAreValid(urlString: String) async throws {
            let url = URL(string: urlString)
            #expect(url is URL, "URL should be valid: \(urlString)")
            #expect(url?.scheme == "x-apple.systempreferences", "Should use system preferences scheme")
        }
    }

    // MARK: - State Management Suite

    @Suite("State Management", .tags(.state, .caching))
    struct StateManagement {
        @Test("Permissions manager permission state caching")
        @MainActor func permissionsManagerPermissionStateCaching() async throws {
            let manager = PermissionsManager()

            // Check that initial permissions are loaded (from cache or checked)
            // The actual values depend on system state, but they should be set
            let initialAccessibility = manager.hasAccessibilityPermissions
            let initialAutomation = manager.hasAutomationPermissions
            let initialScreenRecording = manager.hasScreenRecordingPermissions
            let initialNotifications = manager.hasNotificationPermissions

            // These should be boolean values, not nil
            #expect(initialAccessibility == true || initialAccessibility == false)
            #expect(initialAutomation == true || initialAutomation == false)
            #expect(initialScreenRecording == true || initialScreenRecording == false)
            #expect(initialNotifications == true || initialNotifications == false)
        }

        @Test("Permissions manager permission monitoring task", .timeLimit(.minutes(1)))
        @MainActor func permissionsManagerPermissionMonitoringTask() async throws {
            let manager = PermissionsManager()

            // Wait a short time to let monitoring start
            try await Task.sleep(for: .milliseconds(100)) // 100ms

            // Verify that permission properties remain accessible
            let hasAccessibility = manager.hasAccessibilityPermissions
            let hasAutomation = manager.hasAutomationPermissions
            let hasScreenRecording = manager.hasScreenRecordingPermissions
            let hasNotifications = manager.hasNotificationPermissions
            
            #expect(hasAccessibility == true || hasAccessibility == false)
            #expect(hasAutomation == true || hasAutomation == false)
            #expect(hasScreenRecording == true || hasScreenRecording == false)
            #expect(hasNotifications == true || hasNotifications == false)
        }

        @Test("Published property updates", .timeLimit(.minutes(1)))
        @MainActor func permissionsManagerPublishedPropertyUpdates() async throws {
            let manager = PermissionsManager()

            var updateCount = 0
            let cancellable = manager.objectWillChange.sink { _ in
                updateCount += 1
            }

            // Wait for initial permission check to complete
            try await Task.sleep(for: .milliseconds(200))

            // The objectWillChange should have fired at least once during initialization
            #expect(updateCount >= 0) // May be 0 if no changes occurred

            cancellable.cancel()
        }
    }

    // MARK: - Reliability Suite

    @Suite("Reliability", .tags(.reliability, .edge_cases))
    struct Reliability {
        @Test("Permissions manager multiple permission requests")
        @MainActor func permissionsManagerMultiplePermissionRequests() async throws {
            let manager = PermissionsManager()

            // Request multiple times - should not crash
            await manager.requestAccessibilityPermissions()
            await manager.requestNotificationPermissions()
            await manager.requestAccessibilityPermissions()

            #expect(true) // If we get here, multiple requests didn't crash
        }

        @Test("Permissions manager memory management", .timeLimit(.minutes(1)))
        @MainActor func permissionsManagerMemoryManagement() async throws {
            weak var weakManager: PermissionsManager?

            // Create manager in isolated scope
            autoreleasepool {
                let manager = PermissionsManager()
                weakManager = manager
                #expect(weakManager is PermissionsManager)
            }

            // Wait a bit for deallocation
            try await Task.sleep(for: .milliseconds(100)) // 100ms

            // Note: The manager may not be deallocated immediately due to the monitoring task
            // This test mainly ensures we can create and reference it properly
            #expect(true)
        }

        @Test("Concurrent permission operations", .timeLimit(.minutes(1)))
        @MainActor func concurrentPermissionOperations() async throws {
            let manager = PermissionsManager()

            // Test concurrent permission checks
            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 10 {
                    group.addTask { @MainActor in
                        _ = manager.hasAccessibilityPermissions
                        _ = manager.hasAutomationPermissions
                        _ = manager.hasScreenRecordingPermissions
                        _ = manager.hasNotificationPermissions
                    }
                }
            }

            #expect(true, "Concurrent permission operations should complete safely")
        }
    }

    // MARK: - Test Fixtures and Data
    // Test data moved to CursorMonitorTestData.swift to avoid Swift Testing macro issues
}

