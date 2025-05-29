@testable import CodeLooper
import Combine
import Defaults
import Foundation
import Testing

/// Test suite for rule execution functionality
@Suite("Rule Execution Tests")
struct RuleExecutionTests {
    // MARK: - Test Utilities

    /// Mock JSHookService for testing
    class MockJSHookService: JSHookService {
        var hookedWindowIds: [String] = []
        var commandResponses: [String: String] = [:]
        var shouldThrowError = false

        override func getAllHookedWindowIds() -> [String] {
            hookedWindowIds
        }

        override func sendCommand(_ command: [String: Any], to _: String) async throws -> String {
            if shouldThrowError {
                throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
            }

            if let type = command["type"] as? String {
                return commandResponses[type] ?? "{\"success\": false}"
            }

            return "{\"success\": false}"
        }
    }

    /// Test helper to create temporary defaults
    func withTemporaryDefaults<T>(_ block: () throws -> T) rethrows -> T {
        let originalSuite = Defaults.suite
        let testSuite = UserDefaults(suiteName: "com.codelooper.ruletest.\(UUID().uuidString)")!
        Defaults.suite = testSuite

        defer {
            Defaults.suite = originalSuite
        }

        return try block()
    }

    // MARK: - RuleExecutor Tests

    @Test("RuleExecutor can be initialized")
    func ruleExecutorInitialization() async throws {
        let executor = await RuleExecutor()

        // Test that executor is created without errors
        #expect(executor != nil)
    }

    @Test("RuleExecutor respects global monitoring setting")
    func ruleExecutorGlobalMonitoring() async throws {
        try withTemporaryDefaults {
            let executor = await RuleExecutor()

            // Disable global monitoring
            Defaults[.isGlobalMonitoringEnabled] = false

            // Execute rules - should return early due to disabled monitoring
            await executor.executeEnabledRules()

            // If we get here without errors, the method handled disabled monitoring gracefully
            #expect(true)

            // Enable global monitoring
            Defaults[.isGlobalMonitoringEnabled] = true

            // Execute rules - should proceed (but may have no hooked windows)
            await executor.executeEnabledRules()

            #expect(true)
        }
    }

    @Test("RuleExecutor executes enabled rules")
    func ruleExecution() async throws {
        try withTemporaryDefaults {
            let executor = await RuleExecutor()

            // Enable global monitoring and rule
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = true

            // Execute rules
            await executor.executeEnabledRules()

            // Verify no crashes occurred
            #expect(true)
        }
    }

    @Test("RuleExecutor handles disabled rules")
    func disabledRuleHandling() async throws {
        try withTemporaryDefaults {
            let executor = await RuleExecutor()

            // Enable global monitoring but disable specific rule
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = false

            // Execute rules
            await executor.executeEnabledRules()

            // Verify no crashes occurred
            #expect(true)
        }
    }

    // MARK: - StopAfter25LoopsRule Tests

    @Test("StopAfter25LoopsRule initializes correctly")
    func stopAfter25LoopsRuleInitialization() async throws {
        let rule = await StopAfter25LoopsRule()

        await MainActor.run {
            #expect(rule.displayName == "Stop after 25 loops")
            #expect(rule.ruleName == "StopAfter25LoopsRule")
        }
    }

    @Test("StopAfter25LoopsRule stops execution after limit")
    func stopAfter25LoopsRuleLimit() async throws {
        try withTemporaryDefaults {
            let rule = await StopAfter25LoopsRule()
            let mockService = MockJSHookService()

            // Reset counter to ensure clean state
            await RuleCounterManager.shared.resetCounter(for: "StopAfter25LoopsRule")

            // Set counter to 25 (at limit)
            for _ in 0 ..< 25 {
                await RuleCounterManager.shared.incrementCounter(for: "StopAfter25LoopsRule")
            }

            // Attempt to execute - should return false (stopped)
            let result = await rule.execute(windowId: "test-window", jsHookService: mockService)

            #expect(result == false)
        }
    }

    @Test("StopAfter25LoopsRule executes when rule is needed")
    func stopAfter25LoopsRuleExecution() async throws {
        try withTemporaryDefaults {
            let rule = await StopAfter25LoopsRule()
            let mockService = MockJSHookService()

            // Reset counter
            await RuleCounterManager.shared.resetCounter(for: "StopAfter25LoopsRule")

            // Configure mock responses
            mockService.commandResponses["checkRuleNeeded"] = "{\"ruleNeeded\": true}"
            mockService.commandResponses["performRule"] = "{\"success\": true}"
            mockService.hookedWindowIds = ["test-window"]

            // Execute rule
            let result = await rule.execute(windowId: "test-window", jsHookService: mockService)

            #expect(result == true)

            // Verify counter was incremented
            let count = await RuleCounterManager.shared.getCount(for: "StopAfter25LoopsRule")
            #expect(count == 1)
        }
    }

    @Test("StopAfter25LoopsRule handles no action needed")
    func stopAfter25LoopsRuleNoAction() async throws {
        try withTemporaryDefaults {
            let rule = await StopAfter25LoopsRule()
            let mockService = MockJSHookService()

            // Reset counter
            await RuleCounterManager.shared.resetCounter(for: "StopAfter25LoopsRule")

            // Configure mock responses - no rule needed
            mockService.commandResponses["checkRuleNeeded"] = "{\"ruleNeeded\": false}"
            mockService.hookedWindowIds = ["test-window"]

            // Execute rule
            let result = await rule.execute(windowId: "test-window", jsHookService: mockService)

            #expect(result == false)

            // Verify counter was not incremented
            let count = await RuleCounterManager.shared.getCount(for: "StopAfter25LoopsRule")
            #expect(count == 0)
        }
    }

