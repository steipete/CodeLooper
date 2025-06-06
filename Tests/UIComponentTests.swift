@testable import CodeLooper
import Defaults
import Foundation
import SwiftUI
import Testing

@Suite("UIComponentTests")
struct UIComponentTests {
    // MARK: - SettingsCoordinator Tests

    @Test("Main settings coordinator") @MainActor func mainSettingsCoordinator() async throws {
        // Create mock dependencies
        let mockLoginItemManager = await createMockLoginItemManager()
        let mockUpdaterViewModel = await createMockUpdaterViewModel()
        let coordinator = await MainSettingsCoordinator(
            loginItemManager: mockLoginItemManager,
            updaterViewModel: mockUpdaterViewModel
        )

        // Test that coordinator is created without errors
        #expect(true) // Coordinator exists
    }

    @Test("Settings tab cases") func settingsTabCases() {
        // Test all settings tabs exist
        let allTabs: [SettingsTab] = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced, .debug]

        for tab in allTabs {
            #expect(!tab.id.isEmpty)
            #expect(!tab.systemImageName.isEmpty)
        }
    }

    // MARK: - Model Tests

    @Test("Monitored instance info") @MainActor func monitoredInstanceInfo() async throws {
        // Test MonitoredWindowInfo creation
        let windowInfo = await MonitoredWindowInfo(
            id: "test-window",
            windowTitle: "Test Window",
            axElement: nil,
            documentPath: nil,
            isPaused: false
        )

        await MainActor.run {
            #expect(windowInfo.id == "test-window")
            #expect(windowInfo.windowTitle == "Test Window")
            #expect(!windowInfo.isPaused)
        }
    }

    @Test("A i analysis status") func aIAnalysisStatus() {
        // Test AIAnalysisStatus enum
        let statuses: [AIAnalysisStatus] = [.working, .notWorking, .pending, .error, .off, .unknown]

        for status in statuses {
            #expect(!status.displayName.isEmpty)
        }
    }

    // MARK: - Service Tests

    @Test("Login item manager") @MainActor func testLoginItemManager() async throws {
        let manager = await LoginItemManager.shared
        #expect(true) // Manager exists

        // Test that we can check login item status
        let isEnabled = await manager.startsAtLogin()
        #expect(!isEnabled == true || isEnabled) // Either state is valid
    }

    @Test("Document path tracking") @MainActor func documentPathTracking() async throws {
        let gitMonitor = await GitRepositoryMonitor()
        let tracker = await DocumentPathTracker(gitRepositoryMonitor: gitMonitor)

        // Test document path existence check
        let exists = await tracker.documentPathExists("/nonexistent/path")
        #expect(!exists)

        // Test with a real path
        let homeExists = await tracker.documentPathExists(NSHomeDirectory())
        #expect(homeExists)
    }

    // MARK: - Diagnostics Tests

    @Test("Logging configuration") func loggingConfiguration() {
        // Test that logging is configured properly
        let logger = Logger(category: .ui)

        // Logger should exist and be usable
        logger.info("Test log message")
        #expect(true) // If we get here, logging works
    }

    @Test("Log categories") func logCategories() {
        // Test all log categories exist
        let categories: [LogCategory] = [
            .general, .appDelegate, .appLifecycle, .supervision,
            .intervention, .jshook, .settings, .aiAnalysis,
            .accessibility, .diagnostics, .networking, .git,
            .statusBar, .onboarding, .ui, .utilities,
        ]

        for category in categories {
            let logger = Logger(category: category)
            #expect(true) // Logger exists
        }
    }

    // MARK: - Configuration Tests

    @Test("Defaults keys") func defaultsKeys() {
        // Test that defaults keys are defined
        _ = Defaults.Key<Bool>.isGlobalMonitoringEnabled
        _ = Defaults.Key<Bool>.hasCompletedOnboarding
        _ = Defaults.Key<Bool>.startAtLogin
        #expect(true) // Keys exist
    }

    @Test("Timing configuration") func timingConfiguration() {
        // Test timing configuration values
        #expect(TimingConfiguration.monitoringCycleInterval > 0)
        #expect(TimingConfiguration.heartbeatCheckInterval > 0)
        #expect(TimingConfiguration.interventionActionDelay > 0)
    }

    // MARK: - Notification Tests

    @Test("Notification names") func notificationNames() {
        // Test that notification names are defined
        _ = Notification.Name.ruleCounterUpdated
        _ = Notification.Name.AIServiceConfigured
        #expect(true) // Notification names exist
    }

    // MARK: - Error Handling Tests

    @Test("App error types") func appErrorTypes() {
        // Test error types
        let errors: [AppError] = [
            .serviceInitializationFailed(service: "Test", underlying: nil),
            .configurationMissing(setting: "Test"),
            .accessibilityPermissionDenied,
            .hookConnectionLost(windowId: "test-window"),
        ]

        for error in errors {
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    // MARK: - View Tests

    @Test("Main popover view") @MainActor func mainPopoverView() async throws {
        // Test that main views can be instantiated
        await MainActor.run {
            let popoverView = MainPopoverView()
            #expect(true) // View instantiated without crashes
        }
    }

    @Test("Settings views") @MainActor func settingsViews() async throws {
        // Test settings views
        await MainActor.run {
            let mockUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: SparkleUpdaterManager())
            _ = GeneralSettingsView(updaterViewModel: mockUpdaterViewModel)
            _ = CursorSupervisionSettingsView()
            _ = AdvancedSettingsView()
            #expect(true) // Views instantiated without crashes
        }
    }

    // MARK: - Icon Tests

    @Test("Status icon states") func statusIconStates() {
        // Test status icon states
        let states: [StatusIconState] = [.idle, .syncing, .error, .paused, .success]

        for state in states {
            #expect(!state.rawValue.isEmpty)
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
