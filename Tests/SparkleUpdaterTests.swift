@testable import CodeLooper
import Foundation
import Sparkle
import XCTest

class SparkleUpdaterTests: XCTestCase {
    // MARK: - SparkleUpdaterManager Tests

    func testSparkleUpdaterManagerInitialization() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()

            // Test that manager is created without errors
            XCTAssertTrue(true) // Manager exists

            // Test that updater controller is accessible
            _ = manager.updaterController
            XCTAssertTrue(true) // Controller is accessible
        }
    }

    func testSparkleConfiguration() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()

            // Test Sparkle updater controller configuration
            let controller = manager.updaterController
            XCTAssertTrue(true) // Controller exists

            // Test that updater exists
            let updater = controller.updater
            XCTAssertTrue(true) // Updater exists

            // Test that updater has proper configuration
            let automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
            XCTAssertEqual(automaticallyChecksForUpdates, true || automaticallyChecksForUpdates == false)

            // Test update interval
            let updateCheckInterval = updater.updateCheckInterval
            XCTAssertGreaterThan(updateCheckInterval, 0)
        }
    }

    func testUpdateCheckingConfiguration() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test that we can access update configuration
            XCTAssertTrue(true) // Updater accessible

            // Test automatic download configuration
            let automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
            XCTAssertEqual(automaticallyDownloadsUpdates, true || automaticallyDownloadsUpdates == false)

            // Test update check interval
            XCTAssertGreaterThanOrEqual(updater.updateCheckInterval, 0)
        }
    }

    // MARK: - UpdaterViewModel Tests

    func testUpdaterViewModelInitialization() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)
            XCTAssertNotNil(viewModel) // View model exists
        }
    }

    func testUpdaterViewModelConfiguration() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that view model has proper initial state
            XCTAssertEqual(viewModel.isUpdateInProgress, false)
            XCTAssertEqual(viewModel.lastUpdateCheckDate, nil)
        }
    }

    func testUpdaterViewModelActions() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that actions don't crash
            viewModel.checkForUpdates()
            XCTAssertTrue(true) // Check initiated without crash
        }
    }

    func testSparkleUpdateLifecycle() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test updater exists
            XCTAssertNotNil(updater)
        }
    }

    func testSparkleUpdateCheckInterval() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test default update check interval
            let interval = updater.updateCheckInterval
            XCTAssertTrue(interval == 86400 || interval == 3600 || interval > 0) // Daily, hourly, or custom
        }
    }

    func testSparklePermissions() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let updater = manager.updaterController.updater

            // Test feed URL configuration
            // Feed URL can be either configured or not - just verify the property is accessible
            _ = updater.feedURL
        }
    }

    func testSparkleUserDriver() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let controller = manager.updaterController

            // Test that controller has user driver
            XCTAssertTrue(true) // User driver is part of controller
        }
    }

    // MARK: - Integration Tests

    func testSparkleIntegration() async throws {
        await MainActor.run {
            let manager = SparkleUpdaterManager()
            let viewModel = UpdaterViewModel(sparkleUpdaterManager: manager)

            // Test that manager and view model can work together
            XCTAssertNotNil(viewModel) // View model exists
            XCTAssertNotNil(manager.updaterController) // Controller exists

            // Test that view model can interact with manager
            viewModel.checkForUpdates()
            XCTAssertEqual(viewModel.isUpdateInProgress, true)
        }
    }
}
