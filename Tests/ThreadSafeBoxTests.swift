import Testing
import Foundation
@testable import CodeLooper

@Test("ThreadSafeBox - Basic Operations")
func testThreadSafeBoxBasicOperations() async throws {
    let box = ThreadSafeBox(42)
    
    // Test initial value
    #expect(box.get() == 42)
    
    // Test setting new value
    box.set(100)
    #expect(box.get() == 100)
    
    // Test updating with transform
    box.update { $0 * 2 }
    #expect(box.get() == 200)
}

@Test("ThreadSafeBox - Read Transform")
func testThreadSafeBoxReadTransform() async throws {
    let box = ThreadSafeBox("Hello")
    
    // Test read with transform
    let length = box.read { $0.count }
    #expect(length == 5)
    
    let uppercased = box.read { $0.uppercased() }
    #expect(uppercased == "HELLO")
    
    // Original value should remain unchanged
    #expect(box.get() == "Hello")
}

@Test("ThreadSafeBox - Concurrent Access")
func testThreadSafeBoxConcurrentAccess() async throws {
    let box = ThreadSafeBox(0)
    let iterations = 1000
    
    // Test concurrent writes
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask {
                box.update { $0 + 1 }
            }
        }
    }
    
    // All increments should have been applied
    #expect(box.get() == iterations)
}

@Test("ThreadSafeBox - Concurrent Reads and Writes")
func testThreadSafeBoxConcurrentReadsAndWrites() async throws {
    let box = ThreadSafeBox(100)
    var readResults: [Int] = []
    let readResultsLock = NSLock()
    
    await withTaskGroup(of: Void.self) { group in
        // Add writers
        for i in 1...10 {
            group.addTask {
                box.set(i * 10)
            }
        }
        
        // Add readers
        for _ in 1...50 {
            group.addTask {
                let value = box.get()
                readResultsLock.lock()
                readResults.append(value)
                readResultsLock.unlock()
            }
        }
    }
    
    // Should have read some values
    #expect(readResults.count == 50)
    
    // All read values should be valid (either initial or one of the written values)
    let validValues = Set([100] + (1...10).map { $0 * 10 })
    for value in readResults {
        #expect(validValues.contains(value))
    }
}

@Test("ThreadSafeBox - Boolean Extensions")
func testThreadSafeBoxBooleanExtensions() async throws {
    let box = ThreadSafeBox(false)
    
    // Test initial value
    #expect(box.get() == false)
    
    // Test toggle
    box.toggle()
    #expect(box.get() == true)
    
    box.toggle()
    #expect(box.get() == false)
    
    // Test setTrue
    box.setTrue()
    #expect(box.get() == true)
    
    // Test setFalse
    box.setFalse()
    #expect(box.get() == false)
}

@Test("ThreadSafeBox - Numeric Extensions")
func testThreadSafeBoxNumericExtensions() async throws {
    let intBox = ThreadSafeBox(10)
    
    // Test increment
    intBox.increment()
    #expect(intBox.get() == 11)
    
    intBox.increment(by: 5)
    #expect(intBox.get() == 16)
    
    // Test decrement
    intBox.decrement()
    #expect(intBox.get() == 15)
    
    intBox.decrement(by: 3)
    #expect(intBox.get() == 12)
    
    // Test with Double
    let doubleBox = ThreadSafeBox(1.5)
    doubleBox.increment(by: 2.5)
    #expect(doubleBox.get() == 4.0)
    
    doubleBox.decrement(by: 1.0)
    #expect(doubleBox.get() == 3.0)
}

@Test("ThreadSafeBox - Equatable Extensions")
func testThreadSafeBoxEquatableExtensions() async throws {
    let box = ThreadSafeBox("test")
    
    // Test equals
    #expect(box.equals("test") == true)
    #expect(box.equals("other") == false)
    
    box.set("changed")
    #expect(box.equals("changed") == true)
    #expect(box.equals("test") == false)
}

@Test("ThreadSafeBox - Complex Data Types")
func testThreadSafeBoxComplexDataTypes() async throws {
    struct TestData: Sendable, Equatable {
        let id: Int
        let name: String
    }
    
    let initialData = TestData(id: 1, name: "Initial")
    let box = ThreadSafeBox(initialData)
    
    #expect(box.get() == initialData)
    
    let newData = TestData(id: 2, name: "Updated")
    box.set(newData)
    #expect(box.get() == newData)
    
    // Test with optional
    let optionalBox = ThreadSafeBox<String?>(nil)
    #expect(optionalBox.get() == nil)
    
    optionalBox.set("value")
    #expect(optionalBox.get() == "value")
    
    optionalBox.set(nil)
    #expect(optionalBox.get() == nil)
}

@Test("ThreadSafeBox - Performance")
func testThreadSafeBoxPerformance() async throws {
    let box = ThreadSafeBox(0)
    let startTime = Date()
    
    // Perform many operations
    for i in 0..<10000 {
        if i % 2 == 0 {
            box.set(i)
        } else {
            let _ = box.get()
        }
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    #expect(elapsed < 1.0) // Should complete quickly
}

@Test("ThreadSafeBox - Memory Safety")
func testThreadSafeBoxMemorySafety() async throws {
    var boxes: [ThreadSafeBox<Int>] = []
    
    // Create many boxes
    for i in 0..<100 {
        let box = ThreadSafeBox(i)
        boxes.append(box)
    }
    
    // Test concurrent access across multiple boxes
    await withTaskGroup(of: Void.self) { group in
        for (index, box) in boxes.enumerated() {
            group.addTask {
                box.update { $0 + index }
                let _ = box.get()
            }
        }
    }
    
    // Verify all boxes have expected values
    for (index, box) in boxes.enumerated() {
        #expect(box.get() == index + index) // original + index
    }
    
    // Clear references
    boxes.removeAll()
    #expect(boxes.isEmpty)
}

@Test("ThreadSafeBox - Thread Safety with Weak References")
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
    
    #expect(box.get() == true)
    #expect(resumedBox.get() == true)
}

@Test("ThreadSafeBox - Error Conditions")
func testThreadSafeBoxErrorConditions() async throws {
    // Test with extreme values
    let maxIntBox = ThreadSafeBox(Int.max)
    #expect(maxIntBox.get() == Int.max)
    
    let minIntBox = ThreadSafeBox(Int.min)
    #expect(minIntBox.get() == Int.min)
    
    // Test with empty string
    let emptyStringBox = ThreadSafeBox("")
    #expect(emptyStringBox.get() == "")
    
    emptyStringBox.update { $0 + "test" }
    #expect(emptyStringBox.get() == "test")
}

@Test("ThreadSafeBox - Type Safety")
func testThreadSafeBoxTypeSafety() async throws {
    // Test that different types work correctly
    let stringBox = ThreadSafeBox("string")
    let intBox = ThreadSafeBox(42)
    let boolBox = ThreadSafeBox(true)
    let arrayBox = ThreadSafeBox([1, 2, 3])
    let dictBox = ThreadSafeBox(["key": "value"])
    
    #expect(stringBox.get() == "string")
    #expect(intBox.get() == 42)
    #expect(boolBox.get() == true)
    #expect(arrayBox.get() == [1, 2, 3])
    #expect(dictBox.get() == ["key": "value"])
    
    // Test type inference works
    arrayBox.update { $0 + [4, 5] }
    #expect(arrayBox.get() == [1, 2, 3, 4, 5])
    
    dictBox.update { dict in
        var newDict = dict
        newDict["new"] = "added"
        return newDict
    }
    #expect(dictBox.get() == ["key": "value", "new": "added"])
}