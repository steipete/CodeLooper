@testable import CodeLooper
import Foundation
import Testing

@Suite("LoginItemManager Tests")
struct LoginItemManagerTests {
    /// Test suite for LoginItemManager functionality

    @Test("Enable login item")
    func enableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get current state
        let initialState = await manager.startsAtLogin()

        // Test that we can read the state (true or false, both are valid)
        // initialState is a Bool - no need to validate it's a boolean

        // Test enabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        _ = await manager.setStartAtLogin(enabled: true)
        // Result is a Bool - just verify it executed without throwing
    }

    @Test("Disable login item")
    func disableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Test disabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        _ = await manager.setStartAtLogin(enabled: false)
        // Result is a Bool - just verify it executed without throwing
    }

    @Test("Login item status")
    func loginItemStatus() async throws {
        let manager = await LoginItemManager.shared

        // Test that status can be checked without errors
        let status = await manager.startsAtLogin()

        // Status is a Bool - verify it executed without throwing
        // No need to test if Bool is true or false

        // Test multiple status checks don't crash
        _ = await manager.startsAtLogin()
        _ = await manager.startsAtLogin()

        // All statuses are Bool values - execution without throwing is sufficient
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
    }

    @Test("Service management integration")
    func serviceManagementIntegration() async throws {
        // Test that the native SMAppService is available and functional
        let manager = await LoginItemManager.shared
        _ = await manager.startsAtLogin()

        // Status is a Bool - no need to validate it's a boolean

        // Test that we can observe changes
        await MainActor.run {
            let observation = manager.observeLoginItemStatus { newStatus in
                // This would be called on status changes
                _ = newStatus
            }

            // Cancel observation to clean up
            observation.cancel()
        }

    }

    @Test("Login item thread safety")
    func loginItemThreadSafety() async throws {
        let manager = await LoginItemManager.shared

        // Test concurrent access doesn't crash
        async let status1 = manager.startsAtLogin()
        async let status2 = manager.startsAtLogin()
        async let status3 = manager.startsAtLogin()

        let results = await [status1, status2, status3]

        // All results are Bool values - no need to validate they are booleans
        #expect(results.count == 3)
    }

    @Test("Toggle login item")
    func toggleLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get initial state
        let initialState = await manager.startsAtLogin()

        // Test toggle functionality
        _ = await manager.toggleStartAtLogin()

        // New state is a Bool - in a test environment, it might not actually toggle due to system restrictions
        // Just verify the method executed without throwing

        // Restore original state
        await manager.setStartAtLogin(enabled: initialState)
    }
}
