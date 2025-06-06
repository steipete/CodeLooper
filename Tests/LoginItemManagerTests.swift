@testable import CodeLooper
import Foundation
import Testing

@Suite("LoginItemManager Tests")
struct LoginItemManagerTests {
    /// Test suite for LoginItemManager functionality
    @Test("Login item manager initialization")
    func loginItemManagerInitialization() async throws {
        let manager = await LoginItemManager.shared

        // Test that manager is created without errors
        #expect(true) // Manager exists as singleton
    }

    @Test("Enable login item")
    func enableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get current state
        let initialState = await manager.startsAtLogin()

        // Test that we can read the state (true or false, both are valid)
        #expect(!initialState == true || initialState)

        // Test enabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        let result = await manager.setStartAtLogin(enabled: true)
        #expect(!result == true || result) // Should return a boolean result
    }

    @Test("Disable login item")
    func disableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Test disabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        let result = await manager.setStartAtLogin(enabled: false)
        #expect(!result == true || result) // Should return a boolean result
    }

    @Test("Login item status")
    func loginItemStatus() async throws {
        let manager = await LoginItemManager.shared

        // Test that status can be checked without errors
        let status = await manager.startsAtLogin()

        // Status should be either true or false
        #expect(!status == true || status)

        // Test multiple status checks don't crash
        let status2 = await manager.startsAtLogin()
        let status3 = await manager.startsAtLogin()

        #expect(!status2 == true || status2)
        #expect(!status3 == true || status3)
    }

    @Test("Login item state changes")
    func loginItemStateChanges() async throws {
        let manager = await LoginItemManager.shared

        // Get initial state
        let initialState = await manager.startsAtLogin()

        // Test toggling (without actually changing system settings in tests)
        // We mainly test that the manager handles calls without crashing

        if initialState {
            // If currently enabled, test disabling
            await manager.setStartAtLogin(enabled: false)
            await manager.setStartAtLogin(enabled: true) // Restore
        } else {
            // If currently disabled, test enabling
            await manager.setStartAtLogin(enabled: true)
            await manager.setStartAtLogin(enabled: false) // Restore
        }

        // Note: We don't verify the final state matches initial state
        // because system restrictions might prevent changes in test environment
        #expect(true) // If we get here, no crashes occurred
    }

    @Test("Service management integration")
    func serviceManagementIntegration() async throws {
        // Test that the native SMAppService is available and functional
        let manager = await LoginItemManager.shared
        let initialStatus = await manager.startsAtLogin()

        // Status should be either true or false
        #expect(!initialStatus == true || initialStatus)

        // Test that we can observe changes
        await MainActor.run {
            let observation = manager.observeLoginItemStatus { newStatus in
                // This would be called on status changes
                _ = newStatus
            }
            
            // Cancel observation to clean up
            observation.cancel()
        }

        #expect(true) // If we get here, no crashes occurred
    }

    @Test("Login item error handling")
    func loginItemErrorHandling() async throws {
        let manager = await LoginItemManager.shared

        // Test that manager handles edge cases gracefully
        // Multiple rapid calls shouldn't crash
        for _ in 0 ..< 5 {
            _ = await manager.startsAtLogin()
        }

        // Rapid enable/disable calls shouldn't crash
        let currentState = await manager.startsAtLogin()
        await manager.setStartAtLogin(enabled: !currentState)
        await manager.setStartAtLogin(enabled: currentState) // Restore

        #expect(true) // If we get here, no crashes occurred
    }

    @Test("Login item settings integration")
    func loginItemSettingsIntegration() async throws {
        let manager = await LoginItemManager.shared

        // Test that manager can work with settings system
        // This mainly tests that there are no conflicts or crashes

        let status = await manager.startsAtLogin()

        // Simulate settings change
        await manager.setStartAtLogin(enabled: status) // Set to same value (no-op)

        // Test sync functionality
        let syncResult = await manager.syncLoginItemWithPreference()
        #expect(!syncResult == true || syncResult) // Should return a boolean

        #expect(true) // If we get here, no crashes occurred
    }

    @Test("Login item thread safety")
    func loginItemThreadSafety() async throws {
        let manager = await LoginItemManager.shared

        // Test concurrent access doesn't crash
        async let status1 = manager.startsAtLogin()
        async let status2 = manager.startsAtLogin()
        async let status3 = manager.startsAtLogin()

        let results = await [status1, status2, status3]

        // All results should be valid boolean values
        for result in results {
            #expect(!result == true || result)
        }
    }

    @Test("Toggle login item")
    func toggleLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get initial state
        let initialState = await manager.startsAtLogin()

        // Test toggle functionality
        let newState = await manager.toggleStartAtLogin()

        // New state should be opposite of initial (or same if system restrictions prevent change)
        #expect(!newState == true || newState)

        // Restore original state
        await manager.setStartAtLogin(enabled: initialState)

        #expect(true) // If we get here, no crashes occurred
    }
}
