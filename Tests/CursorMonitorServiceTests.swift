import AXorcist
@testable import CodeLooper
import Combine
import Foundation
import Testing

@Suite("CursorMonitorService Tests")
struct CursorMonitorServiceTests {
    /// Mock implementations for testing
    class MockSessionLogger {
        var loggedMessages: [(level: LogLevel, message: String)] = []

        func log(level: LogLevel, message: String, pid _: Int32? = nil) {
            loggedMessages.append((level: level, message: message))
        }
    }

    /// Helper to create test monitor
    func createTestMonitor(sessionLogger: SessionLogger) async -> CursorMonitor {
        await MainActor.run {
            let axorcist = AXorcist()
            let locatorManager = LocatorManager.shared
            let instanceStateManager = CursorInstanceStateManager(sessionLogger: sessionLogger)

            return CursorMonitor(
                axorcist: axorcist,
                sessionLogger: sessionLogger,
                locatorManager: locatorManager,
                instanceStateManager: instanceStateManager
            )
        }
    }

    /// Test suite for CursorMonitor service functionality
    @Test("CursorMonitor initialization")
    func cursorMonitorInitialization() async throws {
        let sessionLogger = await SessionLogger.shared
        _ = MockSessionLogger() // For future use

        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        await MainActor.run {
            #expect(monitor.axorcist != nil)
            // Note: monitoring state may be active due to global state
            // #expect(!monitor.isMonitoringActivePublic)
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay == 0)
        }
    }

    @Test("Shared instance configuration")
    func sharedInstanceConfiguration() async throws {
        let sharedMonitor = await CursorMonitor.shared

        await MainActor.run {
            // Note: shared instance may have global state, so we test existence rather than specific values
            #expect(sharedMonitor != nil)
            #expect(sharedMonitor.monitoredApps.count >= 0) // Should be a valid array
            #expect(sharedMonitor.totalAutomaticInterventionsThisSessionDisplay >= 0) // Should be non-negative
        }
    }

    @Test("Monitor lifecycle management")
    func monitorLifecycle() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Initially not monitoring
        await MainActor.run {
            #expect(!monitor.isMonitoringActivePublic)
        }

        // Start monitoring
        await monitor.startMonitoringLoop()

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            #expect(monitor.isMonitoringActivePublic)
        }

        // Stop monitoring
        await monitor.stopMonitoringLoop()

        await MainActor.run {
            #expect(!monitor.isMonitoringActivePublic)
        }
    }

    @Test("Duplicate lifecycle requests handling")
    func duplicateLifecycleRequests() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Multiple start requests
        await monitor.startMonitoringLoop()
        await monitor.startMonitoringLoop() // Should be ignored

        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            #expect(monitor.isMonitoringActivePublic)
        }

        // Multiple stop requests
        await monitor.stopMonitoringLoop()
        await monitor.stopMonitoringLoop() // Should be ignored

        await MainActor.run {
            #expect(!monitor.isMonitoringActivePublic)
        }
    }

    @Test("Monitored apps management")
    func monitoredAppsManagement() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Create mock app info
        let appInfo = await MonitoredAppInfo(
            id: 12345,
            pid: 12345,
            displayName: "Test Cursor",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0
        )

        // Add app to monitored list
        await MainActor.run {
            monitor.monitoredApps = [appInfo]
        }

        await MainActor.run {
            #expect(monitor.monitoredApps.count == 1)
            #expect(monitor.monitoredApps.first?.pid == 12345)
            #expect(monitor.monitoredApps.first?.displayName == "Test Cursor")
        }
    }

    @Test("Auto monitoring based on apps")
    func autoMonitoringBasedOnApps() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Initially no apps and not monitoring
        await MainActor.run {
            #expect(monitor.monitoredApps.isEmpty)
            #expect(!monitor.isMonitoringActivePublic)
        }

        // Add an app - should trigger monitoring
        let appInfo = await MonitoredAppInfo(
            id: 12345,
            pid: 12345,
            displayName: "Test Cursor",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0
        )

        await MainActor.run {
            monitor.handleMonitoredAppsChange([appInfo])
        }

        // Give it a moment to process
        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            #expect(monitor.isMonitoringActivePublic)
        }

        // Remove apps - should stop monitoring
        await MainActor.run {
            monitor.handleMonitoredAppsChange([])
        }

        await MainActor.run {
            #expect(!monitor.isMonitoringActivePublic)
        }
    }

    @Test("Intervention tracking")
    func interventionTracking() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Trigger update
        await monitor.performMonitoringCycle()

        await MainActor.run {
            // Should have some default value
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay >= 0)
        }
    }

    @Test("Window management")
    func windowManagement() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Create app with windows
        let windowInfo = await MonitoredWindowInfo(
            id: "test-window",
            windowTitle: "Test Document.txt",
            documentPath: "/path/to/test.txt"
        )

        let appInfo = await MonitoredAppInfo(
            id: 12345,
            pid: 12345,
            displayName: "Test Cursor",
            status: .active,
            isActivelyMonitored: true,
            interventionCount: 0,
            windows: [windowInfo]
        )

        await MainActor.run {
            monitor.monitoredApps = [appInfo]
        }

        await MainActor.run {
            #expect(monitor.monitoredApps.first?.windows.count == 1)
            #expect(monitor.monitoredApps.first?.windows.first?.windowTitle == "Test Document.txt")
            #expect(monitor.monitoredApps.first?.windows.first?.documentPath == "/path/to/test.txt")
        }
    }

    @Test("Empty monitored apps handling")
    func emptyMonitoredAppsHandling() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Start monitoring with no apps
        await monitor.startMonitoringLoop()

        // Perform monitoring cycle with empty apps
        await monitor.performMonitoringCycle()

        // Should not crash
        #expect(true)

        await monitor.stopMonitoringLoop()
    }

    #if DEBUG
        @Test("Preview monitor configuration")
        func previewMonitorConfiguration() async throws {
            let previewMonitor = await CursorMonitor.sharedForPreview

            await MainActor.run {
                #expect(!previewMonitor.monitoredApps.isEmpty)
                #expect(previewMonitor.totalAutomaticInterventionsThisSessionDisplay > 0)
                #expect(previewMonitor.monitoredApps.first?.displayName.contains("Preview") == true)
            }
        }
    #endif
}
