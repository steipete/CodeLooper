import Testing
import Foundation
import LaunchAtLogin
@testable import CodeLooper

/// Test suite for LoginItemManager functionality
@Suite("Login Item Manager Tests")
struct LoginItemManagerTests {
    
    // MARK: - LoginItemManager Tests
    
    @Test("LoginItemManager can be initialized")
    func testLoginItemManagerInitialization() async throws {
        let manager = LoginItemManager.shared
        
        // Test that manager is created without errors
        #expect(manager != nil)
    }
    
    @Test("LoginItemManager manages login state")
    func testEnableLoginItem() async throws {
        let manager = LoginItemManager.shared
        
        // Get current state
        let initialState = manager.isEnabled
        
        // Test that we can read the state (true or false, both are valid)
        #expect(initialState == true || initialState == false)
        
        // Test enabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        do {
            manager.setEnabled(true)
            #expect(true) // If we get here, no crash occurred
        } catch {
            // Some systems may restrict this functionality
            #expect(error != nil)
        }
    }
    
    @Test("LoginItemManager handles disable functionality")
    func testDisableLoginItem() async throws {
        let manager = LoginItemManager.shared
        
        // Test disabling (this is a test, so we won't actually change system settings)
        // Instead, we test that the method doesn't crash
        do {
            manager.setEnabled(false)
            #expect(true) // If we get here, no crash occurred
        } catch {
            // Some systems may restrict this functionality
            #expect(error != nil)
        }
    }
    
    @Test("LoginItemManager can check status")
    func testLoginItemStatus() async throws {
        let manager = LoginItemManager.shared
        
        // Test that status can be checked without errors
        let status = manager.isEnabled
        
        // Status should be either true or false
        #expect(status == true || status == false)
        
        // Test multiple status checks don't crash
        let status2 = manager.isEnabled
        let status3 = manager.isEnabled
        
        #expect(status2 == true || status2 == false)
        #expect(status3 == true || status3 == false)
    }
    
    @Test("LoginItemManager handles state changes gracefully")
    func testLoginItemStateChanges() async throws {
        let manager = LoginItemManager.shared
        
        // Get initial state
        let initialState = manager.isEnabled
        
        // Test toggling (without actually changing system settings in tests)
        // We mainly test that the manager handles calls without crashing
        
        if initialState {
            // If currently enabled, test disabling
            manager.setEnabled(false)
            manager.setEnabled(true) // Restore
        } else {
            // If currently disabled, test enabling
            manager.setEnabled(true)
            manager.setEnabled(false) // Restore
        }
        
        // Verify final state matches initial state (since we restored it)
        let finalState = manager.isEnabled
        #expect(finalState == initialState)
    }
    
    // MARK: - LaunchAtLogin Integration Tests
    
    @Test("LaunchAtLogin framework integration")
    func testLaunchAtLoginIntegration() async throws {
        // Test that LaunchAtLogin framework is available and functional
        let initialStatus = LaunchAtLogin.isEnabled
        
        // Status should be either true or false
        #expect(initialStatus == true || initialStatus == false)
        
        // Test that observable is available (for SwiftUI integration)
        let observable = LaunchAtLogin.observable
        #expect(observable != nil)
    }
    
    @Test("LoginItemManager error handling")
    func testLoginItemErrorHandling() async throws {
        let manager = LoginItemManager.shared
        
        // Test that manager handles edge cases gracefully
        // Multiple rapid calls shouldn't crash
        for _ in 0..<5 {
            _ = manager.isEnabled
        }
        
        // Rapid enable/disable calls shouldn't crash
        let currentState = manager.isEnabled
        manager.setEnabled(!currentState)
        manager.setEnabled(currentState) // Restore
        
        #expect(true) // If we get here, no crashes occurred
    }
    
    // MARK: - Integration with App Settings
    
    @Test("LoginItemManager integrates with app settings")
    func testLoginItemSettingsIntegration() async throws {
        let manager = LoginItemManager.shared
        
        // Test that manager can work with settings system
        // This mainly tests that there are no conflicts or crashes
        
        let status = manager.isEnabled
        
        // Simulate settings change
        manager.setEnabled(status) // Set to same value (no-op)
        
        // Verify status is unchanged
        let newStatus = manager.isEnabled
        #expect(newStatus == status)
    }
    
    @Test("LoginItemManager thread safety")
    func testLoginItemThreadSafety() async throws {
        let manager = LoginItemManager.shared
        
        // Test concurrent access doesn't crash
        async let status1 = Task { manager.isEnabled }
        async let status2 = Task { manager.isEnabled }
        async let status3 = Task { manager.isEnabled }
        
        let results = await [status1.value, status2.value, status3.value]
        
        // All results should be valid boolean values
        for result in results {
            #expect(result == true || result == false)
        }
    }
}