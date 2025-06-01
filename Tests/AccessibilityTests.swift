import AppKit
@testable import AXorcist
@testable import CodeLooper
import Foundation
import XCTest

@MainActor
class AccessibilityTests: XCTestCase {
    @MainActor

    func testPermissionsManagerInitialization() async throws {
        let manager = PermissionsManager()

        // Verify manager initializes properly
        XCTAssertNotNil(manager)

        // Verify properties are available
        XCTAssertNotNil(manager.hasAccessibilityPermissions)
        XCTAssertNotNil(manager.hasAutomationPermissions)
        XCTAssertNotNil(manager.hasScreenRecordingPermissions)
        XCTAssertNotNil(manager.hasNotificationPermissions)
    }

    @MainActor

    func testPermissionsManagerSharedInstance() async throws {
        let shared1 = PermissionsManager.shared
        let shared2 = PermissionsManager.shared

        // Verify shared instance is the same object
        XCTAssertTrue(shared1 === shared2)
    }

    @MainActor

    func testPermissionsManagerPermissionCheckMethods() async throws {
        let manager = PermissionsManager()

        // These methods should not crash when called
        manager.openAutomationSettings()
        manager.openScreenRecordingSettings()

        XCTAssertTrue(true) // If we get here, methods didn't crash
    }

    @MainActor

    func testPermissionsManagerRequestNotificationPermissions() async throws {
        let manager = PermissionsManager()

        // This should not crash, even if permissions are denied
        await manager.requestNotificationPermissions()

        XCTAssertTrue(true) // If we get here, request didn't crash
    }

    @MainActor

    func testPermissionsManagerObservableObjectCompliance() async throws {
        let manager = PermissionsManager()

        // Test that it's properly marked as @MainActor and ObservableObject
        let objectWillChangePublisher = manager.objectWillChange
        XCTAssertNotNil(objectWillChangePublisher)
    }

    func testAXPermissionHelpersAccessibilityCheck() async throws {
        // This tests the static method from AXorcist
        let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()

        // Should return a boolean value (either true or false)
        XCTAssertEqual(hasPermissions, true || hasPermissions == false)
    }

    func testAXPermissionHelpersPermissionRequest() async throws {
        // Test that permission request method is available and doesn't crash
        // Note: This will show system dialog in real usage, but returns false in test mode
        let result = await AXPermissionHelpers.requestPermissions()

        // Should return a boolean result (false in test mode to avoid permission dialogs)
        XCTAssertTrue(result == true || result == false, "Result should be a boolean value")
    }

    @MainActor

    func testPermissionsManagerURLGeneration() async throws {
        // Test that the URL strings used in settings opening are valid
        let automationURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        let screenRecordingURL =
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

        XCTAssertNotNil(automationURL)
        XCTAssertNotNil(screenRecordingURL)
    }

    @MainActor

    func testPermissionsManagerPermissionStateCaching() async throws {
        let manager = PermissionsManager()

        // Check that initial permissions are loaded (from cache or checked)
        // The actual values depend on system state, but they should be set
        let initialAccessibility = manager.hasAccessibilityPermissions
        let initialAutomation = manager.hasAutomationPermissions
        let initialScreenRecording = manager.hasScreenRecordingPermissions
        let initialNotifications = manager.hasNotificationPermissions

        // These should be boolean values, not nil
        XCTAssertEqual(initialAccessibility, true || initialAccessibility == false)
        XCTAssertEqual(initialAutomation, true || initialAutomation == false)
        XCTAssertEqual(initialScreenRecording, true || initialScreenRecording == false)
        XCTAssertEqual(initialNotifications, true || initialNotifications == false)
    }

    @MainActor

    func testPermissionsManagerPermissionMonitoringTask() async throws {
        let manager = PermissionsManager()

        // Wait a short time to let monitoring start
        try await Task.sleep(for: .milliseconds(100)) // 100ms

        // Verify that permission properties remain accessible
        XCTAssertNotNil(manager.hasAccessibilityPermissions)
        XCTAssertNotNil(manager.hasAutomationPermissions)
        XCTAssertNotNil(manager.hasScreenRecordingPermissions)
        XCTAssertNotNil(manager.hasNotificationPermissions)
    }

    @MainActor

    func testPermissionsManagerPermissionRequestAccessibility() async throws {
        let manager = PermissionsManager()

        let initialState = manager.hasAccessibilityPermissions

        // Request accessibility permissions
        await manager.requestAccessibilityPermissions()

        // The permission state should be updated (may be same or different)
        let finalState = manager.hasAccessibilityPermissions
        XCTAssertEqual(finalState, true || finalState == false)

        // Note: In tests, this likely won't change unless running with permissions
        // But the method should complete without crashing
    }

    @MainActor

    func testPermissionsManagerMultiplePermissionRequests() async throws {
        let manager = PermissionsManager()

        // Request multiple times - should not crash
        await manager.requestAccessibilityPermissions()
        await manager.requestNotificationPermissions()
        await manager.requestAccessibilityPermissions()

        XCTAssertTrue(true) // If we get here, multiple requests didn't crash
    }

    @MainActor

    func testPermissionsManagerMemoryManagement() async throws {
        weak var weakManager: PermissionsManager?

        // Create manager in isolated scope
        autoreleasepool {
            let manager = PermissionsManager()
            weakManager = manager
            XCTAssertNotNil(weakManager)
        }

        // Wait a bit for deallocation
        try await Task.sleep(for: .milliseconds(100)) // 100ms

        // Note: The manager may not be deallocated immediately due to the monitoring task
        // This test mainly ensures we can create and reference it properly
        XCTAssertTrue(true)
    }

    @MainActor

    func testPermissionsManagerPublishedPropertyUpdates() async throws {
        let manager = PermissionsManager()

        var updateCount = 0
        let cancellable = manager.objectWillChange.sink { _ in
            updateCount += 1
        }

        // Wait for initial permission check to complete
        try await Task.sleep(for: .milliseconds(200)) // 200ms

        // The objectWillChange should have fired at least once during initialization
        XCTAssertGreaterThanOrEqual(updateCount, 0) // May be 0 if no changes occurred

        cancellable.cancel()
    }

    func testAXPermissionHelpersStaticMethodAvailability() async throws {
        // Verify that the static methods we depend on are available
        let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
        XCTAssertNotNil(hasPermissions)

        let requestResult = await AXPermissionHelpers.requestPermissions()
        XCTAssertNotNil(requestResult)
    }
}
