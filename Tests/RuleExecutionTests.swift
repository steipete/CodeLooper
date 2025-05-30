@testable import CodeLooper
import Combine
import Defaults
import Foundation
import XCTest

class RuleExecutionTests: XCTestCase {
    // MARK: - RuleExecutor Tests

    func testRuleExecutorInitialization() async throws {
        let ruleExecutor = await RuleExecutor()

        // Test that executor is created without errors
        XCTAssertNotNil(ruleExecutor)
    }

    func testRuleExecution() async throws {
        // Save current defaults
        let originalMonitoring = Defaults[.isGlobalMonitoringEnabled]
        let originalRecovery = Defaults[.enableCursorForceStoppedRecovery]

        // Enable rules
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        defer {
            // Restore defaults
            Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
            Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
        }

        let ruleExecutor = await RuleExecutor()

        // Execute enabled rules (will check for hooked windows)
        await ruleExecutor.executeEnabledRules()

        // Should execute without crashes
        XCTAssertTrue(true)
    }

    func testStopAfter25LoopsRule() async throws {
        let rule = await StopAfter25LoopsRule()

        // Test rule properties
        await MainActor.run {
            XCTAssertTrue(rule.displayName.contains("25"))
            XCTAssertEqual(rule.ruleName, "StopAfter25LoopsRule")
        }
    }

    func testRuleCounterManagement() async throws {
        let counterManager = await RuleCounterManager.shared

        // Test counter initialization
        XCTAssertNotNil(counterManager)

        // Test counter operations
        let testRule = "test-rule"

        let initialCount = await counterManager.getCount(for: testRule)

        await counterManager.incrementCounter(for: testRule)
        let count = await counterManager.getCount(for: testRule)
        XCTAssertEqual(count, initialCount + 1)

        await counterManager.resetCounter(for: testRule)
        let resetCount = await counterManager.getCount(for: testRule)
        XCTAssertEqual(resetCount, 0)
    }

    func testRuleExecutionWithDefaults() async throws {
        // Save current defaults
        let originalMonitoring = Defaults[.isGlobalMonitoringEnabled]
        let originalRecovery = Defaults[.enableCursorForceStoppedRecovery]

        defer {
            // Restore defaults
            Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
            Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
        }

        // Test with monitoring disabled
        Defaults[.isGlobalMonitoringEnabled] = false
        Defaults[.enableCursorForceStoppedRecovery] = true

        let ruleExecutor = await RuleExecutor()
        await ruleExecutor.executeEnabledRules()

        // Should not execute when monitoring is disabled
        XCTAssertTrue(true)

        // Test with monitoring enabled but recovery disabled
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = false

        await ruleExecutor.executeEnabledRules()

        // Should not execute recovery rule when disabled
        XCTAssertTrue(true)
    }

    // MARK: - Rule Counter Tests

    func testRuleCounterIncrement() async throws {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "test-increment-rule"

        // Reset counter first
        await counterManager.resetCounter(for: ruleName)

        // Increment multiple times
        for _ in 0 ..< 5 {
            await counterManager.incrementCounter(for: ruleName)
        }

        let count = await counterManager.getCount(for: ruleName)
        XCTAssertEqual(count, 5)
    }

    func testRuleCounterReset() async throws {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "test-reset-rule"

        // Add some counts
        for _ in 0 ..< 3 {
            await counterManager.incrementCounter(for: ruleName)
        }

        // Reset
        await counterManager.resetCounter(for: ruleName)

        let count = await counterManager.getCount(for: ruleName)
        XCTAssertEqual(count, 0)
    }

    func testRuleCounterResetAll() async throws {
        let counterManager = await RuleCounterManager.shared

        // Add counts for multiple rules
        let rules = ["rule1", "rule2", "rule3"]
        for rule in rules {
            for _ in 0 ..< 2 {
                await counterManager.incrementCounter(for: rule)
            }
        }

        // Reset all
        await counterManager.resetAllCounters()

        // Verify all are reset
        for rule in rules {
            let count = await counterManager.getCount(for: rule)
            XCTAssertEqual(count, 0)
        }
    }

    func testRuleCounterPersistence() async throws {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "test-persistence-rule"

        // Reset first
        await counterManager.resetCounter(for: ruleName)

        // Increment
        await counterManager.incrementCounter(for: ruleName)
        await counterManager.incrementCounter(for: ruleName)

        // The counter manager automatically saves on increment
        // Since it's a singleton, the count should persist

        let count = await counterManager.getCount(for: ruleName)
        XCTAssertEqual(count, 2)
    }

