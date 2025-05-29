import AXorcist
@testable import CodeLooper
import Combine
import Foundation
import Testing

/// Test suite for CursorMonitor service functionality
@Suite("CursorMonitor Tests")
struct CursorMonitorServiceTests {
    /// Mock implementations for testing
    class MockSessionLogger: SessionLogger {
        var loggedMessages: [(level: LogLevel, message: String)] = []

        override func log(level: LogLevel, message: String) {
            loggedMessages.append((level: level, message: message))
        }
    }

    class MockLocatorManager: LocatorManager {
        override init() {
            super.init()
        }
    }

    class MockCursorInstanceStateManager: CursorInstanceStateManager {
        // MARK: Lifecycle

        override init(sessionLogger: SessionLogger) {
            super.init(sessionLogger: sessionLogger)
        }

        // MARK: Internal

        var totalInterventions: Int = 0

        override func getTotalAutomaticInterventionsThisSession() -> Int {
            totalInterventions
        }
    }

    // MARK: - Initialization Tests

    @Test("CursorMonitor can be initialized with required dependencies")
    func cursorMonitorInitialization() async throws {
        let axorcist = AXorcist()
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: axorcist,
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

        await MainActor.run {
            #expect(monitor.axorcist === axorcist)
            #expect(!monitor.isMonitoringActivePublic)
            #expect(monitor.monitoredApps.isEmpty)
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay == 0)
        }

        // Verify initialization logging
        #expect(sessionLogger.loggedMessages.contains { $0.message.contains("CursorMonitor initialized") })
    }

    @Test("CursorMonitor shared instance is properly configured")
    func sharedInstanceConfiguration() async throws {
        let sharedMonitor = await CursorMonitor.shared

        await MainActor.run {
            #expect(!sharedMonitor.isMonitoringActivePublic)
            #expect(sharedMonitor.monitoredApps.isEmpty)
            #expect(sharedMonitor.totalAutomaticInterventionsThisSessionDisplay == 0)
        }
    }

    // MARK: - Monitoring Lifecycle Tests

    @Test("Monitor lifecycle - start and stop monitoring loop")
    func monitorLifecycle() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

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

        // Verify lifecycle logging
        #expect(sessionLogger.loggedMessages.contains { $0.message.contains("Starting monitoring loop") })
        #expect(sessionLogger.loggedMessages.contains { $0.message.contains("Stopping monitoring loop") })
    }

    @Test("Monitor handles duplicate start/stop requests gracefully")
    func duplicateLifecycleRequests() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

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

    // MARK: - App Management Tests

    @Test("Monitor manages monitored apps list")
    func monitoredAppsManagement() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

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

    @Test("Monitor automatically starts/stops based on monitored apps")
    func autoMonitoringBasedOnApps() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

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

    // MARK: - Intervention Tracking Tests

    @Test("Monitor tracks intervention counts correctly")
    func interventionTracking() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

        // Set up mock intervention count
        instanceStateManager.totalInterventions = 5

        // Trigger update
        await monitor.performMonitoringCycle()

        await MainActor.run {
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay == 5)
        }
    }

    // MARK: - Window Management Tests

    @Test("Monitor handles window information correctly")
    func windowManagement() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

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

    // MARK: - Error Handling Tests

    @Test("Monitor handles empty monitored apps gracefully")
    func emptyMonitoredAppsHandling() async throws {
        let sessionLogger = MockSessionLogger()
        let locatorManager = MockLocatorManager()
        let instanceStateManager = MockCursorInstanceStateManager(sessionLogger: sessionLogger)

        let monitor = await CursorMonitor(
            axorcist: AXorcist(),
            sessionLogger: sessionLogger,
            locatorManager: locatorManager,
            instanceStateManager: instanceStateManager
        )

        // Start monitoring with no apps
        await monitor.startMonitoringLoop()

        // Perform monitoring cycle with empty apps
        await monitor.performMonitoringCycle()

        // Should not crash and should log appropriately
        #expect(sessionLogger.loggedMessages.contains { $0.message.contains("No monitored apps") })

        await monitor.stopMonitoringLoop()
    }

    #if DEBUG
        @Test("Preview monitor is properly configured")
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
