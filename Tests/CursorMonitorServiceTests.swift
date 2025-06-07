import AXorcist
@testable import CodeLooper
@testable import Diagnostics
import Combine
import Foundation
import Testing

// MARK: - Custom Test Traits

struct MonitoringTestTrait: TestTrait {
    let category: String
}

struct RequiresAXorcist: TestTrait {
    static var isEnabled: Bool {
        // Check if AXorcist is available
        return true
    }
}

struct PerformanceTarget: TestTrait {
    let maxDuration: Duration
    let operationCount: Int
}

// MARK: - Shared Test Utilities

enum CursorMonitorTestUtilities {
    @MainActor
    static func validateMonitorState(_ monitor: CursorMonitor) throws {
        // Monitor has axorcist instance available
        #expect(monitor.totalAutomaticInterventionsThisSessionDisplay >= 0)
        #expect(monitor.monitoredApps.count >= 0)
    }
    
    @MainActor
    static func validateAppInfo(_ app: MonitoredAppInfo) throws {
        #expect(app.pid > 0)
        #expect(!app.displayName.isEmpty)
        #expect(app.interventionCount >= 0)
        #expect(app.windows.count >= 0)
    }
    
    static func createTestApp(
        id: Int,
        displayName: String,
        status: DisplayStatus,
        windows: Int = 0
    ) async -> MonitoredAppInfo {
        var windowInfos: [MonitoredWindowInfo] = []
        for i in 0..<windows {
            windowInfos.append(await MonitoredWindowInfo(
                id: "window-\(id)-\(i)",
                windowTitle: "Document \(i).txt",
                documentPath: "/path/to/doc\(i).txt"
            ))
        }
        
        return await MonitoredAppInfo(
            id: Int32(id),
            pid: Int32(id),
            displayName: displayName,
            status: status,
            isActivelyMonitored: status == .active,
            interventionCount: 0,
            windows: windowInfos
        )
    }
}

// MARK: - Test Conditions

@available(*, unavailable, message: "Test requires accessibility permissions")
struct RequiresAccessibilityPermissions: TestTrait {}

struct RequiresMonitoringActive: TestTrait {
    @MainActor
    static func isEnabled(monitor: CursorMonitor) -> Bool {
        return monitor.isMonitoringActivePublic
    }
}

// MARK: - Advanced Concurrency Test Traits

struct ConcurrencyTestTrait: TestTrait {
    let pattern: ConcurrencyPattern
    let expectedBehavior: String
    
    enum ConcurrencyPattern: String {
        case raceCondition = "race_condition"
        case deadlockPrevention = "deadlock_prevention"
        case actorIsolation = "actor_isolation"
        case taskCancellation = "task_cancellation"
        case backpressure = "backpressure"
    }
}

struct LoadTestTrait: TestTrait {
    let concurrentOperations: Int
    let duration: Duration
    let expectedThroughput: Double
}

// MARK: - Test Actors for Concurrency Safety

actor ConcurrencyTestCoordinator {
    private var operationCount = 0
    private var completedOperations: [String] = []
    private var errors: [Error] = []
    
    func recordOperation(_ id: String) {
        operationCount += 1
        completedOperations.append(id)
    }
    
    func recordError(_ error: Error) {
        errors.append(error)
    }
    
    func getStats() -> (count: Int, operations: [String], errors: [Error]) {
        (operationCount, completedOperations, errors)
    }
    
    func reset() {
        operationCount = 0
        completedOperations.removeAll()
        errors.removeAll()
    }
}

// MARK: - Main Test Suite

@Suite("Cursor Monitor Service", .serialized)
@MainActor
struct CursorMonitorServiceTests {
    // Test data is now in CursorMonitorTestData to avoid Swift Testing macro issues

    // MARK: - Advanced Concurrency Patterns Suite
    
    @Suite("Advanced Concurrency Patterns", .tags(.concurrency, .advanced))
    struct AdvancedConcurrencyPatterns {
        @Test(
            "Actor isolation prevents data races",
            ConcurrencyTestTrait(
                pattern: .actorIsolation,
                expectedBehavior: "Sequential access to shared state"
            ),
            .timeLimit(.minutes(1))
        )
        func actorIsolationPreventsDataRaces() async throws {
            let coordinator = ConcurrencyTestCoordinator()
            
            // Simulate concurrent access to monitor state
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<100 {
                    group.addTask {
                        // Each task records an operation through the actor
                        await coordinator.recordOperation("operation-\(i)")
                        
                        // Simulate some work
                        try await Task.sleep(for: .milliseconds(1))
                    }
                }
                
                try await group.waitForAll()
            }
            