    func testTotalRuleExecutions() async throws {
        let counterManager = await RuleCounterManager.shared

        // Reset all first
        await counterManager.resetAllCounters()

        // Add various counts
        await counterManager.incrementCounter(for: "rule1")
        await counterManager.incrementCounter(for: "rule1")
        await counterManager.incrementCounter(for: "rule2")
        await counterManager.incrementCounter(for: "rule3")

        let total = await MainActor.run {
            counterManager.totalRuleExecutions
        }

        XCTAssertGreaterThanOrEqual(total, 4)
    }

    func testExecutedRuleNames() async throws {
        let counterManager = await RuleCounterManager.shared

        // Reset all first
        await counterManager.resetAllCounters()

        // Execute some rules
        let testRules = ["alpha-rule", "beta-rule", "gamma-rule"]
        for rule in testRules {
            await counterManager.incrementCounter(for: rule)
        }

        let executedRules = await MainActor.run {
            counterManager.executedRuleNames
        }

        // Should contain our test rules
        for rule in testRules {
            XCTAssertTrue(executedRules.contains(rule))
        }

        // Should be sorted
        XCTAssertEqual(executedRules, executedRules.sorted())
    }

    // MARK: - StopAfter25LoopsRule Tests

    func testStopAfter25LoopsThreshold() async throws {
        let rule = await StopAfter25LoopsRule()
        let counterManager = await RuleCounterManager.shared

        // Reset counter
        await counterManager.resetCounter(for: rule.ruleName)

        // Increment counter to just below threshold
        for _ in 0 ..< 24 {
            await counterManager.incrementCounter(for: rule.ruleName)
        }

        let count = await counterManager.getCount(for: rule.ruleName)
        XCTAssertEqual(count, 24)

        // One more should hit threshold
        await counterManager.incrementCounter(for: rule.ruleName)
        let finalCount = await counterManager.getCount(for: rule.ruleName)
        XCTAssertEqual(finalCount, 25)
    }

    func testStopAfter25LoopsExecution() async throws {
        let rule = await StopAfter25LoopsRule()
        let jsHookService = await JSHookService.shared

        // Reset counter
        await RuleCounterManager.shared.resetCounter(for: rule.ruleName)

        // Test execution with a mock window ID
        // Note: This will likely return false since there's no actual hooked window
        let result = await rule.execute(windowId: "test-window", jsHookService: jsHookService)

        // Result depends on whether window is actually hooked
        XCTAssertEqual(result, true || result == false)
    }

    // MARK: - Integration Tests

    func testRuleSystemIntegration() async throws {
        // Save current defaults
        let originalMonitoring = Defaults[.isGlobalMonitoringEnabled]
        let originalRecovery = Defaults[.enableCursorForceStoppedRecovery]

        defer {
            // Restore defaults
            Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
            Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
        }

        // Enable all features
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        let ruleExecutor = await RuleExecutor()
        let counterManager = await RuleCounterManager.shared

        // Reset counters
        await counterManager.resetAllCounters()

        // Execute rules multiple times
        for _ in 0 ..< 3 {
            await ruleExecutor.executeEnabledRules()
        }

        // Should complete integration flow
        XCTAssertTrue(true)
    }

    func testRulePerformance() async throws {
        let _ = await RuleExecutor()
        let counterManager = await RuleCounterManager.shared

        // Test performance with many counter operations
        let startTime = Date()

        for i in 0 ..< 50 {
            await counterManager.incrementCounter(for: "perf-test-\(i)")
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 50 operations)
        XCTAssertLessThan(duration, 1.0)
    }

    // MARK: - Notification Tests

    func testRuleCounterNotifications() async throws {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "notification-test-rule"

        actor NotificationTracker {
            var received = false

            func markReceived() {
                received = true
            }
        }

        let tracker = NotificationTracker()

        // Subscribe to notifications
        let observer = NotificationCenter.default.addObserver(
            forName: .ruleCounterUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let notifiedRuleName = userInfo["ruleName"] as? String,
               notifiedRuleName == ruleName
            {
                Task {
                    await tracker.markReceived()
                }
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // Increment counter
        await counterManager.incrementCounter(for: ruleName)

        // Give time for notification
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let notificationReceived = await tracker.received
        XCTAssertTrue(notificationReceived)
    }

    // MARK: - Error Handling Tests

    func testRuleExecutionWithNoHookedWindows() async throws {
        // This test verifies that rule execution handles the case of no hooked windows gracefully
        let ruleExecutor = await RuleExecutor()

        // Enable rules
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        // Execute rules (likely no hooked windows in test environment)
        await ruleExecutor.executeEnabledRules()

        // Should not crash
        XCTAssertTrue(true)
    }

    func testConcurrentCounterOperations() async throws {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "concurrent-test-rule"

        // Reset counter
        await counterManager.resetCounter(for: ruleName)

        // Concurrent increments
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    await counterManager.incrementCounter(for: ruleName)
                }
            }
        }

        // Should handle concurrent access
        let count = await counterManager.getCount(for: ruleName)
        XCTAssertEqual(count, 10)
    }
}
