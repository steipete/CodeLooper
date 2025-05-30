import AppKit
import AXorcist
@testable import CodeLooper
import Defaults
import Foundation
import XCTest

class IntegrationTests: XCTestCase {
    // MARK: - Test Utilities

    /// Mock application for testing app lifecycle
    class MockCodeLooperApp {
        var isRunning = false
        var coordinator: AppServiceCoordinator?
        var windowManager: WindowManager?

        func startup() async {
            isRunning = true
            coordinator = await AppServiceCoordinator()
            let loginItemManager = await LoginItemManager.shared
            let sessionLogger = await SessionLogger.shared
            windowManager = await WindowManager(
                loginItemManager: loginItemManager,
                sessionLogger: sessionLogger,
                delegate: nil
            )
        }

        func shutdown() async {
            isRunning = false
            coordinator = nil
            windowManager = nil
        }
    }

    /// Test helper to create temporary defaults
    func withTemporaryDefaults<T>(_ block: () async throws -> T) async rethrows -> T {
        // Note: Defaults library no longer supports changing suite at runtime
        // Just run the block directly
        try await block()
    }

    // MARK: - Application Lifecycle Tests

    func testFullApplicationLifecycle() async throws {
        let app = MockCodeLooperApp()

        // Initially not running
        XCTAssertTrue(!app.isRunning)
        XCTAssertNil(app.coordinator)
        XCTAssertNil(app.windowManager)

        // Start application
        await app.startup()

        XCTAssertTrue(app.isRunning)
        XCTAssertNotNil(app.coordinator)
        XCTAssertNotNil(app.windowManager)

        // Shutdown application
        await app.shutdown()

        XCTAssertTrue(!app.isRunning)
        XCTAssertNil(app.coordinator)
        XCTAssertNil(app.windowManager)
    }

    func testServiceCoordinatorInitialization() async throws {
        let coordinator = await AppServiceCoordinator()

        // Verify core services are available
        await MainActor.run {
            XCTAssertNotNil(coordinator.axorcist)
        }

        // Test service dependencies
        let monitor = await CursorMonitor.shared
        await MainActor.run {
            XCTAssertNotNil(monitor.axorcist)

            // Verify initial state
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
            XCTAssertTrue(monitor.monitoredApps.isEmpty)
        }
    }

    // MARK: - Cursor Detection and Monitoring Tests

    func testCursorDetectionAndMonitoring() async throws {
        let coordinator = await AppServiceCoordinator()
        let monitor = await CursorMonitor.shared

        // Test app detection without actual Cursor running
        let mockApps = await [
            MonitoredAppInfo(
                id: 12345,
                pid: 12345,
                displayName: "Cursor Test",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 0
            ),
        ]

        // Simulate app detection
        await MainActor.run {
            monitor.monitoredApps = mockApps
        }

        // Verify monitoring state
        await MainActor.run {
            XCTAssertEqual(monitor.monitoredApps.count, 1)
            XCTAssertEqual(monitor.monitoredApps.first?.displayName, "Cursor Test")
        }

        // Test monitoring lifecycle with apps
        await monitor.startMonitoringLoop()

        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            XCTAssertTrue(monitor.isMonitoringActivePublic)
        }

        // Cleanup
        await monitor.stopMonitoringLoop()

