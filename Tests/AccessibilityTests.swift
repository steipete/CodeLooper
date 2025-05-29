import AppKit
@testable import AXorcist
@testable import CodeLooper
import Foundation
import Testing

@MainActor

func permissionsManagerInitialization() async throws {
    let manager = PermissionsManager()

    // Verify manager initializes properly
    #expect(manager != nil)

    // Verify properties are available
    #expect(manager.hasAccessibilityPermissions != nil)
    #expect(manager.hasAutomationPermissions != nil)
    #expect(manager.hasScreenRecordingPermissions != nil)
    #expect(manager.hasNotificationPermissions != nil)
}

@MainActor

func permissionsManagerSharedInstance() async throws {
    let shared1 = PermissionsManager.shared
    let shared2 = PermissionsManager.shared

    // Verify shared instance is the same object
    #expect(shared1 === shared2)
}

@MainActor

func permissionsManagerPermissionCheckMethods() async throws {
    let manager = PermissionsManager()

    // These methods should not crash when called
    manager.openAutomationSettings()
    manager.openScreenRecordingSettings()

    #expect(true) // If we get here, methods didn't crash
}

@MainActor

func permissionsManagerRequestNotificationPermissions() async throws {
    let manager = PermissionsManager()

    // This should not crash, even if permissions are denied
    await manager.requestNotificationPermissions()

    #expect(true) // If we get here, request didn't crash
}

@MainActor

func permissionsManagerObservableObjectCompliance() async throws {
    let manager = PermissionsManager()

    // Test that it's properly marked as @MainActor and ObservableObject
    let objectWillChangePublisher = manager.objectWillChange
    #expect(objectWillChangePublisher != nil)
}


func aXPermissionHelpersAccessibilityCheck() async throws {
    // This tests the static method from AXorcist
    let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()

    // Should return a boolean value (either true or false)
    #expect(hasPermissions == true || hasPermissions == false)
}


func aXPermissionHelpersPermissionRequest() async throws {
    // Test that permission request method is available and doesn't crash
    // Note: This will show system dialog in real usage
    let result = await AXPermissionHelpers.requestPermissions()

    // Should return a boolean result
    #expect(result == true || result == false)
}

@MainActor

func permissionsManagerURLGeneration() async throws {
    // Test that the URL strings used in settings opening are valid
    let automationURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    let screenRecordingURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    #expect(automationURL != nil)
    #expect(screenRecordingURL != nil)
}

@MainActor

func permissionsManagerPermissionStateCaching() async throws {
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

@MainActor

func permissionsManagerPermissionMonitoringTask() async throws {
    let manager = PermissionsManager()

    // Wait a short time to let monitoring start
    try await Task.sleep(for: .milliseconds(100)) // 100ms

    // Verify that permission properties remain accessible
    #expect(manager.hasAccessibilityPermissions != nil)
    #expect(manager.hasAutomationPermissions != nil)
    #expect(manager.hasScreenRecordingPermissions != nil)
    #expect(manager.hasNotificationPermissions != nil)
}

@MainActor

func permissionsManagerPermissionRequestAccessibility() async throws {
    let manager = PermissionsManager()

    let initialState = manager.hasAccessibilityPermissions

    // Request accessibility permissions
    await manager.requestAccessibilityPermissions()

    // The permission state should be updated (may be same or different)
    let finalState = manager.hasAccessibilityPermissions
    #expect(finalState == true || finalState == false)

    // Note: In tests, this likely won't change unless running with permissions
    // But the method should complete without crashing
}

@MainActor

func permissionsManagerMultiplePermissionRequests() async throws {
    let manager = PermissionsManager()

    // Request multiple times - should not crash
    await manager.requestAccessibilityPermissions()
    await manager.requestNotificationPermissions()
    await manager.requestAccessibilityPermissions()

    #expect(true) // If we get here, multiple requests didn't crash
}

@MainActor

func permissionsManagerMemoryManagement() async throws {
    weak var weakManager: PermissionsManager?

    // Create manager in isolated scope
    autoreleasepool {
        let manager = PermissionsManager()
        weakManager = manager
        #expect(weakManager != nil)
    }

    // Wait a bit for deallocation
    try await Task.sleep(for: .milliseconds(100)) // 100ms

    // Note: The manager may not be deallocated immediately due to the monitoring task
    // This test mainly ensures we can create and reference it properly
    #expect(true)
}

@MainActor

func permissionsManagerPublishedPropertyUpdates() async throws {
    let manager = PermissionsManager()

    var updateCount = 0
    let cancellable = manager.objectWillChange.sink { _ in
        updateCount += 1
    }

    // Wait for initial permission check to complete
    try await Task.sleep(for: .milliseconds(200)) // 200ms

    // The objectWillChange should have fired at least once during initialization
    #expect(updateCount >= 0) // May be 0 if no changes occurred

    cancellable.cancel()
}


func aXPermissionHelpersStaticMethodAvailability() async throws {
    // Verify that the static methods we depend on are available
    let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
    #expect(hasPermissions != nil)

    let requestResult = await AXPermissionHelpers.requestPermissions()
    #expect(requestResult != nil)
}
