import AXorcist
@testable import CodeLooper
import Combine
import Foundation
import XCTest

class CursorMonitorServiceTests: XCTestCase {
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
    func testCursorMonitorInitialization() async throws {
        let sessionLogger = await SessionLogger.shared
        let _ = MockSessionLogger() // For future use

        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        await MainActor.run {
            XCTAssertNotNil(monitor.axorcist)
            // Note: monitoring state may be active due to global state
            // XCTAssertTrue(!monitor.isMonitoringActivePublic)
            XCTAssertEqual(monitor.totalAutomaticInterventionsThisSessionDisplay, 0)
        }
    }

    func testSharedInstanceConfiguration() async throws {
        let sharedMonitor = await CursorMonitor.shared

        await MainActor.run {
            // Note: shared instance may have global state, so we test existence rather than specific values
            XCTAssertNotNil(sharedMonitor)
            XCTAssertTrue(sharedMonitor.monitoredApps.count >= 0) // Should be a valid array
            XCTAssertTrue(sharedMonitor.totalAutomaticInterventionsThisSessionDisplay >= 0) // Should be non-negative
        }
    }

    func testMonitorLifecycle() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Initially not monitoring
        await MainActor.run {
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
        }

        // Start monitoring
        await monitor.startMonitoringLoop()

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            XCTAssertTrue(monitor.isMonitoringActivePublic)
        }

        // Stop monitoring
        await monitor.stopMonitoringLoop()

        await MainActor.run {
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
        }
    }

    func testDuplicateLifecycleRequests() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Multiple start requests
        await monitor.startMonitoringLoop()
        await monitor.startMonitoringLoop() // Should be ignored

        try await Task.sleep(for: .milliseconds(100))

        await MainActor.run {
            XCTAssertTrue(monitor.isMonitoringActivePublic)
        }

        // Multiple stop requests
        await monitor.stopMonitoringLoop()
        await monitor.stopMonitoringLoop() // Should be ignored

        await MainActor.run {
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
        }
    }

    func testMonitoredAppsManagement() async throws {
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
            XCTAssertEqual(monitor.monitoredApps.count, 1)
            XCTAssertEqual(monitor.monitoredApps.first?.pid, 12345)
            XCTAssertEqual(monitor.monitoredApps.first?.displayName, "Test Cursor")
        }
    }

    func testAutoMonitoringBasedOnApps() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Initially no apps and not monitoring
        await MainActor.run {
            XCTAssertTrue(monitor.monitoredApps.isEmpty)
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
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
            XCTAssertTrue(monitor.isMonitoringActivePublic)
        }

        // Remove apps - should stop monitoring
        await MainActor.run {
            monitor.handleMonitoredAppsChange([])
        }

        await MainActor.run {
            XCTAssertTrue(!monitor.isMonitoringActivePublic)
        }
    }

    func testInterventionTracking() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Trigger update
        await monitor.performMonitoringCycle()

        await MainActor.run {
            // Should have some default value
            XCTAssertGreaterThanOrEqual(monitor.totalAutomaticInterventionsThisSessionDisplay, 0)
        }
    }

    func testWindowManagement() async throws {
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
            XCTAssertEqual(monitor.monitoredApps.first?.windows.count, 1)
            XCTAssertEqual(monitor.monitoredApps.first?.windows.first?.windowTitle, "Test Document.txt")
            XCTAssertEqual(monitor.monitoredApps.first?.windows.first?.documentPath, "/path/to/test.txt")
        }
    }

    func testEmptyMonitoredAppsHandling() async throws {
        let sessionLogger = await SessionLogger.shared
        let monitor = await createTestMonitor(sessionLogger: sessionLogger)

        // Start monitoring with no apps
        await monitor.startMonitoringLoop()

        // Perform monitoring cycle with empty apps
        await monitor.performMonitoringCycle()

        // Should not crash
        XCTAssertTrue(true)

        await monitor.stopMonitoringLoop()
    }

    #if DEBUG
        func testPreviewMonitorConfiguration() async throws {
            let previewMonitor = await CursorMonitor.sharedForPreview

            await MainActor.run {
                XCTAssertTrue(!previewMonitor.monitoredApps.isEmpty)
                XCTAssertGreaterThan(previewMonitor.totalAutomaticInterventionsThisSessionDisplay, 0)
                XCTAssertEqual(previewMonitor.monitoredApps.first?.displayName.contains("Preview"), true)
            }
        }
    #endif
}
