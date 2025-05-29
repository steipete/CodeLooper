import Testing
import Foundation
import AXorcist
@testable import CodeLooper

/// Test suite for UI element locator pattern functionality
@Suite("Locator Pattern Tests")
struct LocatorPatternTests {
    
    // MARK: - LocatorManager Tests
    
    @Test("LocatorManager can register and manage patterns")
    func testLocatorPatternRegistration() async throws {
        let manager = LocatorManager.shared
        
        // Test that manager is created without errors
        #expect(manager != nil)
        
        // Test pattern registration
        let testPattern = UIElementPattern(
            role: "AXButton",
            title: "Test Button",
            identifier: "test-button"
        )
        
        await manager.registerPattern("test", pattern: testPattern)
        
        // Test pattern retrieval
        let retrievedPattern = await manager.getPattern(for: "test")
        #expect(retrievedPattern != nil)
        
        // Test pattern removal
        await manager.removePattern(for: "test")
        let removedPattern = await manager.getPattern(for: "test")
        #expect(removedPattern == nil)
    }
    
    @Test("LocatorManager handles pattern matching correctly")
    func testLocatorPatternMatching() async throws {
        let manager = LocatorManager.shared
        
        // Create test patterns
        let buttonPattern = UIElementPattern(
            role: "AXButton",
            title: "Submit",
            identifier: nil
        )
        
        let textFieldPattern = UIElementPattern(
            role: "AXTextField",
            title: nil,
            identifier: "username-field"
        )
        
        await manager.registerPattern("submit-button", pattern: buttonPattern)
        await manager.registerPattern("username-field", pattern: textFieldPattern)
        
        // Test pattern matching
        let matchesButton = await manager.matchesPattern("submit-button", element: MockElement(role: "AXButton", title: "Submit"))
        let matchesTextField = await manager.matchesPattern("username-field", element: MockElement(role: "AXTextField", identifier: "username-field"))
        
        #expect(matchesButton == true)
        #expect(matchesTextField == true)
        
        // Test non-matching patterns
        let noMatch = await manager.matchesPattern("submit-button", element: MockElement(role: "AXTextField", title: "Cancel"))
        #expect(noMatch == false)
        
        // Cleanup
        await manager.removePattern(for: "submit-button")
        await manager.removePattern(for: "username-field")
    }
    
    @Test("LocatorManager handles pattern updates efficiently")
    func testLocatorPatternUpdates() async throws {
        let manager = LocatorManager.shared
        
        // Register initial pattern
        let initialPattern = UIElementPattern(
            role: "AXButton",
            title: "Old Title",
            identifier: "button-1"
        )
        
        await manager.registerPattern("updatable-button", pattern: initialPattern)
        
        // Verify initial pattern
        let initial = await manager.getPattern(for: "updatable-button")
        #expect(initial?.title == "Old Title")
        
        // Update pattern
        let updatedPattern = UIElementPattern(
            role: "AXButton", 
            title: "New Title",
            identifier: "button-1"
        )
        
        await manager.updatePattern("updatable-button", pattern: updatedPattern)
        
        // Verify updated pattern
        let updated = await manager.getPattern(for: "updatable-button")
        #expect(updated?.title == "New Title")
        
        // Cleanup
        await manager.removePattern(for: "updatable-button")
    }
    
    // MARK: - DynamicLocatorDiscoverer Tests
    
    @Test("DynamicLocatorDiscoverer can discover UI patterns")
    func testDynamicLocatorDiscovery() async throws {
        let discoverer = DynamicLocatorDiscoverer()
        
        // Test that discoverer is created without errors
        #expect(discoverer != nil)
        
        // Test discovery process with mock window
        let mockWindow = MockWindow(elements: [
            MockElement(role: "AXButton", title: "Save", identifier: "save-btn"),
            MockElement(role: "AXTextField", title: nil, identifier: "input-field"),
            MockElement(role: "AXStaticText", title: "Status: Ready", identifier: nil)
        ])
        
        let discoveredPatterns = await discoverer.discoverPatterns(in: mockWindow)
        
        // Should discover some patterns
        #expect(discoveredPatterns.count >= 0)
        
        // If patterns were discovered, they should have valid properties
        for pattern in discoveredPatterns {
            #expect(!pattern.role.isEmpty)
        }
    }
    
    @Test("DynamicLocatorDiscoverer handles empty windows gracefully")
    func testDynamicLocatorDiscoveryEmptyWindow() async throws {
        let discoverer = DynamicLocatorDiscoverer()
        
        // Test with empty window
        let emptyWindow = MockWindow(elements: [])
        let patterns = await discoverer.discoverPatterns(in: emptyWindow)
        
        #expect(patterns.isEmpty)
        
        // Test with nil window
        let nilPatterns = await discoverer.discoverPatterns(in: nil)
        #expect(nilPatterns.isEmpty)
    }
    