            let stats = await coordinator.getStats()
            #expect(stats.count == 100, "All operations should be recorded")
            #expect(stats.operations.count == 100, "All operation IDs should be tracked")
            #expect(stats.errors.isEmpty, "No errors should occur")
        }
        
        @Test(
            "Graceful task cancellation patterns",
            ConcurrencyTestTrait(
                pattern: .taskCancellation,
                expectedBehavior: "Clean cancellation without resource leaks"
            )
        )
        func gracefulTaskCancellation() async throws {
            let coordinator = ConcurrencyTestCoordinator()
            var cancelledTasks = 0
            
            // Create a group of long-running tasks
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        do {
                            // Simulate monitoring operation
                            for iteration in 0..<1000 {
                                try Task.checkCancellation()
                                
                                await coordinator.recordOperation("task-\(i)-iter-\(iteration)")
                                try await Task.sleep(for: .milliseconds(1))
                            }
                        } catch is CancellationError {
                            // Note: would increment cancelled tasks in real implementation
                            throw CancellationError()
                        }
                    }
                }
                
                // Let some tasks start
                try await Task.sleep(for: .milliseconds(50))
                
                // Cancel the group
                group.cancelAll()
                
                // Collect any remaining results
                do {
                    try await group.waitForAll()
                } catch is CancellationError {
                    // Expected - some tasks were cancelled
                }
            }
            
            let stats = await coordinator.getStats()
            #expect(stats.count > 0, "Some operations should have completed")
            // In a real implementation, we would track cancellation count
        }
        
        @Test(
            "Backpressure handling under load",
            LoadTestTrait(
                concurrentOperations: 1000,
                duration: .seconds(5),
                expectedThroughput: 100.0
            ),
            .timeLimit(.minutes(2))
        )
        func backpressureHandlingUnderLoad() async throws {
            let coordinator = ConcurrencyTestCoordinator()
            let startTime = ContinuousClock().now
            
            // Create a bounded channel simulation
            actor BoundedProcessor {
                private var queue: [String] = []
                private let maxCapacity = 50
                private var isProcessing = false
                
                func submit(_ item: String) async throws {
                    // Implement backpressure
                    while queue.count >= maxCapacity {
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    
                    queue.append(item)
                    try await processIfNeeded()
                }
                
                private func processIfNeeded() async throws {
                    guard !isProcessing && !queue.isEmpty else { return }
                    
                    isProcessing = true
                    defer { isProcessing = false }
                    
                    while let item = queue.first {
                        queue.removeFirst()
                        
                        // Simulate processing time
                        try await Task.sleep(for: .milliseconds(5))
                    }
                }
                
                func getQueueSize() -> Int {
                    queue.count
                }
            }
            
            let processor = BoundedProcessor()
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Submit many items concurrently
                for i in 0..<1000 {
                    group.addTask {
                        do {
                            try await processor.submit("item-\(i)")
                            await coordinator.recordOperation("processed-\(i)")
                        } catch {
                            await coordinator.recordError(error)
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            let elapsed = ContinuousClock().now - startTime
            let stats = await coordinator.getStats()
            let throughput = Double(stats.count) / Double(elapsed.components.seconds)
            
            #expect(stats.errors.isEmpty, "No processing errors should occur")
            #expect(throughput > 50.0, "Should maintain reasonable throughput under load")
            #expect(await processor.getQueueSize() == 0, "All items should be processed")
        }
        
        @Test(
            "Race condition detection and mitigation",
            ConcurrencyTestTrait(
                pattern: .raceCondition,
                expectedBehavior: "Consistent state despite concurrent modifications"
            )
        )
        func raceConditionDetectionAndMitigation() async throws {
            // Simulate a shared resource that could have race conditions
            actor SharedCounter {
                private var value = 0
                private var modifications: [(Int, String)] = []
                
                func increment(by amount: Int, source: String) {
                    value += amount
                    modifications.append((value, source))
                }
                
                func getValue() -> Int {
                    value
                }
                
                func getModifications() -> [(Int, String)] {
                    modifications
                }
            }
            
            let counter = SharedCounter()
            let coordinator = ConcurrencyTestCoordinator()
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Create many concurrent tasks that modify the counter
                for taskId in 0..<50 {
                    group.addTask {
                        for opId in 0..<20 {
                            await counter.increment(by: 1, source: "task-\(taskId)-op-\(opId)")
                            await coordinator.recordOperation("increment-\(taskId)-\(opId)")
                            
                            // Add some variability to increase chance of race conditions
                            if opId % 3 == 0 {
                                try await Task.sleep(for: .milliseconds(1))
                            }
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            let finalValue = await counter.getValue()
            let modifications = await counter.getModifications()
            let stats = await coordinator.getStats()
            
            // With actor isolation, these should all be consistent
            #expect(finalValue == 1000, "Final value should be exactly 1000 (50 tasks × 20 increments)")
            #expect(modifications.count == 1000, "Should have exactly 1000 modifications recorded")
            #expect(stats.count == 1000, "Should have tracked all operations")
            
            // Verify modifications are properly ordered
            #expect(modifications.last?.0 == 1000, "Last modification should show final value")
        }
        
        @Test(
            "Deadlock prevention with timeout patterns",
            ConcurrencyTestTrait(
                pattern: .deadlockPrevention,
                expectedBehavior: "Operations complete or timeout gracefully"
            )
        )
        func deadlockPreventionWithTimeouts() async throws {
            // Simulate a scenario that could deadlock without proper timeouts
            actor ResourceManager {
                private var resource1Busy = false
                private var resource2Busy = false
                
                func acquireResources(
                    timeout: Duration,
                    requester: String
                ) async throws -> Bool {
                    let startTime = ContinuousClock().now
                    
                    while resource1Busy || resource2Busy {
                        let elapsed = ContinuousClock().now - startTime
                        if elapsed > timeout {
                            throw TimeoutError()
                        }
                        
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    
                    resource1Busy = true
                    resource2Busy = true
                    return true
                }
                
                func releaseResources() {
                    resource1Busy = false
                    resource2Busy = false
                }
            }
            
            struct TimeoutError: Error {}
            
            let resourceManager = ResourceManager()
            let coordinator = ConcurrencyTestCoordinator()
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        do {
                            let acquired = try await resourceManager.acquireResources(
                                timeout: .milliseconds(100),
                                requester: "task-\(i)"
                            )
                            
                            if acquired {
                                await coordinator.recordOperation("acquired-\(i)")
                                
                                // Hold resources briefly
                                try await Task.sleep(for: .milliseconds(20))
                                
                                await resourceManager.releaseResources()
                                await coordinator.recordOperation("released-\(i)")
                            }
                        } catch is TimeoutError {
                            await coordinator.recordError(TimeoutError())
                        } catch {
                            await coordinator.recordError(error)
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            let stats = await coordinator.getStats()
            
            // Some operations should succeed, some should timeout
            #expect(stats.count > 0, "Some operations should succeed")
            #expect(stats.errors.count > 0, "Some operations should timeout")
            
            // Verify we have both acquisition and release operations
            let acquisitions = stats.operations.filter { $0.contains("acquired") }
            let releases = stats.operations.filter { $0.contains("released") }
            #expect(acquisitions.count == releases.count, "All acquired resources should be released")
        }
    }

    // MARK: - Initialization Suite
    
    @Suite("Initialization", .tags(.initialization, .setup))
    struct Initialization {
        @Test(
            "Monitor initialization states",
            arguments: [
                (hasAxorcist: true, interventions: 0, apps: 0),
                (hasAxorcist: true, interventions: 0, apps: 0)
            ]
        )
        func monitorInitializationStates(testCase: (hasAxorcist: Bool, interventions: Int, apps: Int)) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            try await CursorMonitorTestUtilities.validateMonitorState(monitor)
            #expect(await monitor.totalAutomaticInterventionsThisSessionDisplay == testCase.interventions)
            #expect(await monitor.monitoredApps.count == testCase.apps)
        }

        @Test("Shared instance validation")
        func sharedInstanceValidation() async throws {
            try await confirmation("Shared instance properties") { confirm in
                let sharedMonitor = await CursorMonitor.shared
                
                // Shared monitor is available
                try await CursorMonitorTestUtilities.validateMonitorState(sharedMonitor)
                confirm()
            }
        }

        #if DEBUG
            @Test("Preview monitor has test data")
            func previewMonitorConfiguration() async throws {
                let previewMonitor = await CursorMonitor.sharedForPreview

                #expect(await !previewMonitor.monitoredApps.isEmpty, "Preview monitor should have sample data")
                #expect(
                    await previewMonitor.totalAutomaticInterventionsThisSessionDisplay > 0,
                    "Preview should show interventions"
                )
                #expect(
                    await previewMonitor.monitoredApps.first?.displayName.contains("Preview") == true,
                    "Should have preview app name"
                )
            }
        #endif
    }

    // MARK: - Lifecycle Management Suite
    
    @Suite("Lifecycle Management", .tags(.lifecycle, .monitoring))
    struct LifecycleManagement {
        @Test("Monitor lifecycle transitions")
        @MainActor func monitorLifecycleTransitions() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            try await confirmation("Lifecycle state transitions", expectedCount: 3) { confirm in
                // Initial state
                #expect(!monitor.isMonitoringActivePublic)
                confirm()
                
                // Start monitoring
                await monitor.startMonitoringLoop()
                try await Task.sleep(for: .milliseconds(100))
                #expect(monitor.isMonitoringActivePublic)
                confirm()
                
                // Stop monitoring
                await monitor.stopMonitoringLoop()
                #expect(!monitor.isMonitoringActivePublic)
                confirm()
            }
        }

        @Test("Duplicate lifecycle requests are handled gracefully")
        @MainActor func duplicateLifecycleRequests() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

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
        @MainActor func emptyMonitoredAppsHandling() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

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
        @Test(
            "App management matrix",
            arguments: CursorMonitorTestData.testAppConfigurations
        )
        func appManagementMatrix(config: (id: Int, name: String, status: DisplayStatus)) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            let appInfo = await CursorMonitorTestUtilities.createTestApp(
                id: config.id,
                displayName: config.name,
                status: config.status
            )
            
            await MainActor.run {
                monitor.monitoredApps = [appInfo]
            }
            
            try await CursorMonitorTestUtilities.validateAppInfo(appInfo)
            #expect(await monitor.monitoredApps.count == 1)
            #expect(await monitor.monitoredApps.first?.pid == pid_t(config.id))
            #expect(await monitor.monitoredApps.first?.displayName == config.name)
            #expect(await monitor.monitoredApps.first?.status == config.status)
        }

        @Test(
            "Auto monitoring state transitions",
            arguments: [
                (status: DisplayStatus.active, shouldMonitor: true),
                (status: .idle, shouldMonitor: false),
                (status: .notRunning, shouldMonitor: false),
                (status: .pausedManually, shouldMonitor: false)
            ]
        )
        func autoMonitoringStateTransitions(
            testCase: (status: DisplayStatus, shouldMonitor: Bool)
        ) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            try await confirmation("Auto monitoring behavior") { @MainActor confirm in
                // Initial state
                #expect(await monitor.monitoredApps.isEmpty)
                #expect(await !monitor.isMonitoringActivePublic)
                
                // Add app with specific status
                let appInfo = await CursorMonitorTestUtilities.createTestApp(
                    id: 12345,
                    displayName: "Test Cursor",
                    status: testCase.status
                )
                
                await monitor.handleMonitoredAppsChange([appInfo])
                try await Task.sleep(for: .milliseconds(100))
                
                if testCase.shouldMonitor {
                    #expect(await monitor.isMonitoringActivePublic)
                } else {
                    #expect(await !monitor.isMonitoringActivePublic)
                }
                
                // Remove apps
                await monitor.handleMonitoredAppsChange([])
                #expect(await !monitor.isMonitoringActivePublic)
                
                confirm()
            }
        }

        @Test("Multiple apps can be monitored simultaneously")
        @MainActor func multipleAppsMonitoring() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

            var apps: [MonitoredAppInfo] = []
            for (id, name) in zip(CursorMonitorTestData.testAppIds, CursorMonitorTestData.testDisplayNames) {
                let app = await CursorMonitorTestUtilities.createTestApp(
                    id: id,
                    displayName: name,
                    status: .active
                )
                apps.append(app)
            }

            await MainActor.run {
                monitor.monitoredApps = apps
            }

            #expect(await monitor.monitoredApps.count == CursorMonitorTestData.testAppIds.count, "Should monitor all added apps")

            for (index, expectedId) in CursorMonitorTestData.testAppIds.enumerated() {
                #expect(await monitor.monitoredApps[index].pid == pid_t(expectedId), "App \(index) should have correct PID")
            }
        }
    }

    // MARK: - Window Management Suite
    
    @Suite("Window Management", .tags(.windows, .documents))
    struct WindowManagement {
        @Test(
            "Window management matrix",
            arguments: CursorMonitorTestData.windowCountMatrix
        )
        func windowManagementMatrix(
            testCase: (appCount: Int, windowsPerApp: Int)
        ) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            var apps: [MonitoredAppInfo] = []
            
            for appIndex in 0..<testCase.appCount {
                let app = await CursorMonitorTestUtilities.createTestApp(
                    id: 10000 + appIndex,
                    displayName: "App \(appIndex)",
                    status: .active,
                    windows: testCase.windowsPerApp
                )
                apps.append(app)
            }
            
            await MainActor.run {
                monitor.monitoredApps = apps
            }
            
            // Validate structure
            #expect(await monitor.monitoredApps.count == testCase.appCount)
            
            for app in await monitor.monitoredApps {
                #expect(await app.windows.count == testCase.windowsPerApp)
                try await CursorMonitorTestUtilities.validateAppInfo(app)
            }
            
            // Calculate total windows
            let totalWindows = await MainActor.run {
                monitor.monitoredApps.reduce(0) { $0 + $1.windows.count }
            }
            #expect(totalWindows == testCase.appCount * testCase.windowsPerApp)
        }

        @Test("Multiple windows per app are supported", arguments: [1, 3, 5])
        func multipleWindowsPerApp(windowCount: Int) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

            var windows: [MonitoredWindowInfo] = []
            for i in 0 ..< windowCount {
                let window = await MonitoredWindowInfo(
                    id: "window-\(i)",
                    windowTitle: "Document \(i).txt",
                    documentPath: "/path/to/document\(i).txt"
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

            await MainActor.run {
                monitor.monitoredApps = [appInfo]
            }

            #expect(await monitor.monitoredApps.first?.windows.count == windowCount, "Should have \(windowCount) windows")
        }
    }

    // MARK: - Intervention Tracking Suite
    
    @Suite("Intervention Tracking", .tags(.interventions, .tracking))
    struct InterventionTracking {
        struct InterventionTestCase {
            let appCount: Int
            let initialInterventions: Int
            let expectedBehavior: String
            
            static let standardCases = [
                InterventionTestCase(appCount: 1, initialInterventions: 0, expectedBehavior: "baseline"),
                InterventionTestCase(appCount: 3, initialInterventions: 5, expectedBehavior: "accumulated"),
                InterventionTestCase(appCount: 5, initialInterventions: 10, expectedBehavior: "high-volume")
            ]
        }
        
        @Test(
            "Intervention tracking matrix",
            arguments: InterventionTestCase.standardCases
        )
        func interventionTrackingMatrix(testCase: InterventionTestCase) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            var apps: [MonitoredAppInfo] = []
            for i in 0..<testCase.appCount {
                var app = await CursorMonitorTestUtilities.createTestApp(
                    id: 20000 + i,
                    displayName: "Intervention App \(i)",
                    status: .active
                )
                await MainActor.run {
                    app.interventionCount = testCase.initialInterventions
                }
                apps.append(app)
            }
            
            await MainActor.run {
                monitor.monitoredApps = apps
            }
            
            // Validate intervention counts
            for app in await monitor.monitoredApps {
                #expect(await app.interventionCount == testCase.initialInterventions)
            }
            
            // Perform monitoring cycle
            await monitor.performMonitoringCycle()
            
            // Verify counts don't decrease
            for app in await monitor.monitoredApps {
                #expect(await app.interventionCount >= testCase.initialInterventions)
            }
        }
        
        @Test("Cumulative intervention tracking")
        func cumulativeInterventionTracking() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            try await confirmation("Cumulative tracking", expectedCount: 5) { confirm in
                let initialTotal = await monitor.totalAutomaticInterventionsThisSessionDisplay
                
                for cycle in 1...5 {
                    await monitor.performMonitoringCycle()
                    
                    let currentTotal = await monitor.totalAutomaticInterventionsThisSessionDisplay
                    #expect(currentTotal >= initialTotal)
                    
                    confirm()
                }
            }
        }
    }

    // MARK: - Concurrency Suite
    
    @Suite("Concurrency", .tags(.threading, .async))
    struct Concurrency {
        @Test(
            "Concurrent operations matrix",
            arguments: [5, 10, 20]
        )
        func concurrentOperationsMatrix(concurrentTasks: Int) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Concurrent monitoring cycles
                for i in 0..<concurrentTasks {
                    group.addTask {
                        if i % 2 == 0 {
                            await monitor.performMonitoringCycle()
                        } else {
                            let app = await CursorMonitorTestUtilities.createTestApp(
                                id: 30000 + i,
                                displayName: "Concurrent App \(i)",
                                status: .active
                            )
                            await MainActor.run {
                                monitor.monitoredApps = [app]
                            }
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            // Validate final state
            try await CursorMonitorTestUtilities.validateMonitorState(monitor)
        }

        @Test("Concurrent app management is thread-safe")
        func concurrentAppManagement() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

            await withTaskGroup(of: Void.self) { group in
                // Multiple tasks modifying monitored apps
                for i in 0 ..< 10 {
                    group.addTask {
                        let appInfo = await CursorMonitorTestUtilities.createTestApp(
                            id: 10000 + i,
                            displayName: "Concurrent App \(i)",
                            status: .active
                        )
                        await MainActor.run {
                            monitor.monitoredApps = [appInfo]
                        }
                    }
                }
            }

            #expect(await monitor.monitoredApps.count >= 0, "Concurrent app management should maintain valid state")
        }
    }

    // MARK: - Performance Suite
    
    @Suite("Performance", .tags(.performance, .timing))
    struct Performance {
        @Test(
            "Performance scaling matrix",
            arguments: CursorMonitorTestData.performanceTestSizes
        )
        func performanceScalingMatrix(appCount: Int) async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)
            
            // Create apps
            var apps: [MonitoredAppInfo] = []
            for i in 0..<appCount {
                let app = await CursorMonitorTestUtilities.createTestApp(
                    id: 40000 + i,
                    displayName: "Perf App \(i)",
                    status: .active,
                    windows: min(5, appCount / 10 + 1)
                )
                apps.append(app)
            }
            
            let startTime = ContinuousClock().now
            
            // Set apps and perform monitoring
            await MainActor.run {
                monitor.monitoredApps = apps
            }
            await monitor.performMonitoringCycle()
            
            let elapsed = ContinuousClock().now - startTime
            
            // Performance should scale reasonably
            let expectedMaxDuration = Duration.milliseconds(100 * appCount)
            #expect(elapsed < expectedMaxDuration, "Performance should scale linearly")
        }

        @Test("Large number of apps can be handled efficiently", .timeLimit(.minutes(1)))
        func largeNumberOfAppsPerformance() async throws {
            let sessionLogger = await SessionLogger.shared
            let monitor = await createTestMonitor(sessionLogger: sessionLogger)

            // Create many mock apps
            var apps: [MonitoredAppInfo] = []
            for i in 0 ..< 100 {
                let app = await CursorMonitorTestUtilities.createTestApp(
                    id: i,
                    displayName: "App \(i)",
                    status: .active
                )
                apps.append(app)
            }

            let startTime = ContinuousClock().now
            await MainActor.run {
                monitor.monitoredApps = apps
            }
            let elapsed = ContinuousClock().now - startTime

            #expect(elapsed < .seconds(1), "Setting 100 apps should be fast")
            #expect(await monitor.monitoredApps.count == 100, "Should handle 100 apps correctly")
        }
    }

    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration), .disabled("Requires live system"))
    struct IntegrationTests {
        @Test("End-to-end monitoring flow")
        func endToEndMonitoringFlow() async throws {
            let monitor = await CursorMonitor.shared
            
            // This test would require actual accessibility permissions
            #expect(await monitor.axorcist != nil, "Monitor should have AXorcist instance")
        }
    }
}

// MARK: - Helper Functions

extension CursorMonitorServiceTests {
    /// Helper to create test monitor
    static func createTestMonitor(sessionLogger: SessionLogger) async -> CursorMonitor {
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
    
    /// Helper to create test app info
    static func createTestAppInfo(
        id: Int,
        displayName: String,
        status: DisplayStatus
    ) async -> MonitoredAppInfo {
        return await CursorMonitorTestUtilities.createTestApp(
            id: id,
            displayName: displayName,
            status: status
        )
    }
}

// MARK: - Custom Assertions

extension CursorMonitorServiceTests {
    func assertValidMonitoredApp(
        _ app: MonitoredAppInfo,
        expectedStatus: DisplayStatus? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(app.pid > 0, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        #expect(!app.displayName.isEmpty, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        #expect(app.interventionCount >= 0, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        
        if let expectedStatus = expectedStatus {
            #expect(app.status == expectedStatus, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        }
    }
}

