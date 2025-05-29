import Testing
import Foundation
@testable import CodeLooper

@MainActor
@Test("Debouncer - Single Call Execution")
func testDebouncerSingleCall() async throws {
    let debouncer = Debouncer(delay: 0.1)
    var callCount = 0
    
    debouncer.call {
        callCount += 1
    }
    
    // Wait for debounce delay + some buffer
    try await Task.sleep(for: .milliseconds(150))
    
    // Should have been called exactly once
    #expect(callCount == 1)
}

@MainActor
@Test("Debouncer - Multiple Rapid Calls")
func testDebouncerMultipleRapidCalls() async throws {
    let debouncer = Debouncer(delay: 0.1)
    var callCount = 0
    var lastValue = 0
    
    // Fire multiple calls rapidly
    for i in 1...5 {
        debouncer.call {
            callCount += 1
            lastValue = i
        }
        // Small delay between calls (much less than debounce delay)
        try await Task.sleep(for: .milliseconds(10))
    }
    
    // Wait for debounce delay + buffer
    try await Task.sleep(for: .milliseconds(150))
    
    // Should only have been called once with the last value
    #expect(callCount == 1)
    #expect(lastValue == 5)
}

@MainActor
@Test("Debouncer - Cancellation Behavior")
func testDebouncerCancellation() async throws {
    let debouncer = Debouncer(delay: 0.2)
    var callCount = 0
    
    debouncer.call {
        callCount += 1
    }
    
    // Wait less than debounce delay
    try await Task.sleep(for: .milliseconds(50))
    
    // Make another call (should cancel the first one)
    debouncer.call {
        callCount += 1
    }
    
    // Wait for full debounce delay + buffer
    try await Task.sleep(for: .milliseconds(250))
    
    // Should only have been called once (the second call)
    #expect(callCount == 1)
}

@MainActor
@Test("Debouncer - Different Delay Intervals")
func testDebouncerDifferentDelays() async throws {
    let shortDebouncer = Debouncer(delay: 0.05)
    let longDebouncer = Debouncer(delay: 0.15)
    
    var shortCallCount = 0
    var longCallCount = 0
    
    shortDebouncer.call {
        shortCallCount += 1
    }
    
    longDebouncer.call {
        longCallCount += 1
    }
    
    // Wait for short debouncer to fire but not long
    try await Task.sleep(for: .milliseconds(80))
    
    #expect(shortCallCount == 1)
    #expect(longCallCount == 0)
    
    // Wait for long debouncer to fire
    try await Task.sleep(for: .milliseconds(100))
    
    #expect(shortCallCount == 1)
    #expect(longCallCount == 1)
}

@MainActor
@Test("Debouncer - Action Captures Context")
func testDebouncerActionCapturesContext() async throws {
    let debouncer = Debouncer(delay: 0.05)
    var results: [String] = []
    
    let context = "test_context"
    debouncer.call {
        results.append(context)
    }
    
    try await Task.sleep(for: .milliseconds(80))
    
    #expect(results == ["test_context"])
}

@MainActor
@Test("Debouncer - Concurrent Access Safety")
func testDebouncerConcurrentAccess() async throws {
    let debouncer = Debouncer(delay: 0.05)
    var callCount = 0
    
    // Simulate concurrent calls from different contexts
    await withTaskGroup(of: Void.self) { group in
        for i in 1...10 {
            group.addTask { @MainActor in
                debouncer.call {
                    callCount += 1
                }
            }
        }
    }
    
    // Wait for debounce delay + buffer
    try await Task.sleep(for: .milliseconds(80))
    
    // Should only have been called once despite multiple concurrent calls
    #expect(callCount == 1)
}

@MainActor
@Test("Debouncer - Zero Delay Behavior")
func testDebouncerZeroDelay() async throws {
    let debouncer = Debouncer(delay: 0.0)
    var callCount = 0
    
    debouncer.call {
        callCount += 1
    }
    
    // Even with zero delay, give time for async execution
    try await Task.sleep(for: .milliseconds(10))
    
    #expect(callCount == 1)
}

@MainActor
@Test("Debouncer - Multiple Instances Independence")
func testDebouncerMultipleInstancesIndependence() async throws {
    let debouncer1 = Debouncer(delay: 0.05)
    let debouncer2 = Debouncer(delay: 0.05)
    
    var count1 = 0
    var count2 = 0
    
    debouncer1.call {
        count1 += 1
    }
    
    debouncer2.call {
        count2 += 1
    }
    
    try await Task.sleep(for: .milliseconds(80))
    
    // Both should have fired independently
    #expect(count1 == 1)
    #expect(count2 == 1)
}