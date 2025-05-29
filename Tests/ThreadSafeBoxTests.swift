@testable import CodeLooper
import Foundation
import XCTest

class ThreadSafeBoxTests: XCTestCase {
    func testThreadSafeBoxBasicOperations() async throws {
        let box = ThreadSafeBox(42)

        // Test initial value
        XCTAssertEqual(box.get(), 42)

        // Test setting new value
        box.set(100)
        XCTAssertEqual(box.get(), 100)

        // Test updating with transform
        box.update { $0 * 2 }
        XCTAssertEqual(box.get(), 200)
    }

    func testThreadSafeBoxReadTransform() async throws {
        let box = ThreadSafeBox("Hello")

        // Test read with transform
        let length = box.read { $0.count }
        XCTAssertEqual(length, 5)

        let uppercased = box.read { $0.uppercased() }
        XCTAssertEqual(uppercased, "HELLO")

        // Original value should remain unchanged
        XCTAssertEqual(box.get(), "Hello")
    }

    func testThreadSafeBoxConcurrentAccess() async throws {
        let box = ThreadSafeBox(0)
        let iterations = 1000

        // Test concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< iterations {
                group.addTask {
                    box.update { $0 + 1 }
                }
            }
        }

        // All increments should have been applied
        XCTAssertEqual(box.get(), iterations)
    }

    func testThreadSafeBoxConcurrentReadsAndWrites() async throws {
        let box = ThreadSafeBox(100)
        // Use an actor to collect results safely
        actor ResultCollector {
            var results: [Int] = []
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

        // Should have read some values
        XCTAssertEqual(readResults.count, 50)

        // All read values should be valid (either initial or one of the written values)
        let validValues = Set([100] + (1 ... 10).map { $0 * 10 })
        for value in readResults {
            XCTAssertTrue(validValues.contains(value))
        }
    }

    func testThreadSafeBoxBooleanExtensions() async throws {
        let box = ThreadSafeBox(false)

        // Test initial value
        XCTAssertEqual(box.get(), false)

        // Test toggle
        box.toggle()
        XCTAssertEqual(box.get(), true)

        box.toggle()
        XCTAssertEqual(box.get(), false)

        // Test setTrue
        box.setTrue()
        XCTAssertEqual(box.get(), true)

        // Test setFalse
        box.setFalse()
        XCTAssertEqual(box.get(), false)
    }

    func testThreadSafeBoxNumericExtensions() async throws {
        let intBox = ThreadSafeBox(10)

        // Test increment
        intBox.increment()
        XCTAssertEqual(intBox.get(), 11)

        intBox.increment(by: 5)
        XCTAssertEqual(intBox.get(), 16)

        // Test decrement
        intBox.decrement()
        XCTAssertEqual(intBox.get(), 15)

        intBox.decrement(by: 3)
        XCTAssertEqual(intBox.get(), 12)

        // Test with Double
        let doubleBox = ThreadSafeBox(1.5)
        doubleBox.increment(by: 2.5)
        XCTAssertEqual(doubleBox.get(), 4.0)

        doubleBox.decrement(by: 1.0)
        XCTAssertEqual(doubleBox.get(), 3.0)
    }

    func testThreadSafeBoxEquatableExtensions() async throws {
        let box = ThreadSafeBox("test")

        // Test equals
        XCTAssertTrue(box.equals("test"))
        XCTAssertFalse(box.equals("other"))

        box.set("changed")
        XCTAssertTrue(box.equals("changed"))
        XCTAssertFalse(box.equals("test"))
    }

    func testThreadSafeBoxComplexDataTypes() async throws {
        struct TestData: Sendable, Equatable {
            let id: Int
            let name: String
        }

        let initialData = TestData(id: 1, name: "Initial")
        let box = ThreadSafeBox(initialData)

        XCTAssertEqual(box.get(), initialData)

        let newData = TestData(id: 2, name: "Updated")
        box.set(newData)
        XCTAssertEqual(box.get(), newData)

        // Test with optional
        let optionalBox = ThreadSafeBox<String?>(nil)
        XCTAssertNil(optionalBox.get())

        optionalBox.set("value")
        XCTAssertEqual(optionalBox.get(), "value")

        optionalBox.set(nil)
        XCTAssertNil(optionalBox.get())
    }

    func testThreadSafeBoxPerformance() async throws {
        let box = ThreadSafeBox(0)
        let startTime = Date()

        // Perform many operations
        for i in 0 ..< 10000 {
            if i % 2 == 0 {
                box.set(i)
            } else {
                _ = box.get()
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 1.0) // Should complete quickly
    }

    func testThreadSafeBoxMemorySafety() async throws {
        var boxes: [ThreadSafeBox<Int>] = []

        // Create many boxes
        for i in 0 ..< 100 {
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
            XCTAssertEqual(box.get(), index + index) // original + index
        }

        // Clear references
        boxes.removeAll()
        XCTAssertTrue(boxes.isEmpty)
    }

    func testThreadSafeBoxThreadSafetyWithWeakReferences() async throws {
        let box = ThreadSafeBox(false)
        let resumedBox = ThreadSafeBox(false)

        // Simulate the pattern used in WebSocketManager
        await withCheckedContinuation { continuation in
            box.set(true)

            if !resumedBox.get() {
                resumedBox.set(true)
                continuation.resume()
            }
        }

        XCTAssertEqual(box.get(), true)
        XCTAssertEqual(resumedBox.get(), true)
    }

    func testThreadSafeBoxErrorConditions() async throws {
        // Test with extreme values
        let maxIntBox = ThreadSafeBox(Int.max)
        XCTAssertEqual(maxIntBox.get(), Int.max)

        let minIntBox = ThreadSafeBox(Int.min)
        XCTAssertEqual(minIntBox.get(), Int.min)

        // Test with empty string
        let emptyStringBox = ThreadSafeBox("")
        XCTAssertEqual(emptyStringBox.get(), "")

        emptyStringBox.update { $0 + "test" }
        XCTAssertEqual(emptyStringBox.get(), "test")
    }

    func testThreadSafeBoxTypeSafety() async throws {
        // Test that different types work correctly
        let stringBox = ThreadSafeBox("string")
        let intBox = ThreadSafeBox(42)
        let boolBox = ThreadSafeBox(true)
        let arrayBox = ThreadSafeBox([1, 2, 3])
        let dictBox = ThreadSafeBox(["key": "value"])

        XCTAssertEqual(stringBox.get(), "string")
        XCTAssertEqual(intBox.get(), 42)
        XCTAssertEqual(boolBox.get(), true)
        XCTAssertEqual(arrayBox.get(), [1, 2, 3])
        XCTAssertEqual(dictBox.get(), ["key": "value"])

        // Test type inference works
        arrayBox.update { $0 + [4, 5] }
        XCTAssertEqual(arrayBox.get(), [1, 2, 3, 4, 5])

        dictBox.update { dict in
            var newDict = dict
            newDict["new"] = "added"
            return newDict
        }
        XCTAssertEqual(dictBox.get(), ["key": "value", "new": "added"])
    }
}