@testable import CodeLooper
import Foundation
import Testing

// MARK: - Test Suite with Tags and Organization

@Suite("ThreadSafeBox Tests", .tags(.threading, .utilities, .core))
struct ThreadSafeBoxTests {
    // MARK: - Basic Operations Suite

    @Suite("Basic Operations", .tags(.basic, .synchronous))
    struct BasicOperations {
        @Test("Initial value is preserved correctly", arguments: testValues)
        func initialValue(value: Int) async throws {
            let box = ThreadSafeBox(value)
            #expect(box.get() == value, "Initial value should be preserved")
        }

        @Test("Setting new values works correctly", arguments: zip(testValues, testValues.reversed()))
        func settingValues(initial: Int, newValue: Int) async throws {
            let box = ThreadSafeBox(initial)
            #expect(box.get() == initial, "Initial value verification")

            box.set(newValue)
            #expect(box.get() == newValue, "New value should be set correctly")
        }

        @Test("Transform operations preserve type safety", arguments: testStrings)
        func transformOperations(input: String) async throws {
            let box = ThreadSafeBox(input)

            // Test read transform without mutation
            let length = box.read { $0.count }
            #expect(length == input.count, "Length should match input")
            #expect(box.get() == input, "Original value should remain unchanged")

            // Test update transform with mutation
            box.update { $0.uppercased() }
            #expect(box.get() == input.uppercased(), "Value should be transformed correctly")
        }
    }

    // MARK: - Concurrency Test Suite

    @Suite("Concurrency Safety", .tags(.threading, .performance, .async))
    struct ConcurrencySafety {
        @Test("Concurrent increments are thread-safe", .timeLimit(.minutes(1)))
        func concurrentIncrements() async throws {
            let box = ThreadSafeBox(0)
            let iterations = 1000

            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< iterations {
                    group.addTask {
                        box.update { $0 + 1 }
                    }
                }
            }

            #expect(box.get() == iterations, "All increments should be applied atomically")
        }

        @Test("Mixed read/write operations maintain consistency")
        func mixedOperations() async throws {
            let box = ThreadSafeBox(100)

            // Use actor for collecting results safely
            actor ResultCollector {
                private var results: [Int] = []

                func append(_ value: Int) {
                    results.append(value)
                }

                func getResults() -> [Int] {
                    results
                }
            }

            let collector = ResultCollector()

            await withTaskGroup(of: Void.self) { group in
                // Add writers
                for i in 1 ... 10 {
                    group.addTask {
                        box.set(i * 10)
                    }
                }

                // Add readers
                for _ in 1 ... 50 {
                    group.addTask {
                        let value = box.get()
                        await collector.append(value)
                    }
                }
            }

            let readResults = await collector.getResults()

            #expect(readResults.count == 50, "Should have 50 read results")

            // All values should be valid (either initial or written values)
            let validValues = Set([100] + (1 ... 10).map { $0 * 10 })
            for value in readResults {
                #expect(validValues.contains(value), "Read value \(value) should be valid")
            }
        }

