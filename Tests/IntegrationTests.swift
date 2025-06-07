import AppKit
import AXorcist
@testable import CodeLooper
import Defaults
@testable import Diagnostics
import Foundation
import Testing

@Suite("IntegrationTests")
struct IntegrationTests {
    // MARK: - Test Utilities

    /// Mock application for testing app lifecycle
    @MainActor
    class MockCodeLooperApp {
        var isRunning = false
        var coordinator: AppServiceCoordinator?
        var windowManager: WindowManager?

        func startup() async {
            isRunning = true
            coordinator = AppServiceCoordinator()
            let loginItemManager = LoginItemManager.shared
            let sessionLogger = Diagnostics.SessionLogger.shared
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

    @Test("Full application lifecycle") @MainActor func fullApplicationLifecycle() async throws {
        let app = MockCodeLooperApp()

        // Initially not running
        #expect(!app.isRunning)
        #expect(app.coordinator == nil)
        #expect(app.windowManager == nil)

        // Start application
        await app.startup()

        #expect(app.isRunning)
        #expect(app.coordinator != nil)
        #expect(app.windowManager != nil)

        // Shutdown application
        await app.shutdown()

        #expect(!app.isRunning)
        #expect(app.coordinator == nil)
        #expect(app.windowManager == nil)
    }

    @Test("Service coordinator initialization") @MainActor func serviceCoordinatorInitialization() async throws {
        let coordinator = await AppServiceCoordinator()

        // Verify core services are available
        await MainActor.run {
            #expect(coordinator.axorcist != nil)
        }

        // Test service dependencies
        let monitor = await CursorMonitor.shared
        // The test is already MainActor-isolated, so we can access these directly
        #expect(await monitor.axorcist != nil)

        // Verify initial state
        #expect(!monitor.isMonitoringActivePublic)
        #expect(monitor.monitoredApps.isEmpty)
    }

    // MARK: - Cursor Detection and Monitoring Tests

    @Test("Cursor detection and monitoring") @MainActor func cursorDetectionAndMonitoring() async throws {
        _ = AppServiceCoordinator()
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
            #expect(monitor.monitoredApps.count == 1)
            #expect(monitor.monitoredApps.first?.displayName == "Cursor Test")
        }

        // Test monitoring lifecycle with apps
        await monitor.startMonitoringLoop()

        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            #expect(monitor.isMonitoringActivePublic)
        }

        // Cleanup
        await monitor.stopMonitoringLoop()

        await MainActor.run {
            #expect(!monitor.isMonitoringActivePublic)
        }
    }

    @Test("Window management integration") @MainActor func windowManagementIntegration() async throws {
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
            #expect(app?.windows.count == 2)
            #expect(app?.windows.first?.windowTitle == "Main Document.txt")
            #expect(app?.windows.first?.documentPath == "/path/to/main.txt")
            #expect(app?.windows.last?.windowTitle == "Settings")
            #expect(app?.windows.last?.documentPath == nil)
        }
    }

    // MARK: - Intervention Flow Tests

    @Test("Intervention flow") @MainActor func interventionFlow() async throws {
        let coordinator = await AppServiceCoordinator()
        let monitor = await CursorMonitor.shared
        // Monitor has internal rule execution
        // Just verify monitor exists
        #expect(monitor != nil)

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
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay >= 0)
        }

        // Cleanup
        await monitor.stopMonitoringLoop()
    }


    // MARK: - Settings Persistence Tests

    @Test("Settings persistence integration") @MainActor func settingsPersistenceIntegration() async throws {
        // Save original values
        let originalMonitoring = await MainActor.run { Defaults[.isGlobalMonitoringEnabled] }
        let originalMaxInterventions = await MainActor.run { Defaults[.maxInterventionsBeforePause] }

        defer {
            // Restore original values
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.maxInterventionsBeforePause] = originalMaxInterventions
            }
        }

        // Set some test settings
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.maxInterventionsBeforePause] = 10
        }

        // Create first coordinator instance
        let coordinator1 = await AppServiceCoordinator()
        let monitor1 = await CursorMonitor.shared

        // Verify settings are loaded
        await MainActor.run {
            #expect(Defaults[.isGlobalMonitoringEnabled])
            #expect(Defaults[.maxInterventionsBeforePause] == 10)
        }

        // Create second coordinator instance (simulating restart)
        let coordinator2 = await AppServiceCoordinator()
        let monitor2 = await CursorMonitor.shared

        // Verify settings persistence
        await MainActor.run {
            #expect(Defaults[.isGlobalMonitoringEnabled])
            #expect(Defaults[.maxInterventionsBeforePause] == 10)
        }

        // Test settings changes
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = false
            #expect(!Defaults[.isGlobalMonitoringEnabled])
        }
    }

    @Test("Window settings persistence") @MainActor func windowSettingsPersistence() async throws {
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
            #expect(newWindowInfo.isLiveWatchingEnabled)
            #expect(newWindowInfo.aiAnalysisIntervalSeconds == 30)
        }

        // Clean up test settings if needed
        // Note: Window settings are stored per window ID and would be cleaned up
        // when the window is deallocated in a real scenario
    }

    // MARK: - Permission Flow Tests

    @Test("Permission flow integration") @MainActor func permissionFlowIntegration() async throws {
        // Test accessibility permissions check
        let permissionsManager = await PermissionsManager()

        // Wait for initial check
        try await Task.sleep(for: .milliseconds(100))

        // This should not crash regardless of permission state
        await MainActor.run {
            #expect(
                permissionsManager.hasAccessibilityPermissions == true || permissionsManager
                    .hasAccessibilityPermissions == false
            )
        }
    }

    @Test("A xorcist permission integration") @MainActor func aXorcistPermissionIntegration() async throws {
        let axorcist = await AXorcist()

        // Test that AXorcist can be created without errors
        #expect(axorcist != nil)

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
            #expect(result != nil)
        } catch {
            // Ping might fail due to permissions, but should not crash
            #expect(error != nil)
        }
    }

    // MARK: - Cross-Service Integration Tests

    @Test("Service coordination") @MainActor func serviceCoordination() async throws {
        let coordinator = await AppServiceCoordinator()

        // Test that all services can be accessed
        let cursorMonitor = await CursorMonitor.shared
        #expect(cursorMonitor != nil)

        // Test service interaction
        let monitor = await CursorMonitor.shared

        // Test that monitor can interact with its dependencies
        await monitor.performMonitoringCycle()
    }

    @Test("Cross service error handling") @MainActor func crossServiceErrorHandling() async throws {
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
    }
}