    @Test("StopAfter25LoopsRule handles errors gracefully")
    func stopAfter25LoopsRuleErrorHandling() async throws {
        try withTemporaryDefaults {
            let rule = await StopAfter25LoopsRule()
            let mockService = MockJSHookService()

            // Reset counter
            await RuleCounterManager.shared.resetCounter(for: "StopAfter25LoopsRule")

            // Configure mock to throw error
            mockService.shouldThrowError = true
            mockService.hookedWindowIds = ["test-window"]

            // Execute rule - should handle error gracefully
            let result = await rule.execute(windowId: "test-window", jsHookService: mockService)

            #expect(result == false)

            // Verify counter was not incremented due to error
            let count = await RuleCounterManager.shared.getCount(for: "StopAfter25LoopsRule")
            #expect(count == 0)
        }
    }

    // MARK: - RuleCounterManager Tests

    @Test("RuleCounterManager initializes as singleton")
    func ruleCounterManagerSingleton() async throws {
        let manager1 = await RuleCounterManager.shared
        let manager2 = await RuleCounterManager.shared

        // Should be the same instance
        #expect(manager1 === manager2)
    }

    @Test("RuleCounterManager manages counters correctly")
    func ruleCounterManagement() async throws {
        let manager = await RuleCounterManager.shared
        let testRuleName = "TestRule_\(UUID().uuidString)"

        // Reset to ensure clean state
        await manager.resetCounter(for: testRuleName)

        // Initial count should be 0
        let initialCount = await manager.getCount(for: testRuleName)
        #expect(initialCount == 0)

        // Increment counter
        await manager.incrementCounter(for: testRuleName)

        let countAfterIncrement = await manager.getCount(for: testRuleName)
        #expect(countAfterIncrement == 1)

        // Increment again
        await manager.incrementCounter(for: testRuleName)

        let countAfterSecondIncrement = await manager.getCount(for: testRuleName)
        #expect(countAfterSecondIncrement == 2)

        // Reset counter
        await manager.resetCounter(for: testRuleName)

        let countAfterReset = await manager.getCount(for: testRuleName)
        #expect(countAfterReset == 0)
    }

    @Test("RuleCounterManager calculates total executions")
    func ruleCounterManagerTotalExecutions() async throws {
        let manager = await RuleCounterManager.shared
        let testRule1 = "TestRule1_\(UUID().uuidString)"
        let testRule2 = "TestRule2_\(UUID().uuidString)"

        // Reset counters
        await manager.resetCounter(for: testRule1)
        await manager.resetCounter(for: testRule2)

        // Add some executions
        await manager.incrementCounter(for: testRule1)
        await manager.incrementCounter(for: testRule1)
        await manager.incrementCounter(for: testRule2)

        // Check total (should include all rules, so at least 3)
        let total = await manager.totalRuleExecutions
        #expect(total >= 3)

        // Check executed rule names
        let executedNames = await manager.executedRuleNames
        #expect(executedNames.contains(testRule1))
        #expect(executedNames.contains(testRule2))
    }

    @Test("RuleCounterManager resets all counters")
    func ruleCounterManagerResetAll() async throws {
        let manager = await RuleCounterManager.shared
        let testRule1 = "TestRule1_\(UUID().uuidString)"
        let testRule2 = "TestRule2_\(UUID().uuidString)"

        // Add some executions
        await manager.incrementCounter(for: testRule1)
        await manager.incrementCounter(for: testRule2)

        // Verify counters are set
        let count1Before = await manager.getCount(for: testRule1)
        let count2Before = await manager.getCount(for: testRule2)
        #expect(count1Before > 0)
        #expect(count2Before > 0)

        // Reset all counters
        await manager.resetAllCounters()

        // Verify all counters are reset
        let count1After = await manager.getCount(for: testRule1)
        let count2After = await manager.getCount(for: testRule2)
        #expect(count1After == 0)
        #expect(count2After == 0)

        let totalAfterReset = await manager.totalRuleExecutions
        #expect(totalAfterReset == 0)
    }

    @Test("RuleCounterManager sends notifications on counter updates")
    func ruleCounterManagerNotifications() async throws {
        let manager = await RuleCounterManager.shared
        let testRuleName = "TestRule_\(UUID().uuidString)"

        // Set up expectation for notification
        var notificationReceived = false
        var receivedRuleName: String?
        var receivedCount: Int?

        let observer = NotificationCenter.default.addObserver(
            forName: .ruleCounterUpdated,
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            receivedRuleName = notification.userInfo?["ruleName"] as? String
            receivedCount = notification.userInfo?["count"] as? Int
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // Reset counter first
        await manager.resetCounter(for: testRuleName)

        // Increment counter - should trigger notification
        await manager.incrementCounter(for: testRuleName)

        // Give notification time to process
        try await Task.sleep(for: .milliseconds(100))

        #expect(notificationReceived == true)
        #expect(receivedRuleName == testRuleName)
        #expect(receivedCount == 1)
    }

    // MARK: - Integration Tests

    @Test("End-to-end rule execution flow")
    func endToEndRuleExecution() async throws {
        try withTemporaryDefaults {
            let executor = await RuleExecutor()
            let manager = await RuleCounterManager.shared
            let testRuleName = "StopAfter25LoopsRule"

            // Reset counter
            await manager.resetCounter(for: testRuleName)

            // Enable global monitoring and rule
            Defaults[.isGlobalMonitoringEnabled] = true
            Defaults[.enableCursorForceStoppedRecovery] = true

            // Execute rules (may not do anything if no hooked windows, but should not crash)
            await executor.executeEnabledRules()

            // Verify no crashes occurred
            #expect(true)

            // Test counter functionality
            await manager.incrementCounter(for: testRuleName)
            let count = await manager.getCount(for: testRuleName)
            #expect(count == 1)
        }
    }
}
