@testable import CodeLooper
import Foundation
import Testing

// Helper actor for thread-safe counting
actor TestCounter {
    private var count = 0
    private var lastValue = 0
    private var results: [String] = []
    
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
}

@MainActor
@Test("Debouncer - Single Call Execution")
func debouncerSingleCall() async throws {
    let debouncer = Debouncer(delay: 0.1)
    let counter = TestCounter()

    debouncer.call {
        Task {
            await counter.increment()
        }
    }

    // Wait for debounce delay + some buffer
    try await Task.sleep(for: .milliseconds(150))

    // Should have been called exactly once
    let finalCount = await counter.getCount()
    #expect(finalCount == 1)
}

@MainActor
@Test("Debouncer - Multiple Rapid Calls")
func debouncerMultipleRapidCalls() async throws {
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

    // Wait for debounce delay + buffer
    try await Task.sleep(for: .milliseconds(150))

    // Should only have been called once with the last value
    let (finalCallCount, finalLastValue) = await counter.getCountAndValue()
    #expect(finalCallCount == 1)
    #expect(finalLastValue == 5)
}

@MainActor
@Test("Debouncer - Cancellation Behavior")
func debouncerCancellation() async throws {
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

    // Wait for full debounce delay + buffer
    try await Task.sleep(for: .milliseconds(250))

    // Should only have been called once (the second call)
    let finalCount = await counter.getCount()
    #expect(finalCount == 1)
}

@MainActor
@Test("Debouncer - Different Delay Intervals")
func debouncerDifferentDelays() async throws {
    let shortDebouncer = Debouncer(delay: 0.05)
    let longDebouncer = Debouncer(delay: 0.15)

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
    try await Task.sleep(for: .milliseconds(80))

    let shortCount1 = await shortCounter.getCount()
    let longCount1 = await longCounter.getCount()
    #expect(shortCount1 == 1)
    #expect(longCount1 == 0)

    // Wait for long debouncer to fire
    try await Task.sleep(for: .milliseconds(100))

    let shortCount2 = await shortCounter.getCount()
    let longCount2 = await longCounter.getCount()
    #expect(shortCount2 == 1)
    #expect(longCount2 == 1)
}

@MainActor
@Test("Debouncer - Action Captures Context")
func debouncerActionCapturesContext() async throws {
    let debouncer = Debouncer(delay: 0.05)
    let counter = TestCounter()

    let context = "test_context"
    debouncer.call {
        Task {
            await counter.append(context)
        }
    }

    try await Task.sleep(for: .milliseconds(80))

    let finalResults = await counter.getResults()
    #expect(finalResults == ["test_context"])
}

@MainActor
@Test("Debouncer - Concurrent Access Safety")
func debouncerConcurrentAccess() async throws {
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

    // Wait for debounce delay + buffer
    try await Task.sleep(for: .milliseconds(80))

    // Should only have been called once despite multiple concurrent calls
    let finalCount = await counter.getCount()
    #expect(finalCount == 1)
}

@MainActor
@Test("Debouncer - Zero Delay Behavior")
func debouncerZeroDelay() async throws {
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
    #expect(finalCount == 1)
}

@MainActor
@Test("Debouncer - Multiple Instances Independence")
func debouncerMultipleInstancesIndependence() async throws {
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

    // Both should have fired independently
    let finalCount1 = await counter1.getCount()
    let finalCount2 = await counter2.getCount()
    #expect(finalCount1 == 1)
    #expect(finalCount2 == 1)
}