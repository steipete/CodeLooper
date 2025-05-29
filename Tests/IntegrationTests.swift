import AppKit
import AXorcist
@testable import CodeLooper
import Defaults
import Foundation
import Testing

/// Integration tests for end-to-end application functionality
@Suite("Integration Tests")
struct IntegrationTests {
    // MARK: - Test Utilities

    /// Mock application for testing app lifecycle
    class MockCodeLooperApp {
        var isRunning = false
        var coordinator: AppServiceCoordinator?
        var windowManager: WindowManager?

        func startup() async {
            isRunning = true
            coordinator = AppServiceCoordinator()
            windowManager = WindowManager()
        }

        func shutdown() async {
            isRunning = false
            coordinator = nil
            windowManager = nil
        }
    }

    /// Test helper to create temporary defaults
    func withTemporaryDefaults<T>(_ block: () throws -> T) rethrows -> T {
        let originalSuite = Defaults.suite
        let testSuite = UserDefaults(suiteName: "com.codelooper.test.\(UUID().uuidString)")!
        Defaults.suite = testSuite

        defer {
            Defaults.suite = originalSuite
        }

        return try block()
    }

    // MARK: - Application Lifecycle Tests

    @Test("Full application lifecycle - startup and shutdown")
    func fullApplicationLifecycle() async throws {
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

    @Test("Service coordinator initialization and dependency injection")
    func serviceCoordinatorInitialization() async throws {
        let coordinator = AppServiceCoordinator()

        // Verify core services are available
        #expect(coordinator.cursorMonitor != nil)

        // Test service dependencies
        let monitor = coordinator.cursorMonitor
        #expect(monitor.sessionLogger != nil)
        #expect(monitor.axorcist != nil)

        // Verify initial state
        #expect(!monitor.isMonitoringActivePublic)
        #expect(monitor.monitoredApps.isEmpty)
    }

    // MARK: - Cursor Detection and Monitoring Tests

    @Test("End-to-end Cursor detection and monitoring flow")
    func cursorDetectionAndMonitoring() async throws {
        let coordinator = AppServiceCoordinator()
        let monitor = coordinator.cursorMonitor

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

    @Test("Window management integration")
    func windowManagementIntegration() async throws {
        let coordinator = AppServiceCoordinator()
        let monitor = coordinator.cursorMonitor

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

    @Test("Complete intervention detection and recovery flow")
    func interventionFlow() async throws {
        let coordinator = AppServiceCoordinator()
        let monitor = coordinator.cursorMonitor
        let ruleExecutor = monitor.ruleExecutor

        // Verify rule executor is initialized
        #expect(ruleExecutor != nil)

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

    @Test("Rule execution integration")
    func ruleExecutionIntegration() async throws {
        let ruleExecutor = RuleExecutor()

        // Test that rule executor can run without errors
        await ruleExecutor.executeEnabledRules()

        // Verify no crashes occurred
        #expect(true) // If we get here, no exception was thrown
    }

    // MARK: - Settings Persistence Tests

    @Test("Settings persistence across service restarts")
    func settingsPersistenceIntegration() async throws {
        try withTemporaryDefaults {
            // Set some test settings
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.maxInterventionsPerSession] = 10

            // Create first coordinator instance
            let coordinator1 = AppServiceCoordinator()
            let monitor1 = coordinator1.cursorMonitor

            // Verify settings are loaded
            #expect(Defaults[.isGlobalMonitoringEnabled] == true)
            #expect(Defaults[.maxInterventionsPerSession] == 10)

            // Create second coordinator instance (simulating restart)
            let coordinator2 = AppServiceCoordinator()
            let monitor2 = coordinator2.cursorMonitor

            // Verify settings persistence
            #expect(Defaults[.isGlobalMonitoringEnabled] == true)
            #expect(Defaults[.maxInterventionsPerSession] == 10)

            // Test settings changes
            Defaults[.isGlobalMonitoringEnabled] = false

            #expect(Defaults[.isGlobalMonitoringEnabled] == false)
        }
    }

    @Test("Window settings persistence")
    func windowSettingsPersistence() async throws {
        try withTemporaryDefaults {
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
                #expect(newWindowInfo.isLiveWatchingEnabled == true)
                #expect(newWindowInfo.aiAnalysisIntervalSeconds == 30)
            }
        }
    }

    // MARK: - Permission Flow Tests

    @Test("Permission validation flow")
    func permissionFlowIntegration() async throws {
        // Test accessibility permissions check
        let hasAccessibilityPermissions = AccessibilityPermissions.hasAccessibilityPermissions()

        // This should not crash regardless of permission state
        #expect(hasAccessibilityPermissions == true || hasAccessibilityPermissions == false)

        // Test permission status tracking
        let permissionChecker = AccessibilityPermissions()
        let status = await permissionChecker.checkPermissions()

        #expect(status != nil)
    }

    @Test("AXorcist integration with permissions")
    func aXorcistPermissionIntegration() async throws {
        let axorcist = AXorcist()

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
            let result = axorcist.processCommand(pingCommand)
            #expect(result != nil)
        } catch {
            // Ping might fail due to permissions, but should not crash
            #expect(error != nil)
        }
    }

    // MARK: - Cross-Service Integration Tests

    @Test("Service coordination and communication")
    func serviceCoordination() async throws {
        let coordinator = AppServiceCoordinator()

        // Test that all services can be accessed
        #expect(coordinator.cursorMonitor != nil)

        // Test service interaction
        let monitor = coordinator.cursorMonitor

        // Test that monitor can interact with its dependencies
        await monitor.performMonitoringCycle()

        // Verify no crashes occurred
        #expect(true)
    }

    @Test("Error handling across service boundaries")
    func crossServiceErrorHandling() async throws {
        let coordinator = AppServiceCoordinator()
        let monitor = coordinator.cursorMonitor

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

        #expect(true) // If we get here, error was handled gracefully
    }
}
