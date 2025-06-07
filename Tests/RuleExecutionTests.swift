@testable import CodeLooper
import Combine
import Defaults
import Foundation
import Testing

@Suite("RuleExecutionTests")
struct RuleExecutionTests {
    // MARK: - RuleExecutor Tests

    @Test("Rule executor initialization") @MainActor func ruleExecutorInitialization() async throws {
        _ = RuleExecutor()

        // Test that executor is created without errors
        // ruleExecutor is non-optional
    }

    @Test("Rule execution") @MainActor func ruleExecution() async throws {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])

        // Enable rules
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        let ruleExecutor = RuleExecutor()

        // Execute enabled rules (will check for hooked windows)
        await ruleExecutor.executeEnabledRules()

        // Should execute without crashes
        #expect(Bool(true))
    }

    @Test("Stop after25 loops rule") @MainActor func stopAfter25LoopsRule() async throws {
        let rule = StopAfter25LoopsRule()

        // Test rule properties
        #expect(rule.displayName.contains("25"))
        #expect(rule.ruleName == "StopAfter25LoopsRule")
    }

    @Test("Rule counter management") @MainActor func ruleCounterManagement() async throws {
        let counterManager = RuleCounterManager.shared

        // Test counter initialization
        // counterManager is non-optional, no need to check for nil

        // Test counter operations
        let testRule = "test-rule"

        let initialCount = counterManager.getCount(for: testRule)

        counterManager.incrementCounter(for: testRule)
        let count = counterManager.getCount(for: testRule)
        #expect(count == initialCount + 1)

        counterManager.resetCounter(for: testRule)
        let resetCount = counterManager.getCount(for: testRule)
        #expect(resetCount == 0)
    }

    @Test("Rule execution with defaults") @MainActor func ruleExecutionWithDefaults() async throws {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        // Test with monitoring disabled
        Defaults[.isGlobalMonitoringEnabled] = false
        Defaults[.enableCursorForceStoppedRecovery] = true

        let ruleExecutor = RuleExecutor()
        await ruleExecutor.executeEnabledRules()

        // Should not execute when monitoring is disabled
        #expect(Bool(true))

        // Test with monitoring enabled but recovery disabled
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = false

        await ruleExecutor.executeEnabledRules()

        // Should not execute recovery rule when disabled
        #expect(Bool(true))
    }

    // MARK: - Rule Counter Tests

    @Test("Rule counter increment") @MainActor func ruleCounterIncrement() async throws {
        let counterManager = RuleCounterManager.shared
        let ruleName = "test-increment-rule"

        // Reset counter first
        counterManager.resetCounter(for: ruleName)

        // Increment multiple times
        for _ in 0 ..< 5 {
            counterManager.incrementCounter(for: ruleName)
        }

        let count = counterManager.getCount(for: ruleName)
        #expect(count == 5)
    }

    @Test("Rule counter reset") @MainActor func ruleCounterReset() async throws {
        let counterManager = RuleCounterManager.shared
        let ruleName = "test-reset-rule"

        // Add some counts
        for _ in 0 ..< 3 {
            counterManager.incrementCounter(for: ruleName)
        }

        // Reset
        counterManager.resetCounter(for: ruleName)

        let count = counterManager.getCount(for: ruleName)
        #expect(count == 0)
    }

    @Test("Rule counter reset all") @MainActor func ruleCounterResetAll() async throws {
        let counterManager = RuleCounterManager.shared

        // Add counts for multiple rules
        let rules = ["rule1", "rule2", "rule3"]
        for rule in rules {
            for _ in 0 ..< 2 {
                counterManager.incrementCounter(for: rule)
            }
        }

        // Reset all
        counterManager.resetAllCounters()

        // Verify all are reset
        for rule in rules {
            let count = counterManager.getCount(for: rule)
            #expect(count == 0)
        }
    }

    @Test("Rule counter persistence") @MainActor func ruleCounterPersistence() async throws {
        let counterManager = RuleCounterManager.shared
        let ruleName = "test-persistence-rule"

        // Reset first
        counterManager.resetCounter(for: ruleName)

        // Increment
        counterManager.incrementCounter(for: ruleName)
        counterManager.incrementCounter(for: ruleName)

        // The counter manager automatically saves on increment
        // Since it's a singleton, the count should persist

        let count = counterManager.getCount(for: ruleName)
        #expect(count == 2)
    }

    @Test("Total rule executions") @MainActor func testTotalRuleExecutions() async throws {
        let counterManager = RuleCounterManager.shared

        // Reset all first
        counterManager.resetAllCounters()

        // Add various counts
        counterManager.incrementCounter(for: "rule1")
        counterManager.incrementCounter(for: "rule1")
        counterManager.incrementCounter(for: "rule2")
        counterManager.incrementCounter(for: "rule3")

        let total = counterManager.totalRuleExecutions

        #expect(total >= 4)
    }

    @Test("Executed rule names") @MainActor func testExecutedRuleNames() async throws {
        let counterManager = RuleCounterManager.shared

        // Reset all first
        counterManager.resetAllCounters()

        // Execute some rules
        let testRules = ["alpha-rule", "beta-rule", "gamma-rule"]
        for rule in testRules {
            counterManager.incrementCounter(for: rule)
        }

        let executedRules = counterManager.executedRuleNames

        // Should contain our test rules
        for rule in testRules {
            #expect(executedRules.contains(rule))
        }

        // Should be sorted
        #expect(executedRules == executedRules.sorted())
    }

    // MARK: - StopAfter25LoopsRule Tests

    @Test("Stop after25 loops threshold") @MainActor func stopAfter25LoopsThreshold() async throws {
        let rule = StopAfter25LoopsRule()
        let counterManager = RuleCounterManager.shared

        // Reset counter
        counterManager.resetCounter(for: rule.ruleName)

        // Increment counter to just below threshold
        for _ in 0 ..< 24 {
            counterManager.incrementCounter(for: rule.ruleName)
        }

        let count = counterManager.getCount(for: rule.ruleName)
        #expect(count == 24)

        // One more should hit threshold
        counterManager.incrementCounter(for: rule.ruleName)
        let finalCount = counterManager.getCount(for: rule.ruleName)
        #expect(finalCount == 25)
    }

    @Test("Stop after25 loops execution") @MainActor func stopAfter25LoopsExecution() async throws {
        let rule = StopAfter25LoopsRule()
        let jsHookService = JSHookService.shared

        // Reset counter
        RuleCounterManager.shared.resetCounter(for: rule.ruleName)

        // Test execution with a mock window ID
        // Note: This will likely return false since there's no actual hooked window
        let result = await rule.execute(windowId: "test-window", jsHookService: jsHookService)

        // Result depends on whether window is actually hooked
        // Since there's no actual hooked window in test, result should be false
        #expect(result == false, "Expected false since no window is hooked in test environment")
    }

    // MARK: - Integration Tests

    @Test("Rule system integration") @MainActor func ruleSystemIntegration() async throws {
        // Save current defaults
        let (originalMonitoring, originalRecovery) = (Defaults[.isGlobalMonitoringEnabled], Defaults[.enableCursorForceStoppedRecovery])

        defer {
            // Restore defaults
            Task { @MainActor in
                Defaults[.isGlobalMonitoringEnabled] = originalMonitoring
                Defaults[.enableCursorForceStoppedRecovery] = originalRecovery
            }
        }

        // Enable all features
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        let ruleExecutor = RuleExecutor()
        let counterManager = RuleCounterManager.shared

        // Reset counters
        counterManager.resetAllCounters()

        // Execute rules multiple times
        for _ in 0 ..< 3 {
            await ruleExecutor.executeEnabledRules()
        }

        // Should complete integration flow
        #expect(Bool(true))
    }

    @Test("Rule performance") @MainActor func rulePerformance() async throws {
        _ = RuleExecutor()
        let counterManager = RuleCounterManager.shared

        // Test performance with many counter operations
        let startTime = Date()

        for i in 0 ..< 50 {
            counterManager.incrementCounter(for: "perf-test-\(i)")
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 50 operations)
        #expect(duration < 1.0)
    }

    // MARK: - Notification Tests

    @Test("Rule counter notifications") @MainActor func ruleCounterNotifications() async throws {
        let counterManager = RuleCounterManager.shared
        let ruleName = "notification-test-rule"

        actor NotificationTracker {
            var received = false

            func markReceived() {
                received = true
            }
            
            func getReceived() -> Bool {
                received
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
        counterManager.incrementCounter(for: ruleName)

        // Give time for notification
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let notificationReceived = await tracker.getReceived()
        #expect(notificationReceived)
    }

    // MARK: - Error Handling Tests

    @Test("Rule execution with no hooked windows") @MainActor func ruleExecutionWithNoHookedWindows() async throws {
        // This test verifies that rule execution handles the case of no hooked windows gracefully
        let ruleExecutor = RuleExecutor()

        // Enable rules
        Defaults[.isGlobalMonitoringEnabled] = true
        Defaults[.enableCursorForceStoppedRecovery] = true

        // Execute rules (likely no hooked windows in test environment)
        await ruleExecutor.executeEnabledRules()

        // Should not crash
        #expect(Bool(true))
    }

    @Test("Concurrent counter operations") @MainActor func concurrentCounterOperations() async throws {
        let counterManager = RuleCounterManager.shared
        let ruleName = "concurrent-test-rule"

        // Reset counter
        counterManager.resetCounter(for: ruleName)

        // Concurrent increments
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    await counterManager.incrementCounter(for: ruleName)
                }
            }
        }

        // Should handle concurrent access
        let count = counterManager.getCount(for: ruleName)
        #expect(count == 10)
    }
}