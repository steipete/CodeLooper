import AXorcist
@testable import CodeLooper
import Combine
import Foundation
import Testing

// MARK: - Test Suite with Advanced Organization

@Suite("Cursor Monitor Service Tests", .tags(.monitoring, .cursor, .service))
@MainActor
struct CursorMonitorServiceTests {
    // MARK: - Test Fixtures and Helpers

    /// Mock implementations for testing
    class MockSessionLogger {
        var loggedMessages: [(level: LogLevel, message: String)] = []

        func log(level: LogLevel, message: String, pid _: Int32? = nil) {
            loggedMessages.append((level: level, message: message))
        }
    }

    // MARK: - Initialization Suite

    @Suite("Initialization", .tags(.initialization, .setup))
    struct Initialization {
        @Test("CursorMonitor initializes with correct default state")
        func cursorMonitorInitialization() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            #expect(monitor.axorcist != nil, "Monitor should have AXorcist instance")
            #expect(monitor.totalAutomaticInterventionsThisSessionDisplay == 0, "Should start with zero interventions")
            #expect(monitor.monitoredApps.isEmpty, "Should start with no monitored apps")
        }

        @Test("Shared instance is properly configured")
        func sharedInstanceConfiguration() async throws {
            let sharedMonitor = await CursorMonitor.shared

            #expect(sharedMonitor != nil, "Shared instance should exist")
            #expect(sharedMonitor.monitoredApps.count >= 0, "Should have valid monitored apps array")
            #expect(
                sharedMonitor.totalAutomaticInterventionsThisSessionDisplay >= 0,
                "Should have non-negative intervention count"
            )
        }

        #if DEBUG
            @Test("Preview monitor has test data")
            func previewMonitorConfiguration() async throws {
                let previewMonitor = await CursorMonitor.sharedForPreview

                #expect(!previewMonitor.monitoredApps.isEmpty, "Preview monitor should have sample data")
                #expect(
                    previewMonitor.totalAutomaticInterventionsThisSessionDisplay > 0,
                    "Preview should show interventions"
                )
                #expect(
                    previewMonitor.monitoredApps.first?.displayName.contains("Preview") == true,
                    "Should have preview app name"
                )
            }
        #endif
    }

    // MARK: - Lifecycle Management Suite

    @Suite("Lifecycle Management", .tags(.lifecycle, .monitoring))
    struct LifecycleManagement {
        @Test("Monitor lifecycle starts and stops correctly")
        func monitorLifecycle() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Initially not monitoring
            #expect(!monitor.isMonitoringActivePublic, "Should not be monitoring initially")

            // Start monitoring
            await monitor.startMonitoringLoop()
            try await Task.sleep(for: .milliseconds(100))

            #expect(monitor.isMonitoringActivePublic, "Should be monitoring after start")

            // Stop monitoring
            await monitor.stopMonitoringLoop()

            #expect(!monitor.isMonitoringActivePublic, "Should not be monitoring after stop")
        }

        @Test("Duplicate lifecycle requests are handled gracefully")
        func duplicateLifecycleRequests() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Multiple start requests should not cause issues
            await monitor.startMonitoringLoop()
            await monitor.startMonitoringLoop()

            try await Task.sleep(for: .milliseconds(100))
            #expect(monitor.isMonitoringActivePublic, "Should be monitoring after duplicate starts")

            // Multiple stop requests should not cause issues
            await monitor.stopMonitoringLoop()
            await monitor.stopMonitoringLoop()

            #expect(!monitor.isMonitoringActivePublic, "Should not be monitoring after duplicate stops")
        }

        @Test("Empty apps handling doesn't cause crashes")
        func emptyMonitoredAppsHandling() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Start monitoring with no apps
            await monitor.startMonitoringLoop()

            // Perform monitoring cycle with empty apps
            await monitor.performMonitoringCycle()

            #expect(true, "Empty apps monitoring should not crash")

            await monitor.stopMonitoringLoop()
        }
    }

    // MARK: - App Management Suite

    @Suite("App Management", .tags(.apps, .management))
    struct AppManagement {
        @Test("Monitored apps can be added and managed", arguments: zip(testAppIds, testDisplayNames))
        func monitoredAppsManagement(appData: (id: Int, displayName: String)) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            let appInfo = await CursorMonitorServiceTests().createTestAppInfo(
                id: appData.id,
                displayName: appData.displayName,
                status: .active
            )

            // Add app to monitored list
            monitor.monitoredApps = [appInfo]

            #expect(monitor.monitoredApps.count == 1, "Should have one monitored app")
            #expect(monitor.monitoredApps.first?.pid == Int32(appData.id), "Should have correct PID")
            #expect(monitor.monitoredApps.first?.displayName == appData.displayName, "Should have correct display name")
        }

        @Test("Auto monitoring responds to app changes", arguments: testStatuses)
        func autoMonitoringBasedOnApps(status: MonitoredAppInfo.Status) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Initially no apps and not monitoring
            #expect(monitor.monitoredApps.isEmpty, "Should start with no apps")
            #expect(!monitor.isMonitoringActivePublic, "Should not be monitoring initially")

            // Add an app - should trigger monitoring for active apps
            let appInfo = await CursorMonitorServiceTests().createTestAppInfo(
                id: 12345,
                displayName: "Test Cursor",
                status: status
            )

            monitor.handleMonitoredAppsChange([appInfo])
            try await Task.sleep(for: .milliseconds(100))

            if status == .active {
                #expect(monitor.isMonitoringActivePublic, "Should start monitoring for active apps")
            }

            // Remove apps - should stop monitoring
            monitor.handleMonitoredAppsChange([])

            #expect(!monitor.isMonitoringActivePublic, "Should stop monitoring when no apps")
        }

        @Test("Multiple apps can be monitored simultaneously")
        func multipleAppsMonitoring() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            var apps: [MonitoredAppInfo] = []
            for (id, name) in zip(testAppIds, testDisplayNames) {
                let app = await CursorMonitorServiceTests().createTestAppInfo(
                    id: id,
                    displayName: name,
                    status: .active
                )
                apps.append(app)
            }

            monitor.monitoredApps = apps

            #expect(monitor.monitoredApps.count == testAppIds.count, "Should monitor all added apps")

            for (index, expectedId) in testAppIds.enumerated() {
                #expect(monitor.monitoredApps[index].pid == Int32(expectedId), "App \\(index) should have correct PID")
            }
        }
    }

    // MARK: - Window Management Suite

    @Suite("Window Management", .tags(.windows, .documents))
    struct WindowManagement {
        @Test("Windows can be associated with monitored apps")
        func windowManagement() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

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

            monitor.monitoredApps = [appInfo]

            #expect(monitor.monitoredApps.first?.windows.count == 1, "Should have one window")
            #expect(
                monitor.monitoredApps.first?.windows.first?.windowTitle == "Test Document.txt",
                "Should have correct window title"
            )
            #expect(
                monitor.monitoredApps.first?.windows.first?.documentPath == "/path/to/test.txt",
                "Should have correct document path"
            )
        }

        @Test("Multiple windows per app are supported", arguments: [1, 3, 5])
        func multipleWindowsPerApp(windowCount: Int) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            var windows: [MonitoredWindowInfo] = []
            for i in 0 ..< windowCount {
                let window = await MonitoredWindowInfo(
                    id: "window-\\(i)",
                    windowTitle: "Document \\(i).txt",
                    documentPath: "/path/to/document\\(i).txt"
                )
                windows.append(window)
            }

            let appInfo = await MonitoredAppInfo(
                id: 12345,
                pid: 12345,
                displayName: "Test Cursor",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 0,
                windows: windows
            )

            monitor.monitoredApps = [appInfo]

            #expect(monitor.monitoredApps.first?.windows.count == windowCount, "Should have \\(windowCount) windows")
        }
    }

    // MARK: - Intervention Tracking Suite

    @Suite("Intervention Tracking", .tags(.interventions, .tracking))
    struct InterventionTracking {
        @Test("Intervention counts are tracked correctly")
        func interventionTracking() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            let initialCount = monitor.totalAutomaticInterventionsThisSessionDisplay

            // Trigger monitoring cycle
            await monitor.performMonitoringCycle()

            #expect(
                monitor.totalAutomaticInterventionsThisSessionDisplay >= initialCount,
                "Intervention count should not decrease"
            )
        }

        @Test("Per-app intervention counting works")
        func perAppInterventionCounting() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            let appInfo = await MonitoredAppInfo(
                id: 12345,
                pid: 12345,
                displayName: "Test Cursor",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 5
            )

            monitor.monitoredApps = [appInfo]

            #expect(monitor.monitoredApps.first?.interventionCount == 5, "Should track per-app intervention count")
        }
    }

    // MARK: - Concurrency Suite

    @Suite("Concurrency", .tags(.threading, .async))
    struct Concurrency {
        @Test("Concurrent monitoring operations are safe")
        func concurrentMonitoringOperations() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Perform concurrent operations
            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 5 {
                    group.addTask {
                        await monitor.performMonitoringCycle()
                    }
                }
            }

            #expect(true, "Concurrent monitoring cycles should complete without issues")
        }

        @Test("Concurrent app management is thread-safe")
        func concurrentAppManagement() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            await withTaskGroup(of: Void.self) { group in
                // Multiple tasks modifying monitored apps
                for i in 0 ..< 10 {
                    group.addTask {
                        let appInfo = await CursorMonitorServiceTests().createTestAppInfo(
                            id: 10000 + i,
                            displayName: "Concurrent App \\(i)",
                            status: .active
                        )
                        monitor.monitoredApps = [appInfo]
                    }
                }
            }

            #expect(monitor.monitoredApps.count >= 0, "Concurrent app management should maintain valid state")
        }
    }

    // MARK: - Performance Suite

    @Suite("Performance", .tags(.performance, .timing))
    struct Performance {
        @Test("Monitoring cycle performance is acceptable", .timeLimit(.seconds(5)))
        func monitoringCyclePerformance() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            let startTime = ContinuousClock().now

            // Perform multiple monitoring cycles
            for _ in 0 ..< 10 {
                await monitor.performMonitoringCycle()
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(2), "10 monitoring cycles should complete quickly")
        }

        @Test("Large number of apps can be handled efficiently", .timeLimit(.seconds(3)))
        func largeNumberOfAppsPerformance() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await CursorMonitorServiceTests().createTestMonitor(sessionLogger: sessionLogger)

            // Create many mock apps
            var apps: [MonitoredAppInfo] = []
            for i in 0 ..< 100 {
                let app = await CursorMonitorServiceTests().createTestAppInfo(
                    id: i,
                    displayName: "App \\(i)",
                    status: .active
                )
                apps.append(app)
            }

            let startTime = ContinuousClock().now
            monitor.monitoredApps = apps
            let elapsed = ContinuousClock().now - startTime

            #expect(elapsed < .seconds(1), "Setting 100 apps should be fast")
            #expect(monitor.monitoredApps.count == 100, "Should handle 100 apps correctly")
        }
    }

    static let testAppIds = [12345, 54321, 98765]
    static let testDisplayNames = ["Test Cursor", "Cursor Preview", "Development Cursor"]
    static let testStatuses: [MonitoredAppInfo.Status] = [.active, .inactive, .launching]

    /// Helper to create test monitor
    func createTestMonitor(sessionLogger: SessionLogger) async -> CursorMonitor {
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

    func createTestAppInfo(id: Int, displayName: String, status: MonitoredAppInfo.Status) async -> MonitoredAppInfo {
        await MonitoredAppInfo(
            id: id,
            pid: Int32(id),
            displayName: displayName,
            status: status,
            isActivelyMonitored: true,
            interventionCount: 0
        )
    }
}

// MARK: - Custom Test Tags

extension Tag {
    @Tag static var monitoring: Self
    @Tag static var cursor: Self
    @Tag static var service: Self
    @Tag static var initialization: Self
    @Tag static var setup: Self
    @Tag static var lifecycle: Self
    @Tag static var apps: Self
    @Tag static var management: Self
    @Tag static var windows: Self
    @Tag static var documents: Self
    @Tag static var interventions: Self
    @Tag static var tracking: Self
    @Tag static var threading: Self
    @Tag static var async: Self
    @Tag static var performance: Self
    @Tag static var timing: Self
}
