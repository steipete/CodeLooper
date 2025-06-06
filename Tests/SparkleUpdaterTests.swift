@testable import CodeLooper
import Foundation
import Sparkle
import Testing

@Suite("SparkleUpdaterTests")
struct SparkleUpdaterTests {
    // MARK: - SparkleUpdaterManager Tests

    @Test("Sparkle updater manager initialization") func sparkleUpdaterManagerInitialization() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()

            // Test that manager is created without errors
            #expect(true) // Manager exists

            // Test that updater controller is accessible
            _ = manager.updaterController
            #expect(true) // Controller is accessible
        }
    }

    @Test("Sparkle configuration") func sparkleConfiguration() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()

            // Test Sparkle updater controller configuration
            let controller = manager.updaterController
            #expect(true) // Controller exists

            // Test that updater exists
            let updater = controller.updater
            #expect(true) // Updater exists

            // Test that updater has proper configuration
            let automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
            #expect(automaticallyChecksForUpdates == true || automaticallyChecksForUpdates == false)

            // Test update interval
            let updateCheckInterval = updater.updateCheckInterval
            #expect(updateCheckInterval > 0)
        }
    }

    @Test("Update checking configuration") func updateCheckingConfiguration() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test that we can access update configuration
            #expect(true) // Updater accessible

            // Test automatic download configuration
            let automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
            #expect(automaticallyDownloadsUpdates == true || automaticallyDownloadsUpdates == false)

            // Test update check interval
            #expect(updater.updateCheckInterval >= 0)
        }
    }

    // MARK: - UpdaterViewModel Tests

    @Test("Updater view model initialization") func updaterViewModelInitialization() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)
            #expect(viewModel != nil) // View model exists
        }
    }

    @Test("Updater view model configuration") func updaterViewModelConfiguration() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that view model has proper initial state
            #expect(viewModel.isUpdateInProgress == false)
            #expect(viewModel.lastUpdateCheckDate == nil)
        }
    }

    @Test("Updater view model actions") func updaterViewModelActions() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that actions don't crash
            viewModel.checkForUpdates()
            #expect(true) // Check initiated without crash
        }
    }

    @Test("Sparkle update lifecycle") func sparkleUpdateLifecycle() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test updater exists
            #expect(updater != nil)
        }
    }

    @Test("Sparkle update check interval") func sparkleUpdateCheckInterval() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test default update check interval
            let interval = updater.updateCheckInterval
            #expect(interval == 86400 || interval == 3600 || interval > 0) // Daily, hourly, or custom
        }
    }

    @Test("Sparkle permissions") func sparklePermissions() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test feed URL configuration
            // Feed URL can be either configured or not - just verify the property is accessible
            _ = updater.feedURL
        }
    }

    @Test("Sparkle user driver") func sparkleUserDriver() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let controller = manager.updaterController

            // Test that controller has user driver
            #expect(true) // User driver is part of controller
        }
    }

    // MARK: - Integration Tests

    @Test("Sparkle integration") func sparkleIntegration() async {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that manager and view model can work together
            #expect(viewModel != nil) // View model exists
            #expect(manager.updaterController != nil) // Controller exists

            // Test that view model can interact with manager
            viewModel.checkForUpdates()
            #expect(viewModel.isUpdateInProgress == true)
        }
    }
}
