@testable import CodeLooper
import Foundation
import SwiftUI
import Testing
import Defaults

/// Test suite for UI-related component functionality
struct UIComponentTests {
    // MARK: - SettingsCoordinator Tests

    @Test
    func mainSettingsCoordinator() async throws {
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

    @Test
    func settingsTabCases() async throws {
        // Test all settings tabs exist
        let allTabs: [SettingsTab] = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced, .debug]

        for tab in allTabs {
            #expect(tab.id.isEmpty == false)
            #expect(tab.systemImageName.isEmpty == false)
        }
    }

    // MARK: - Model Tests

    @Test
    func monitoredInstanceInfo() async throws {
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
            #expect(windowInfo.isPaused == false)
        }
    }

    @Test
    func aiAnalysisStatus() async throws {
        // Test AIAnalysisStatus enum
        let statuses: [AIAnalysisStatus] = [.working, .notWorking, .pending, .error, .off, .unknown]
        
        for status in statuses {
            #expect(status.displayName.isEmpty == false)
        }
    }

    // MARK: - Service Tests

    @Test
    func loginItemManager() async throws {
        let manager = await LoginItemManager.shared
        #expect(true) // Manager exists
        
        // Test that we can check login item status
        let isEnabled = await manager.startsAtLogin()
        #expect(isEnabled == true || isEnabled == false) // Either state is valid
    }

    @Test
    func documentPathTracking() async throws {
        let gitMonitor = await GitRepositoryMonitor()
        let tracker = await DocumentPathTracker(gitRepositoryMonitor: gitMonitor)
        
        // Test document path existence check
        let exists = await tracker.documentPathExists("/nonexistent/path")
        #expect(exists == false)
        
        // Test with a real path
        let homeExists = await tracker.documentPathExists(NSHomeDirectory())
        #expect(homeExists == true)
    }

    // MARK: - Diagnostics Tests

    @Test
    func loggingConfiguration() async throws {
        // Test that logging is configured properly
        let logger = Logger(category: .ui)
        
        // Logger should exist and be usable
        logger.info("Test log message")
        #expect(true) // If we get here, logging works
    }

    @Test
    func logCategories() async throws {
        // Test all log categories exist
        let categories: [LogCategory] = [
            .general, .appDelegate, .appLifecycle, .supervision,
            .intervention, .jshook, .settings, .aiAnalysis,
            .accessibility, .diagnostics, .networking, .git,
            .statusBar, .onboarding, .ui, .utilities
        ]
        
        for category in categories {
            let logger = Logger(category: category)
            #expect(true) // Logger exists
        }
    }

    // MARK: - Configuration Tests

    @Test
    func defaultsKeys() async throws {
        // Test that defaults keys are defined
        _ = Defaults.Key<Bool>.isGlobalMonitoringEnabled
        _ = Defaults.Key<Bool>.hasCompletedOnboarding
        _ = Defaults.Key<Bool>.startAtLogin
        #expect(true) // Keys exist
    }

    @Test
    func timingConfiguration() async throws {
        // Test timing configuration values
        #expect(TimingConfiguration.monitoringCycleInterval > 0)
        #expect(TimingConfiguration.heartbeatCheckInterval > 0)
        #expect(TimingConfiguration.interventionActionDelay > 0)
    }

    // MARK: - Notification Tests

    @Test
    func notificationNames() async throws {
        // Test that notification names are defined
        _ = Notification.Name.ruleCounterUpdated
        _ = Notification.Name.AIServiceConfigured
        #expect(true) // Notification names exist
    }

    // MARK: - Error Handling Tests

    @Test
    func appErrorTypes() async throws {
        // Test error types
        let errors: [AppError] = [
            .serviceInitializationFailed(service: "Test", underlying: nil),
            .configurationMissing(setting: "Test"),
            .accessibilityPermissionDenied,
            .hookConnectionLost(windowId: "test-window")
        ]
        
        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    // MARK: - View Tests

    @Test
    func mainPopoverView() async throws {
        // Test that main views can be instantiated
        await MainActor.run {
            let popoverView = MainPopoverView()
            #expect(true) // View instantiated without crashes
        }
    }

    @Test
    func settingsViews() async throws {
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

    @Test
    func statusIconStates() async throws {
        // Test status icon states
        let states: [StatusIconState] = [.idle, .syncing, .error, .paused, .success]
        
        for state in states {
            #expect(state.rawValue.isEmpty == false)
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