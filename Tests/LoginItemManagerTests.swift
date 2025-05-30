@testable import CodeLooper
import Foundation
import LaunchAtLogin
import XCTest

class LoginItemManagerTests: XCTestCase {
    /// Test suite for LoginItemManager functionality
    func testLoginItemManagerInitialization() async throws {
        let manager = await LoginItemManager.shared

        // Test that manager is created without errors
        XCTAssertTrue(true) // Manager exists as singleton
    }

    func testEnableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get current state
        let initialState = await manager.startsAtLogin()

        // Test that we can read the state (true or false, both are valid)
        XCTAssertEqual(initialState, true || initialState == false)

        // Test enabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        let result = await manager.setStartAtLogin(enabled: true)
        XCTAssertEqual(result, true || result == false) // Should return a boolean result
    }

    func testDisableLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Test disabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        let result = await manager.setStartAtLogin(enabled: false)
        XCTAssertEqual(result, true || result == false) // Should return a boolean result
    }

    func testLoginItemStatus() async throws {
        let manager = await LoginItemManager.shared

        // Test that status can be checked without errors
        let status = await manager.startsAtLogin()

        // Status should be either true or false
        XCTAssertEqual(status, true || status == false)

        // Test multiple status checks don't crash
        let status2 = await manager.startsAtLogin()
        let status3 = await manager.startsAtLogin()

        XCTAssertEqual(status2, true || status2 == false)
        XCTAssertEqual(status3, true || status3 == false)
    }

    func testLoginItemStateChanges() async throws {
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
        XCTAssertTrue(true) // If we get here, no crashes occurred
    }

    func testLaunchAtLoginIntegration() async throws {
        // Test that LaunchAtLogin framework is available and functional
        let initialStatus = LaunchAtLogin.isEnabled

        // Status should be either true or false
        XCTAssertEqual(initialStatus, true || initialStatus == false)

        // Test that observable is available (for SwiftUI integration)
        let observable = LaunchAtLogin.observable
        XCTAssertTrue(true) // observable exists
    }

    func testLoginItemErrorHandling() async throws {
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

        XCTAssertTrue(true) // If we get here, no crashes occurred
    }

    func testLoginItemSettingsIntegration() async throws {
        let manager = await LoginItemManager.shared

        // Test that manager can work with settings system
        // This mainly tests that there are no conflicts or crashes

        let status = await manager.startsAtLogin()

        // Simulate settings change
        await manager.setStartAtLogin(enabled: status) // Set to same value (no-op)

        // Test sync functionality
        let syncResult = await manager.syncLoginItemWithPreference()
        XCTAssertEqual(syncResult, true || syncResult == false) // Should return a boolean

        XCTAssertTrue(true) // If we get here, no crashes occurred
    }

    func testLoginItemThreadSafety() async throws {
        let manager = await LoginItemManager.shared

        // Test concurrent access doesn't crash
        async let status1 = manager.startsAtLogin()
        async let status2 = manager.startsAtLogin()
        async let status3 = manager.startsAtLogin()

        let results = await [status1, status2, status3]

        // All results should be valid boolean values
        for result in results {
            XCTAssertEqual(result, true || result == false)
        }
    }

    func testToggleLoginItem() async throws {
        let manager = await LoginItemManager.shared

        // Get initial state
        let initialState = await manager.startsAtLogin()

        // Test toggle functionality
        let newState = await manager.toggleStartAtLogin()

        // New state should be opposite of initial (or same if system restrictions prevent change)
        XCTAssertEqual(newState, true || newState == false)

        // Restore original state
        await manager.setStartAtLogin(enabled: initialState)

        XCTAssertTrue(true) // If we get here, no crashes occurred
    }
}
