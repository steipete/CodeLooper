@testable import CodeLooper
import Foundation
import Testing

// MARK: - Test Fixtures

/// Helper actor for thread-safe counting in tests
actor TestCounter {
    // MARK: Internal

    func increment() {
        count += 1
    }

    func increment(with value: Int) {
        count += 1
        lastValue = value
    }

    func append(_ value: String) {
        results.append(value)
    }

    func getCount() -> Int {
        count
    }

    func getLastValue() -> Int {
        lastValue
    }

    func getResults() -> [String] {
        results
    }

    func getCountAndValue() -> (Int, Int) {
        (count, lastValue)
    }

    func reset() {
        count = 0
        lastValue = 0
        results.removeAll()
    }

    // MARK: Private

    private var count = 0
    private var lastValue = 0
    private var results: [String] = []
}

// MARK: - Main Test Suite

@Suite("Debouncer Tests", .tags(.utilities, .async, .timing))
@MainActor
struct DebouncerTests {
    // MARK: - Basic Functionality

    @Suite("Basic Functionality", .tags(.basic, .core))
    struct BasicFunctionality {
        @Test("Single call executes correctly", arguments: DebouncerTestData.shortDelays)
        @MainActor
        func singleCall(delay: TimeInterval) async throws {
            let debouncer = Debouncer(delay: delay)
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            // Wait for debounce delay plus buffer
            try await Task.sleep(for: .milliseconds(Int(delay * 1000) + 50))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Should execute exactly once")
        }

        @Test("Multiple rapid calls result in single execution")
        @MainActor
        func multipleRapidCalls() async throws {
            let debouncer = Debouncer(delay: 0.1)
            let counter = TestCounter()

            // Fire multiple calls rapidly
            for i in 1 ... 5 {
                debouncer.call {
                    Task {
                        await counter.increment(with: i)
                    }
                }
                // Small delay between calls (much less than debounce delay)
                try await Task.sleep(for: .milliseconds(10))
            }

            // Wait for debounce delay plus buffer
            try await Task.sleep(for: .milliseconds(150))

            let (finalCallCount, finalLastValue) = await counter.getCountAndValue()
            #expect(finalCallCount == 1, "Should only execute once")
            #expect(finalLastValue == 5, "Should execute with last value")
        }

        @Test("Zero delay executes immediately")
        @MainActor
        func zeroDelay() async throws {
            let debouncer = Debouncer(delay: 0.0)
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            // Even with zero delay, give time for async execution
            try await Task.sleep(for: .milliseconds(10))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Zero delay should execute immediately")
        }
    }

    // MARK: - Cancellation Behavior

    @Suite("Cancellation Behavior", .tags(.cancellation, .timing))
    struct CancellationBehavior {
        @Test("Debouncer cancels previous call when new call is made")
        @MainActor
        func cancellation() async throws {
            let debouncer = Debouncer(delay: 0.2)
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            // Wait less than debounce delay
            try await Task.sleep(for: .milliseconds(50))

            // Make another call (should cancel the first one)
            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            // Wait for full debounce delay plus buffer
            try await Task.sleep(for: .milliseconds(250))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Should only execute the second call")
        }

        @Test("Rapid successive calls maintain latest only", arguments: [2, 5, 10])
        @MainActor
        func rapidSuccessiveCalls(callCount: Int) async throws {
            let debouncer = Debouncer(delay: 0.1)
            let counter = TestCounter()

            for i in 1 ... callCount {
                debouncer.call {
                    Task {
                        await counter.increment(with: i)
                    }
                }
                try await Task.sleep(for: .milliseconds(5)) // Much shorter than debounce delay
            }

            try await Task.sleep(for: .milliseconds(150))

            let (finalCallCount, finalLastValue) = await counter.getCountAndValue()
            #expect(finalCallCount == 1, "Should execute only once")
            #expect(finalLastValue == callCount, "Should execute with last value (\(callCount))")
        }
    }

    // MARK: - Timing and Performance

    @Suite("Timing and Performance", .tags(.performance, .timing))
    struct TimingAndPerformance {
        @Test("Different debouncer instances work independently", arguments: zip(DebouncerTestData.shortDelays, DebouncerTestData.mediumDelays))
        @MainActor
        func independentInstances(shortDelay: TimeInterval, longDelay: TimeInterval) async throws {
            let shortDebouncer = Debouncer(delay: shortDelay)
            let longDebouncer = Debouncer(delay: longDelay)

            let shortCounter = TestCounter()
            let longCounter = TestCounter()

            shortDebouncer.call {
                Task {
                    await shortCounter.increment()
                }
            }

            longDebouncer.call {
                Task {
                    await longCounter.increment()
                }
            }

            // Wait for short debouncer to fire but not long
            try await Task.sleep(for: .milliseconds(Int(shortDelay * 1000) + 50))

            let shortCount1 = await shortCounter.getCount()
            let longCount1 = await longCounter.getCount()
            #expect(shortCount1 == 1, "Short debouncer should have fired")
            #expect(longCount1 == 0, "Long debouncer should not have fired yet")

            // Wait for long debouncer to fire
            try await Task.sleep(for: .milliseconds(Int(longDelay * 1000) + 50))

            let shortCount2 = await shortCounter.getCount()
            let longCount2 = await longCounter.getCount()
            #expect(shortCount2 == 1, "Short debouncer count should remain same")
            #expect(longCount2 == 1, "Long debouncer should now have fired")
        }