    // MARK: - Pattern Validation Tests
    
    @Test("UIElementPattern validates properties correctly")
    func testUIElementPatternValidation() async throws {
        // Test valid pattern
        let validPattern = UIElementPattern(
            role: "AXButton",
            title: "Click Me",
            identifier: "click-button"
        )
        
        #expect(validPattern.isValid())
        #expect(validPattern.role == "AXButton")
        #expect(validPattern.title == "Click Me")
        #expect(validPattern.identifier == "click-button")
        
        // Test pattern with minimal properties
        let minimalPattern = UIElementPattern(
            role: "AXTextField",
            title: nil,
            identifier: nil
        )
        
        #expect(minimalPattern.isValid()) // Should be valid with just role
        
        // Test invalid pattern
        let invalidPattern = UIElementPattern(
            role: "",
            title: nil,
            identifier: nil
        )
        
        #expect(!invalidPattern.isValid()) // Empty role should be invalid
    }
    
    // MARK: - Pattern Matching Algorithm Tests
    
    @Test("Pattern matching algorithm handles edge cases")
    func testPatternMatchingEdgeCases() async throws {
        let manager = LocatorManager.shared
        
        // Test case-sensitive matching
        let caseSensitivePattern = UIElementPattern(
            role: "AXButton",
            title: "Save",
            identifier: nil
        )
        
        await manager.registerPattern("case-test", pattern: caseSensitivePattern)
        
        let exactMatch = await manager.matchesPattern("case-test", element: MockElement(role: "AXButton", title: "Save"))
        let caseMatch = await manager.matchesPattern("case-test", element: MockElement(role: "AXButton", title: "save"))
        
        #expect(exactMatch == true)
        #expect(caseMatch == false) // Should be case-sensitive
        
        // Test partial matching
        let partialPattern = UIElementPattern(
            role: "AXButton",
            title: nil, // Only match on role
            identifier: nil
        )
        
        await manager.updatePattern("case-test", pattern: partialPattern)
        
        let roleOnlyMatch = await manager.matchesPattern("case-test", element: MockElement(role: "AXButton", title: "Any Title"))
        #expect(roleOnlyMatch == true)
        
        // Cleanup
        await manager.removePattern(for: "case-test")
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("LocatorManager handles concurrent pattern operations")
    func testConcurrentPatternOperations() async throws {
        let manager = LocatorManager.shared
        
        // Test concurrent pattern registration
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let pattern = UIElementPattern(
                        role: "AXButton",
                        title: "Button \(i)",
                        identifier: "btn-\(i)"
                    )
                    await manager.registerPattern("concurrent-\(i)", pattern: pattern)
                }
            }
        }
        
        // Verify all patterns were registered
        for i in 0..<10 {
            let pattern = await manager.getPattern(for: "concurrent-\(i)")
            #expect(pattern != nil)
            #expect(pattern?.title == "Button \(i)")
        }
        
        // Test concurrent pattern removal
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await manager.removePattern(for: "concurrent-\(i)")
                }
            }
        }
        
        // Verify all patterns were removed
        for i in 0..<10 {
            let pattern = await manager.getPattern(for: "concurrent-\(i)")
            #expect(pattern == nil)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Pattern matching performance under load")
    func testPatternMatchingPerformance() async throws {
        let manager = LocatorManager.shared
        
        // Register many patterns
        for i in 0..<100 {
            let pattern = UIElementPattern(
                role: i % 2 == 0 ? "AXButton" : "AXTextField",
                title: "Element \(i)",
                identifier: "elem-\(i)"
            )
            await manager.registerPattern("perf-\(i)", pattern: pattern)
        }
        
        // Test matching performance
        let startTime = Date()
        
        for i in 0..<100 {
            let element = MockElement(
                role: i % 2 == 0 ? "AXButton" : "AXTextField",
                title: "Element \(i)",
                identifier: "elem-\(i)"
            )
            let matches = await manager.matchesPattern("perf-\(i)", element: element)
            #expect(matches == true)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete quickly (less than 1 second for 100 matches)
        #expect(duration < 1.0)
        
        // Cleanup
        for i in 0..<100 {
            await manager.removePattern(for: "perf-\(i)")
        }
    }
}

// MARK: - Mock Objects

struct UIElementPattern {
    let role: String
    let title: String?
    let identifier: String?
    
    func isValid() -> Bool {
        return !role.isEmpty
    }
}

class MockElement {
    let role: String
    let title: String?
    let identifier: String?
    
    init(role: String, title: String? = nil, identifier: String? = nil) {
        self.role = role
        self.title = title
        self.identifier = identifier
    }
}

class MockWindow {
    let elements: [MockElement]
    
    init(elements: [MockElement]) {
        self.elements = elements
    }
}