        @Test("High contention scenario stress test", .timeLimit(.minutes(1)))
        func highContentionStressTest() async throws {
            let box = ThreadSafeBox("")
            let taskCount = 100
            let operationsPerTask = 50

            await withTaskGroup(of: Void.self) { group in
                for taskId in 0 ..< taskCount {
                    group.addTask {
                        for opId in 0 ..< operationsPerTask {
                            if opId % 2 == 0 {
                                box.update { "\($0)_\(taskId)_\(opId)" }
                            } else {
                                _ = box.read { $0.count }
                            }
                        }
                    }
                }
            }

            let finalValue = box.get()
            #expect(!finalValue.isEmpty, "Final value should not be empty after operations")
        }
    }

    // MARK: - Type Safety Suite

    @Suite("Type Safety", .tags(.types, .generics))
    struct TypeSafety {
        @Test("Boolean extensions work correctly")
        func booleanExtensions() async throws {
            let box = ThreadSafeBox(false)

            #expect(box.get() == false, "Initial value should be false")

            box.toggle()
            #expect(box.get() == true, "Toggle should flip to true")

            box.setFalse()
            #expect(box.get() == false, "setFalse should set to false")

            box.setTrue()
            #expect(box.get() == true, "setTrue should set to true")
        }

        @Test("Numeric extensions work with different types")
        func numericExtensions() async throws {
            // Test Int
            let intBox = ThreadSafeBox(10)
            intBox.increment()
            #expect(intBox.get() == 11, "Increment should work")

            intBox.increment(by: 5)
            #expect(intBox.get() == 16, "Increment by amount should work")

            intBox.decrement(by: 3)
            #expect(intBox.get() == 13, "Decrement by amount should work")

            // Test Double
            let doubleBox = ThreadSafeBox(1.5)
            doubleBox.increment(by: 2.5)
            #expect(doubleBox.get() == 4.0, "Double increment should work")
        }

        @Test("Complex data types maintain integrity")
        func complexDataTypes() async throws {
            struct TestData: Sendable, Equatable {
                let id: Int
                let name: String
                let timestamp: Date
            }

            let initialData = TestData(id: 1, name: "Initial", timestamp: Date())
            let box = ThreadSafeBox(initialData)

            #expect(box.get() == initialData, "Initial complex data should be preserved")

            let newData = TestData(id: 2, name: "Updated", timestamp: Date())
            box.set(newData)
            #expect(box.get() == newData, "Complex data should be updated correctly")

            // Test with collections
            let arrayBox = ThreadSafeBox([1, 2, 3])
            arrayBox.update { $0 + [4, 5] }
            #expect(arrayBox.get() == [1, 2, 3, 4, 5], "Array operations should work")
        }

        @Test("Optional types are handled correctly")
        func optionalTypes() async throws {
            let optionalBox = ThreadSafeBox<String?>(nil)
            #expect(optionalBox.get() == nil, "Initial nil value should be preserved")

            optionalBox.set("value")
            #expect(optionalBox.get() == "value", "Optional should hold value")

            optionalBox.set(nil)
            #expect(optionalBox.get() == nil, "Optional should be reset to nil")
        }
    }

    // MARK: - Performance Tests Suite

    @Suite("Performance", .tags(.performance, .memory))
    struct Performance {
        @Test("Operations complete within reasonable time", .timeLimit(.minutes(1)))
        func operationPerformance() async throws {
            let box = ThreadSafeBox(0)
            let operationCount = 10000

            let startTime = ContinuousClock().now

            for i in 0 ..< operationCount {
                if i % 2 == 0 {
                    box.set(i)
                } else {
                    _ = box.get()
                }
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(1), "10k operations should complete quickly")
        }

        @Test("Memory usage remains stable under load")
        func memoryStability() async throws {
            var boxes: [ThreadSafeBox<Int>] = []

            // Create many boxes
            for i in 0 ..< 1000 {
                let box = ThreadSafeBox(i)
                boxes.append(box)
            }

            // Test concurrent access across multiple boxes
            await withTaskGroup(of: Void.self) { group in
                for (index, box) in boxes.enumerated() {
                    group.addTask {
                        box.update { $0 + index }
                        _ = box.get()
                    }
                }
            }

            // Verify all boxes have expected values
            for (index, box) in boxes.enumerated() {
                #expect(box.get() == index + index, "Box \(index) should have correct value")
            }

            boxes.removeAll()
            #expect(boxes.isEmpty, "Cleanup should work correctly")
        }
    }

    // MARK: - Edge Cases Suite

    @Suite("Edge Cases", .tags(.edge_cases, .robustness))
    struct EdgeCases {
        @Test("Extreme values are handled correctly")
        func extremeValues() async throws {
            // Test with extreme integers
            let maxIntBox = ThreadSafeBox(Int.max)
            #expect(maxIntBox.get() == Int.max, "Max int should be preserved")

            let minIntBox = ThreadSafeBox(Int.min)
            #expect(minIntBox.get() == Int.min, "Min int should be preserved")

            // Test with empty collections
            let emptyArrayBox = ThreadSafeBox<[String]>([])
            #expect(emptyArrayBox.get().isEmpty, "Empty array should be preserved")

            emptyArrayBox.update { $0 + ["test"] }
            #expect(emptyArrayBox.get() == ["test"], "Empty array should be updatable")
        }

        @Test("Zero delay concurrent operations")
        func zeroDeleyConcurrentOps() async throws {
            let box = ThreadSafeBox(false)
            let resumedBox = ThreadSafeBox(false)

            // Simulate WebSocketManager pattern
            await withCheckedContinuation { continuation in
                box.set(true)

                if !resumedBox.get() {
                    resumedBox.set(true)
                    continuation.resume()
                }
            }

            #expect(box.get() == true, "First box should be true")
            #expect(resumedBox.get() == true, "Second box should be true")
        }

        @Test("Rapid state transitions maintain consistency")
        func rapidStateTransitions() async throws {
            let box = ThreadSafeBox(0)

            await withTaskGroup(of: Void.self) { group in
                // Multiple tasks performing rapid state changes
                for _ in 0 ..< 10 {
                    group.addTask {
                        for i in 0 ..< 100 {
                            box.update { _ in i }
                        }
                    }
                }
            }

            let finalValue = box.get()
            #expect(finalValue >= 0 && finalValue < 100, "Final value should be within expected range")
        }
    }

    // MARK: - Memory Leak Tests

    @Suite("Memory Management", .tags(.memory, .reliability))
    struct MemoryManagement {
        @Test("ThreadSafeBox instances are properly deallocated")
        func threadSafeBoxMemoryLeaks() async throws {
            weak var weakBox: ThreadSafeBox<String>?
            
            // Create a scope where the box will be deallocated
            do {
                let box = ThreadSafeBox("test-value")
                weakBox = box
                
                // Verify the box works correctly
                #expect(box.get() == "test-value")
                box.set("updated-value")
                #expect(box.get() == "updated-value")
                
                // weakBox should still be alive here
                #expect(weakBox != nil, "Box should be alive within scope")
            }
            
            // Force deallocation by yielding to the runtime
            await Task.yield()
            
            // After the scope, the box should be deallocated
            #expect(weakBox == nil, "Box should be deallocated after scope ends")
        }
        
        @Test("Multiple ThreadSafeBox instances don't retain each other")
        func multipleBoxesNoRetainCycles() async throws {
            weak var weakBox1: ThreadSafeBox<Int>?
            weak var weakBox2: ThreadSafeBox<Int>?
            
            do {
                let box1 = ThreadSafeBox(100)
                let box2 = ThreadSafeBox(200)
                
                weakBox1 = box1
                weakBox2 = box2
                
                // Boxes operate independently
                box1.set(box2.get() + 50)
                #expect(box1.get() == 250)
                #expect(box2.get() == 200)
                
                // Both should be alive
                #expect(weakBox1 != nil)
                #expect(weakBox2 != nil)
            }
            
            await Task.yield()
            
            // Both should be deallocated
            #expect(weakBox1 == nil, "First box should be deallocated")
            #expect(weakBox2 == nil, "Second box should be deallocated")
        }
    }

    // MARK: - Test Fixtures and Setup

    /// Test fixture for creating different box types
    static let testValues = [
        42, 100, 200, 500, 1000,
    ]

    static let testStrings = [
        "Hello", "World", "Swift", "Testing", "Framework",
    ]

    // MARK: - Parameterized Tests

    @Test("Equals method works correctly", arguments: [
        ("test", "test", true),
        ("test", "other", false),
        ("", "", true),
        ("swift", "Swift", false),
    ])
    func equalsMethod(value1: String, value2: String, shouldEqual: Bool) async throws {
        let box = ThreadSafeBox(value1)

        if shouldEqual {
            #expect(box.equals(value2), "'\(value1)' should equal '\(value2)'")
        } else {
            #expect(!box.equals(value2), "'\(value1)' should not equal '\(value2)'")
        }
    }

    // MARK: - Conditional Tests

    @Test("Debug-only behavior verification")
    func debugOnlyBehavior() async throws {
        #if DEBUG
            let box = ThreadSafeBox("debug_mode")
            #expect(box.get() == "debug_mode", "Debug mode should be active")
        #else
            let box = ThreadSafeBox("release_mode")
            #expect(box.get() == "release_mode", "Release mode should be active")
        #endif
    }
}

