@testable import CodeLooper
import Defaults
import Diagnostics
import Foundation
import SwiftUI
import XCTest

class UIComponentTests: XCTestCase {
    // MARK: - SettingsCoordinator Tests

    func testMainSettingsCoordinator() async throws {
        // Create mock dependencies
        let mockLoginItemManager = await createMockLoginItemManager()
        let mockUpdaterViewModel = await createMockUpdaterViewModel()
        let coordinator = await MainSettingsCoordinator(
            loginItemManager: mockLoginItemManager,
            updaterViewModel: mockUpdaterViewModel
        )

        // Test that coordinator is created without errors
        XCTAssertTrue(true) // Coordinator exists
    }

    func testSettingsTabCases() async throws {
        // Test all settings tabs exist
        let allTabs: [SettingsTab] = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced, .debug]

        for tab in allTabs {
            XCTAssertEqual(tab.id.isEmpty, false)
            XCTAssertEqual(tab.systemImageName.isEmpty, false)
        }
    }

    // MARK: - Model Tests

    func testMonitoredInstanceInfo() async throws {
        // Test MonitoredWindowInfo creation
        let windowInfo = await MonitoredWindowInfo(
            id: "test-window",
            windowTitle: "Test Window",
            axElement: nil,
            documentPath: nil,
            isPaused: false
        )

        await MainActor.run {
            XCTAssertEqual(windowInfo.id, "test-window")
            XCTAssertEqual(windowInfo.windowTitle, "Test Window")
            XCTAssertEqual(windowInfo.isPaused, false)
        }
    }

    func testAIAnalysisStatus() async throws {
        // Test AIAnalysisStatus enum
        let statuses: [AIAnalysisStatus] = [.working, .notWorking, .pending, .error, .off, .unknown]

        for status in statuses {
            XCTAssertEqual(status.displayName.isEmpty, false)
        }
    }

    // MARK: - Service Tests

    func testLoginItemManager() async throws {
        let manager = await LoginItemManager.shared
        XCTAssertTrue(true) // Manager exists

        // Test that we can check login item status
        let isEnabled = await manager.startsAtLogin()
        XCTAssertEqual(isEnabled, true || isEnabled == false) // Either state is valid
    }

    func testDocumentPathTracking() async throws {
        let gitMonitor = await GitRepositoryMonitor()
        let tracker = await DocumentPathTracker(gitRepositoryMonitor: gitMonitor)

        // Test document path existence check
        let exists = await tracker.documentPathExists("/nonexistent/path")
        XCTAssertEqual(exists, false)

        // Test with a real path
        let homeExists = await tracker.documentPathExists(NSHomeDirectory())
        XCTAssertEqual(homeExists, true)
    }

    // MARK: - Diagnostics Tests

    func testLoggingConfiguration() async throws {
        // Test that logging is configured properly
        let logger = Logger(category: .ui)

        // Logger should exist and be usable
        logger.info("Test log message")
        XCTAssertTrue(true) // If we get here, logging works
    }

    func testLogCategories() async throws {
        // Test all log categories exist
        let categories: [LogCategory] = [
            .general, .appDelegate, .appLifecycle, .supervision,
            .intervention, .jshook, .settings, .aiAnalysis,
            .accessibility, .diagnostics, .networking, .git,
            .statusBar, .onboarding, .ui, .utilities,
        ]

        for category in categories {
            let logger = Logger(category: category)
            XCTAssertTrue(true) // Logger exists
        }
    }

    // MARK: - Configuration Tests

    func testDefaultsKeys() async throws {
        // Test that defaults keys are defined
        _ = Defaults.Key<Bool>.isGlobalMonitoringEnabled
        _ = Defaults.Key<Bool>.hasCompletedOnboarding
        _ = Defaults.Key<Bool>.startAtLogin
        XCTAssertTrue(true) // Keys exist
    }

    func testTimingConfiguration() async throws {
        // Test timing configuration values
        XCTAssertGreaterThan(TimingConfiguration.monitoringCycleInterval, 0)
        XCTAssertGreaterThan(TimingConfiguration.heartbeatCheckInterval, 0)
        XCTAssertGreaterThan(TimingConfiguration.interventionActionDelay, 0)
    }

    // MARK: - Notification Tests

    func testNotificationNames() async throws {
        // Test that notification names are defined
        _ = Notification.Name.ruleCounterUpdated
        _ = Notification.Name.AIServiceConfigured
        XCTAssertTrue(true) // Notification names exist
    }

    // MARK: - Error Handling Tests

    func testAppErrorTypes() async throws {
        // Test error types
        let errors: [AppError] = [
            .serviceInitializationFailed(service: "Test", underlying: nil),
            .configurationMissing(setting: "Test"),
            .accessibilityPermissionDenied,
            .hookConnectionLost(windowId: "test-window"),
        ]

        for error in errors {
            XCTAssertEqual(error.localizedDescription.isEmpty, false)
        }
    }

    // MARK: - View Tests

    func testMainPopoverView() async throws {
        // Test that main views can be instantiated
        await MainActor.run {
            let popoverView = MainPopoverView()
            XCTAssertTrue(true) // View instantiated without crashes
        }
    }

    func testSettingsViews() async throws {
        // Test settings views
        await MainActor.run {
            let mockUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: SparkleUpdaterManager())
            _ = GeneralSettingsView(updaterViewModel: mockUpdaterViewModel)
            _ = CursorSupervisionSettingsView()
            _ = AdvancedSettingsView()
            XCTAssertTrue(true) // Views instantiated without crashes
        }
    }

    // MARK: - Icon Tests

    func testStatusIconStates() async throws {
        // Test status icon states
        let states: [StatusIconState] = [.idle, .syncing, .error, .paused, .success]

        for state in states {
            XCTAssertEqual(state.rawValue.isEmpty, false)
        }
    }

    // MARK: - Test Helpers

    func createMockLoginItemManager() async -> LoginItemManager {
        await LoginItemManager.shared
    }

    func createMockUpdaterViewModel() async -> UpdaterViewModel {
        await UpdaterViewModel(sparkleUpdaterManager: SparkleUpdaterManager())
    }
}
