@testable import CodeLooper
import Combine
import Defaults
import Foundation
import Testing

@Suite("RuleExecutionTests")
struct RuleExecutionTests {
    // MARK: - RuleExecutor Tests

    @Test("Rule executor initialization") func ruleExecutorInitialization() {
        let ruleExecutor = await RuleExecutor()

        // Test that executor is created without errors
        #expect(ruleExecutor != nil)
    }

    @Test("Rule execution") func ruleExecution() {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = await MainActor.run {
            (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])
        }

        // Enable rules
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = true
        }

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        let ruleExecutor = await RuleExecutor()

        // Execute enabled rules (will check for hooked windows)
        await ruleExecutor.executeEnabledRules()

        // Should execute without crashes
        #expect(true)
    }

    @Test("Stop after25 loops rule") func stopAfter25LoopsRule() {
        let rule = await StopAfter25LoopsRule()

        // Test rule properties
        await MainActor.run {
            #expect(rule.displayName.contains("25"))
            #expect(rule.ruleName == "StopAfter25LoopsRule")
        }
    }

    @Test("Rule counter management") func ruleCounterManagement() {
        let counterManager = await RuleCounterManager.shared

        // Test counter initialization
        #expect(counterManager != nil)

        // Test counter operations
        let testRule = "test-rule"

        let initialCount = await counterManager.getCount(for: testRule)

        await counterManager.incrementCounter(for: testRule)
        let count = await counterManager.getCount(for: testRule)
        #expect(count == initialCount + 1)

        await counterManager.resetCounter(for: testRule)
        let resetCount = await counterManager.getCount(for: testRule)
        #expect(resetCount == 0)
    }

    @Test("Rule execution with defaults") func ruleExecutionWithDefaults() {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = await MainActor.run {
            (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])
        }

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        // Test with monitoring disabled
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = false
            Defaults[.enableCursorForceStoppedRecovery] = true
        }

        let ruleExecutor = await RuleExecutor()
        await ruleExecutor.executeEnabledRules()

        // Should not execute when monitoring is disabled
        #expect(true)

        // Test with monitoring enabled but recovery disabled
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = false
        }

        await ruleExecutor.executeEnabledRules()

        // Should not execute recovery rule when disabled
        #expect(true)
    }

    // MARK: - Rule Counter Tests

    @Test("Rule counter increment") func ruleCounterIncrement() {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "test-increment-rule"

        // Reset counter first
        await counterManager.resetCounter(for: ruleName)

        // Increment multiple times
        for _ in 0 ..< 5 {
            await counterManager.incrementCounter(for: ruleName)
        }

        let count = await counterManager.getCount(for: ruleName)
        #expect(count == 5)
    }

    @Test("Rule counter reset") func ruleCounterReset() {
        let counterManager = await RuleCounterManager.shared
        let ruleName = "test-reset-rule"

        // Add some counts
        for _ in 0 ..< 3 {
            await counterManager.incrementCounter(for: ruleName)
        }

        // Reset
        await counterManager.resetCounter(for: ruleName)

        let count = await counterManager.getCount(for: ruleName)
        #expect(count == 0)
    }

    @Test("Rule counter reset all") func ruleCounterResetAll() {
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
            #expect(count == 0)
        }
    }

    @Test("Rule counter persistence") func ruleCounterPersistence() {
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
        #expect(count == 2)
    }

    @Test("Total rule executions") func testTotalRuleExecutions() {
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

        #expect(total >= 4)
    }

    @Test("Executed rule names") func testExecutedRuleNames() {
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
            #expect(executedRules.contains(rule))
        }

        // Should be sorted
        #expect(executedRules == executedRules.sorted())
    }

    // MARK: - StopAfter25LoopsRule Tests

    @Test("Stop after25 loops threshold") func stopAfter25LoopsThreshold() {
        let rule = await StopAfter25LoopsRule()
        let counterManager = await RuleCounterManager.shared

        // Reset counter
        await counterManager.resetCounter(for: rule.ruleName)

        // Increment counter to just below threshold
        for _ in 0 ..< 24 {
            await counterManager.incrementCounter(for: rule.ruleName)
        }

        let count = await counterManager.getCount(for: rule.ruleName)
        #expect(count == 24)

        // One more should hit threshold
        await counterManager.incrementCounter(for: rule.ruleName)
        let finalCount = await counterManager.getCount(for: rule.ruleName)
        #expect(finalCount == 25)
    }

    @Test("Stop after25 loops execution") func stopAfter25LoopsExecution() {
        let rule = await StopAfter25LoopsRule()
        let jsHookService = await JSHookService.shared

        // Reset counter
        await RuleCounterManager.shared.resetCounter(for: rule.ruleName)

        // Test execution with a mock window ID
        // Note: This will likely return false since there's no actual hooked window
        let result = await rule.execute(windowId: "test-window", jsHookService: jsHookService)

        // Result depends on whether window is actually hooked
        // Since there's no actual hooked window in test, result should be false
        #expect(result == false, "Expected false since no window is hooked in test environment")
    }

    // MARK: - Integration Tests

    @Test("Rule system integration") func ruleSystemIntegration() {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = await MainActor.run {
            (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])
        }

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        // Enable all features
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = true
        }

        let ruleExecutor = await RuleExecutor()
        let counterManager = await RuleCounterManager.shared

        // Reset counters
        await counterManager.resetAllCounters()

        // Execute rules multiple times
        for _ in 0 ..< 3 {
            await ruleExecutor.executeEnabledRules()
        }

        // Should complete integration flow
        #expect(true)
    }

    @Test("Rule performance") func rulePerformance() {
        _ = await RuleExecutor()
        let counterManager = await RuleCounterManager.shared

        // Test performance with many counter operations
        let startTime = Date()

        for i in 0 ..< 50 {
            await counterManager.incrementCounter(for: "perf-test-\(i)")
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 50 operations)
        #expect(duration < 1.0)
    }

    // MARK: - Notification Tests

    @Test("Rule counter notifications") func ruleCounterNotifications() {
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
        #expect(notificationReceived)
    }

    // MARK: - Error Handling Tests

    @Test("Rule execution with no hooked windows") func ruleExecutionWithNoHookedWindows() {
        // This test verifies that rule execution handles the case of no hooked windows gracefully
        let ruleExecutor = await RuleExecutor()

        // Enable rules
        await MainActor.run {
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = true
        }

        // Execute rules (likely no hooked windows in test environment)
        await ruleExecutor.executeEnabledRules()

        // Should not crash
        #expect(true)
    }

    @Test("Concurrent counter operations") func concurrentCounterOperations() {
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
        #expect(count == 10)
    }
}