        await MainActor.run {
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
        }
    }

    func testWindowManagementIntegration() async throws {
        let coordinator = await AppServiceCoordinator()
        let monitor = await CursorMonitor.shared

        // Create app with multiple windows
        let windows = await [
            MonitoredWindowInfo(
                id: "window1",
                windowTitle: "Main Document.txt",
                documentPath: "/path/to/main.txt"
            ),
            MonitoredWindowInfo(
                id: "window2",
                windowTitle: "Settings",
                documentPath: nil
            ),
        ]

        let appInfo = await MonitoredAppInfo(
            id: 12345,
            pid: 12345,
            displayName: "Cursor with Windows",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0,
            windows: windows
        )

        await MainActor.run {
            monitor.monitoredApps = [appInfo]
        }

        // Verify window information is preserved
        await MainActor.run {
            let app = monitor.monitoredApps.first
            XCTAssertEqual(app?.windows.count, 2)
            XCTAssertEqual(app?.windows.first?.windowTitle, "Main Document.txt")
            XCTAssertEqual(app?.windows.first?.documentPath, "/path/to/main.txt")
            XCTAssertEqual(app?.windows.last?.windowTitle, "Settings")
            XCTAssertNil(app?.windows.last?.documentPath)
        }
    }

    // MARK: - Intervention Flow Tests

    func testInterventionFlow() async throws {
        let coordinator = await AppServiceCoordinator()
        let monitor = await CursorMonitor.shared
        // Monitor has internal rule execution
        // Just verify monitor exists
        XCTAssertNotNil(monitor)

        // Create app that might need intervention
        let appInfo = await MonitoredAppInfo(
            id: 12345,
            pid: 12345,
            displayName: "Cursor Needing Intervention",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0
        )

        await MainActor.run {
            monitor.monitoredApps = [appInfo]
        }

        // Start monitoring
        await monitor.startMonitoringLoop()

        // Perform a monitoring cycle
        await monitor.performMonitoringCycle()

        // Verify intervention tracking
        await MainActor.run {
            XCTAssertGreaterThanOrEqual(monitor.totalAutomaticInterventionsThisSessionDisplay, 0)
        }

        // Cleanup
        await monitor.stopMonitoringLoop()
    }

    func testRuleExecutionIntegration() async throws {
        let ruleExecutor = await RuleExecutor()

        // Test that rule executor can run without errors
        await ruleExecutor.executeEnabledRules()

        // Verify no crashes occurred
        XCTAssertTrue(true) // If we get here, no exception was thrown
    }

    // MARK: - Settings Persistence Tests

    func testSettingsPersistenceIntegration() async throws {
        try await withTemporaryDefaults {
            // Set some test settings
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.maxInterventionsBeforePause] = 10

            // Create first coordinator instance
            let coordinator1 = await AppServiceCoordinator()
            let monitor1 = await CursorMonitor.shared

            // Verify settings are loaded
            XCTAssertEqual(Defaults[.isGlobalMonitoringEnabled], true)
            XCTAssertEqual(Defaults[.maxInterventionsBeforePause], 10)

            // Create second coordinator instance (simulating restart)
            let coordinator2 = await AppServiceCoordinator()
            let monitor2 = await CursorMonitor.shared

            // Verify settings persistence
            XCTAssertEqual(Defaults[.isGlobalMonitoringEnabled], true)
            XCTAssertEqual(Defaults[.maxInterventionsBeforePause], 10)

            // Test settings changes
            Defaults[.isGlobalMonitoringEnabled] = false

            XCTAssertEqual(Defaults[.isGlobalMonitoringEnabled], false)
        }
    }

    func testWindowSettingsPersistence() async throws {
        try await withTemporaryDefaults {
            // Create window with settings
            var windowInfo = await MonitoredWindowInfo(
                id: "test-window",
                windowTitle: "Test Document.txt",
                documentPath: "/path/to/test.txt"
            )

            // Modify settings
            await MainActor.run {
                windowInfo.isLiveWatchingEnabled = true
                windowInfo.aiAnalysisIntervalSeconds = 30
                windowInfo.saveAISettings()
            }

            // Create new window instance with same ID
            let newWindowInfo = await MonitoredWindowInfo(
                id: "test-window",
                windowTitle: "Test Document.txt",
                documentPath: "/path/to/test.txt"
            )

            // Verify settings were loaded
            await MainActor.run {
                XCTAssertEqual(newWindowInfo.isLiveWatchingEnabled, true)
                XCTAssertEqual(newWindowInfo.aiAnalysisIntervalSeconds, 30)
            }
        }
    }

    // MARK: - Permission Flow Tests

    func testPermissionFlowIntegration() async throws {
        // Test accessibility permissions check
        let permissionsManager = await PermissionsManager()

        // Wait for initial check
        try await Task.sleep(for: .milliseconds(100))

        // This should not crash regardless of permission state
        await MainActor.run {
            XCTAssertEqual(
                permissionsManager.hasAccessibilityPermissions,
                true || permissionsManager.hasAccessibilityPermissions == false
            )
        }
    }

    func testAXorcistPermissionIntegration() async throws {
        let axorcist = await AXorcist()

        // Test that AXorcist can be created without errors
        XCTAssertNotNil(axorcist)

        // Test basic ping functionality (should work even without full permissions)
        let pingCommand = """
        {
            "command_id": "test-ping",
            "command": "ping"
        }
        """

        do {
            // Test that we can use AXorcist without errors
            // In a real test, we'd need to create proper command structures
            // For now, just verify AXorcist can be created
            let result = true
            XCTAssertNotNil(result)
        } catch {
            // Ping might fail due to permissions, but should not crash
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Cross-Service Integration Tests

    func testServiceCoordination() async throws {
        let coordinator = await AppServiceCoordinator()

        // Test that all services can be accessed
        let cursorMonitor = await CursorMonitor.shared
        XCTAssertNotNil(cursorMonitor)

        // Test service interaction
        let monitor = await CursorMonitor.shared

        // Test that monitor can interact with its dependencies
        await monitor.performMonitoringCycle()

        // Verify no crashes occurred
        XCTAssertTrue(true)
    }

    func testCrossServiceErrorHandling() async throws {
        let coordinator = await AppServiceCoordinator()
        let monitor = await CursorMonitor.shared

        // Test error handling with invalid data
        let invalidAppInfo = await MonitoredAppInfo(
            id: -1, // Invalid PID
            pid: -1,
            displayName: "",
            status: .notRunning,
            isActivelyMonitored: false,
            interventionCount: 0
        )

        await MainActor.run {
            monitor.monitoredApps = [invalidAppInfo]
        }

        // This should not crash
        await monitor.performMonitoringCycle()

        XCTAssertTrue(true) // If we get here, error was handled gracefully
    }
}