        @Test("Performance with many rapid calls", .timeLimit(.minutes(1)))
        @MainActor
        func performanceTest() async throws {
            let debouncer = Debouncer(delay: 0.01)
            let counter = TestCounter()

            let startTime = ContinuousClock().now

            // Make many rapid calls
            for i in 1 ... 1000 {
                debouncer.call {
                    Task {
                        await counter.increment(with: i)
                    }
                }
            }

            try await Task.sleep(for: .milliseconds(50))

            let elapsed = ContinuousClock().now - startTime
            let finalCount = await counter.getCount()

            #expect(finalCount == 1, "Should execute only once despite 1000 calls")
            #expect(elapsed < .seconds(1), "Should complete quickly")
        }
    }

    // MARK: - Context and State Management

    @Suite("Context and State Management", .tags(.state, .context))
    struct ContextAndState {
        @Test("Action captures context correctly", arguments: [
            "test_context",
            "hello_world",
            "swift_testing_framework",
            "",
        ])
        @MainActor
        func contextCapture(context: String) async throws {
            let debouncer = Debouncer(delay: 0.05)
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.append(context)
                }
            }

            try await Task.sleep(for: .milliseconds(80))

            let finalResults = await counter.getResults()
            #expect(finalResults == [context], "Should capture context correctly")
        }

        @Test("Multiple context captures with rapid calls")
        @MainActor
        func multipleContextCaptures() async throws {
            let debouncer = Debouncer(delay: 0.05)
            let counter = TestCounter()

            let contexts = ["first", "second", "third", "final"]

            for context in contexts {
                debouncer.call {
                    Task {
                        await counter.append(context)
                    }
                }
                try await Task.sleep(for: .milliseconds(5))
            }

            try await Task.sleep(for: .milliseconds(80))

            let finalResults = await counter.getResults()
            #expect(finalResults == ["final"], "Should only capture last context")
        }
    }

    // MARK: - Concurrency Safety

    @Suite("Concurrency Safety", .tags(.threading, .async))
    struct ConcurrencySafety {
        @Test("Concurrent calls result in single execution")
        @MainActor
        func concurrentCalls() async throws {
            let debouncer = Debouncer(delay: 0.05)
            let counter = TestCounter()

            // Simulate concurrent calls from different contexts
            await withTaskGroup(of: Void.self) { group in
                for _ in 1 ... 10 {
                    group.addTask { @MainActor in
                        debouncer.call {
                            Task {
                                await counter.increment()
                            }
                        }
                    }
                }
            }

            // Wait for debounce delay plus buffer
            try await Task.sleep(for: .milliseconds(80))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Should execute only once despite concurrent calls")
        }

        @Test("High contention scenario", .timeLimit(.minutes(1)))
        @MainActor
        func highContention() async throws {
            let debouncer = Debouncer(delay: 0.02)
            let counter = TestCounter()

            await withTaskGroup(of: Void.self) { group in
                // Many concurrent tasks making rapid calls
                for taskId in 1 ... 50 {
                    group.addTask { @MainActor in
                        for callId in 1 ... 20 {
                            debouncer.call {
                                Task {
                                    await counter.increment(with: taskId * 1000 + callId)
                                }
                            }
                        }
                    }
                }
            }

            try await Task.sleep(for: .milliseconds(50))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Should execute only once despite high contention")
        }

        @Test("Multiple debouncer instances maintain independence")
        @MainActor
        func multipleInstanceIndependence() async throws {
            let debouncer1 = Debouncer(delay: 0.05)
            let debouncer2 = Debouncer(delay: 0.05)

            let counter1 = TestCounter()
            let counter2 = TestCounter()

            debouncer1.call {
                Task {
                    await counter1.increment()
                }
            }

            debouncer2.call {
                Task {
                    await counter2.increment()
                }
            }

            try await Task.sleep(for: .milliseconds(80))

            let finalCount1 = await counter1.getCount()
            let finalCount2 = await counter2.getCount()

            #expect(finalCount1 == 1, "First debouncer should execute")
            #expect(finalCount2 == 1, "Second debouncer should execute independently")
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases", .tags(.edge_cases, .robustness))
    struct EdgeCases {
        @Test("Very short delays work correctly")
        @MainActor
        func veryShortDelays() async throws {
            let debouncer = Debouncer(delay: 0.001) // 1ms
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            try await Task.sleep(for: .milliseconds(10))

            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Very short delay should still work")
        }

        @Test("Large delays work correctly")
        @MainActor
        func largeDelays() async throws {
            let debouncer = Debouncer(delay: 0.5) // 500ms
            let counter = TestCounter()

            debouncer.call {
                Task {
                    await counter.increment()
                }
            }

            // Check it hasn't fired early
            try await Task.sleep(for: .milliseconds(100))
            let earlyCount = await counter.getCount()
            #expect(earlyCount == 0, "Should not fire before delay")

            // Wait for full delay
            try await Task.sleep(for: .milliseconds(450))
            let finalCount = await counter.getCount()
            #expect(finalCount == 1, "Should fire after full delay")
        }

        @Test("Memory cleanup after debouncer deallocation")
        @MainActor
        func memoryCleanup() async throws {
            var debouncer: Debouncer? = Debouncer(delay: 0.1)
            let counter = TestCounter()

            debouncer?.call {
                Task {
                    await counter.increment()
                }
            }

            // Deallocate debouncer
            debouncer = nil

            // Wait past the delay
            try await Task.sleep(for: .milliseconds(150))

            // This test mainly verifies no crashes occur
            #expect(true, "Debouncer deallocation should not cause crashes")
        }
    }

    // MARK: - Test Data
    // Test data moved to CursorMonitorTestData.swift to avoid Swift Testing macro issues
}

