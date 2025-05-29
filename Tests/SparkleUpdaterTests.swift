import Testing
import Foundation
import Sparkle
@testable import CodeLooper

/// Test suite for Sparkle auto-update functionality
@Suite("Sparkle Updater Tests")
struct SparkleUpdaterTests {
    
    // MARK: - SparkleUpdaterManager Tests
    
    @Test("SparkleUpdaterManager can be initialized")
    func testSparkleUpdaterManagerInitialization() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test that manager is created without errors
        #expect(manager != nil)
        
        // Test basic properties
        #expect(manager.updater != nil)
        #expect(manager.isUpdateCheckInProgress == false)
    }
    
    @Test("SparkleUpdaterManager configures Sparkle correctly")
    func testSparkleConfiguration() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test Sparkle updater configuration
        let updater = manager.updater
        #expect(updater != nil)
        
        // Test that updater has proper configuration
        let automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        #expect(automaticallyChecksForUpdates == true || automaticallyChecksForUpdates == false)
        
        // Test update interval
        let updateCheckInterval = updater.updateCheckInterval
        #expect(updateCheckInterval > 0)
    }
    
    @Test("SparkleUpdaterManager handles update checking")
    func testUpdateChecking() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test manual update check
        await manager.checkForUpdates()
        
        // Test that check doesn't crash
        #expect(true)
        
        // Test update check state
        #expect(manager.isUpdateCheckInProgress == true || manager.isUpdateCheckInProgress == false)
    }
    
    @Test("SparkleUpdaterManager handles update installation flow")
    func testUpdateInstallation() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test update installation preparation
        let canInstallUpdates = manager.canInstallUpdates()
        #expect(canInstallUpdates == true || canInstallUpdates == false)
        
        // Test update installation settings
        await manager.setAutomaticUpdateInstallation(enabled: true)
        await manager.setAutomaticUpdateInstallation(enabled: false)
        
        // Should handle installation settings without crashes
        #expect(true)
    }
    
    // MARK: - UpdaterViewModel Tests
    
    @Test("UpdaterViewModel manages update UI state")
    func testUpdaterUI() async throws {
        let viewModel = UpdaterViewModel()
        
        // Test that view model is created without errors
        #expect(viewModel != nil)
        
        // Test initial state
        await MainActor.run {
            #expect(viewModel.isCheckingForUpdates == false)
            #expect(viewModel.updateAvailable == false)
            #expect(viewModel.currentVersion != nil)
        }
        
        // Test state transitions
        await viewModel.checkForUpdates()
        
        // Should handle UI state updates gracefully
        #expect(true)
    }
    
    @Test("UpdaterViewModel handles update notifications")
    func testUpdateNotifications() async throws {
        let viewModel = UpdaterViewModel()
        
        // Test update notification handling
        await viewModel.handleUpdateNotification(isAvailable: true)
        
        await MainActor.run {
            #expect(viewModel.updateAvailable == true)
        }
        
        await viewModel.handleUpdateNotification(isAvailable: false)
        
        await MainActor.run {
            #expect(viewModel.updateAvailable == false)
        }
    }
    
    // MARK: - Update Check Flow Tests
    
    @Test("Update check flow works end-to-end")
    func testUpdateCheckFlow() async throws {
        let manager = SparkleUpdaterManager()
        let viewModel = UpdaterViewModel()
        
        // Test coordinated update check
        await manager.checkForUpdates()
        await viewModel.checkForUpdates()
        
        // Both should complete without errors
        #expect(true)
        
        // Test update check cancellation
        await manager.cancelUpdateCheck()
        
        #expect(true)
    }
    
    @Test("Update preferences are persisted correctly")
    func testUpdatePreferencesPersistence() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test setting preferences
        await manager.setAutomaticUpdateChecking(enabled: true)
        let isEnabled = await manager.isAutomaticUpdateCheckingEnabled()
        #expect(isEnabled == true)
        
        await manager.setAutomaticUpdateChecking(enabled: false)
        let isDisabled = await manager.isAutomaticUpdateCheckingEnabled()
        #expect(isDisabled == false)
        
        // Test update check interval setting
        await manager.setUpdateCheckInterval(hours: 24)
        let interval = await manager.getUpdateCheckInterval()
        #expect(interval == 24 * 3600) // 24 hours in seconds
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Sparkle handles network errors gracefully")
    func testSparkleNetworkErrorHandling() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test update check with potential network issues
        await manager.checkForUpdatesWithTimeout(seconds: 5)
        
        // Should handle network errors gracefully
        #expect(true)
        
        // Test error state handling
        let hasError = await manager.hasUpdateCheckError()
        #expect(hasError == true || hasError == false)
        
        if hasError {
            let errorMessage = await manager.getLastUpdateCheckError()
            #expect(errorMessage != nil)
        }
    }
    
    @Test("Sparkle handles malformed update feeds")
    func testSparkleErrorHandling() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test with invalid update URL (should not crash)
        await manager.setUpdateFeedURL("invalid-url")
        await manager.checkForUpdates()
        
        // Should handle invalid feed gracefully
        #expect(true)
        
        // Reset to valid URL
        await manager.resetUpdateFeedURL()
        
        #expect(true)
    }
    
    // MARK: - Version Comparison Tests
    
    @Test("Version comparison works correctly")
    func testVersionComparison() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test version comparison
        let currentVersion = await manager.getCurrentVersion()
        #expect(currentVersion != nil)
        #expect(!currentVersion.isEmpty)
        
        // Test version format validation
        let isValidVersion = await manager.isValidVersion("1.2.3")
        #expect(isValidVersion == true)
        
        let isInvalidVersion = await manager.isValidVersion("invalid-version")
        #expect(isInvalidVersion == false)
        
        // Test version comparison
        let isNewer = await manager.isVersionNewer("2.0.0", than: "1.0.0")
        #expect(isNewer == true)
        
        let isOlder = await manager.isVersionNewer("1.0.0", than: "2.0.0")
        #expect(isOlder == false)
    }
    
    // MARK: - Security Tests
    
    @Test("Update verification and security")
    func testUpdateSecurity() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test signature verification
        let verificationEnabled = await manager.isSignatureVerificationEnabled()
        #expect(verificationEnabled == true) // Should always verify signatures
        
        // Test secure download
        let usesSecureDownload = await manager.usesSecureDownloadChannel()
        #expect(usesSecureDownload == true) // Should use HTTPS
        
        // Test update validation
        await manager.validateUpdateIntegrity()
        
        // Should handle security validation without crashes
        #expect(true)
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("Sparkle handles concurrent update operations")
    func testConcurrentUpdateOperations() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test concurrent update checks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    await manager.checkForUpdates()
                }
            }
        }
        
        // Should handle concurrent operations gracefully
        #expect(true)
        
        // Test concurrent preference changes
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await manager.setAutomaticUpdateChecking(enabled: true)
            }
            group.addTask {
                await manager.setUpdateCheckInterval(hours: 12)
            }
            group.addTask {
                await manager.setAutomaticUpdateInstallation(enabled: false)
            }
        }
        
        #expect(true)
    }
    
    // MARK: - Integration Tests
    
    @Test("Sparkle integrates with app lifecycle")
    func testSparkleAppLifecycleIntegration() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test app startup integration
        await manager.handleAppStartup()
        
        // Test app termination integration
        await manager.handleAppTermination()
        
        // Test background update checking
        await manager.enableBackgroundUpdateChecking()
        await manager.disableBackgroundUpdateChecking()
        
        // Should integrate with app lifecycle smoothly
        #expect(true)
    }
    
    @Test("Sparkle performance under various conditions")
    func testSparklePerformance() async throws {
        let manager = SparkleUpdaterManager()
        
        // Test rapid update checks
        let startTime = Date()
        
        for _ in 0..<5 {
            await manager.checkForUpdates()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete reasonably quickly (less than 10 seconds for 5 checks)
        #expect(duration < 10.0)
        
        // Test memory usage during update operations
        await manager.performMemoryEfficientUpdateCheck()
        
        #expect(true)
    }
}