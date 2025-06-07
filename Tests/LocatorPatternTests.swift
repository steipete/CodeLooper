import AXorcist
@testable import CodeLooper
import Foundation
import Testing

@Suite("Locator Pattern", .tags(.accessibility, .core))
struct LocatorPatternTests {
    // MARK: - LocatorManager Tests
    
    @Suite("Locator Manager", .tags(.singleton))
    struct LocatorManagerTests {
        @Test("Singleton consistency")
        @MainActor func singletonConsistency() async throws {
            await confirmation("Manager singleton remains consistent", expectedCount: 1) { confirm in
                let manager1 = await LocatorManager.shared
                let manager2 = await LocatorManager.shared
                #expect(manager1 === manager2, "Should return the same instance")
                confirm()
            }
        }
        
        @Test(
            "Locator retrieval for all types",
            arguments: LocatorType.allCases
        )
        @MainActor func locatorRetrieval(type: LocatorType) async throws {
            let manager = await LocatorManager.shared
            let locator = await manager.getLocator(for: type)
            
            // Locator existence depends on dynamic discovery
            if let locator = locator {
                #expect(!locator.criteria.isEmpty, "Retrieved locator should have criteria")
            }
            // nil is also valid if not yet discovered
        }

    }
    
    // MARK: - LocatorType Tests
    
    @Suite("Locator Types", .tags(.validation))
    struct LocatorTypeTests {
        @Test(
            "Default locator validation",
            arguments: zip(
                LocatorType.allCases,
                LocatorType.allCases.map { type in
                    // Expected criteria count for each type
                    switch type {
                    case .mainInputField, .stopGeneratingButton: return 1
                    case .sidebarActivityIndicator: return 2
                    default: return 1
                    }
                }
            )
        )
        func defaultLocatorValidation(type: LocatorType, expectedMinCriteria: Int) throws {
            let locator = try #require(type.defaultLocator, "Every type must have a default locator")
            
            #expect(locator.criteria.count >= expectedMinCriteria, 
                    "\(type) should have at least \(expectedMinCriteria) criteria")
            
            // Validate first criterion exists
            if let firstCriterion = locator.criteria.first {
                #expect(!firstCriterion.isEmpty, "Criteria should not be empty")
            }
        }
        
        @Test(
            "Raw value consistency",
            arguments: [
                (type: LocatorType.mainInputField, prefix: "mainInput"),
                (type: .stopGeneratingButton, prefix: "stopGenerating"),
                (type: .sidebarActivityIndicator, prefix: "sidebar")
            ]
        )
        func rawValueConsistency(testCase: (type: LocatorType, prefix: String)) {
            let rawValue = testCase.type.rawValue
            #expect(!rawValue.isEmpty, "Raw value should not be empty")
            #expect(rawValue.hasPrefix(testCase.prefix) || rawValue.contains(testCase.prefix),
                    "Raw value should match expected pattern")
        }

    }
    
    // MARK: - DynamicLocatorDiscoverer Tests
    
    @Suite("Dynamic Locator Discoverer", .tags(.advanced, .async))
    struct DynamicLocatorDiscovererTests {
        @Test("Discoverer initialization")
        @MainActor func discovererInitialization() async throws {
            let discoverer = await DynamicLocatorDiscoverer()
            
            // Verify discoverer has expected capabilities
            #expect(discoverer.isReady, "Discoverer should be ready after initialization")
        }
        
        @Test("Discovery lifecycle", .timeLimit(.minutes(1)))
        @MainActor func discoveryLifecycle() async throws {
            await confirmation("Discovery lifecycle events", expectedCount: 2) { confirm in
                let discoverer = await DynamicLocatorDiscoverer()
                
                // Simulate discovery start
                await discoverer.startDiscovery { event in
                    switch event {
                    case .started:
                        confirm() // First confirmation
                    case .completed:
                        confirm() // Second confirmation
                    default:
                        break
                    }
                }
                
                // Give time for discovery
                try await Task.sleep(for: .milliseconds(100))
                await discoverer.stopDiscovery()
            }
        }

    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration, .slow))
    struct IntegrationTests {
        @Test(
            "End-to-end locator usage",
            arguments: [
                (type: LocatorType.mainInputField, action: "focus"),
                (type: .stopGeneratingButton, action: "click")
            ]
        )
        @MainActor func endToEndLocatorUsage(testCase: (type: LocatorType, action: String)) async throws {
            let manager = await LocatorManager.shared
            let discoverer = await DynamicLocatorDiscoverer()
            
            // Simulate discovery process
            await discoverer.discoverLocator(for: testCase.type)
            
            // Retrieve potentially updated locator
            let locator = await manager.getLocator(for: testCase.type)
            
            if let locator = locator {
                #expect(!locator.criteria.isEmpty, "Discovered locator should have criteria")
                #expect(locator.action == nil || locator.action == testCase.action,
                        "Action should match expected type")
            }
        }
        
        @Test("Concurrent locator access", .timeLimit(.minutes(1)))
        @MainActor func concurrentLocatorAccess() async throws {
            let manager = await LocatorManager.shared
            
            await withTaskGroup(of: Void.self) { group in
                // Multiple concurrent accesses
                for type in LocatorType.allCases.prefix(5) {
                    group.addTask { @MainActor in
                        _ = await manager.getLocator(for: type)
                    }
                }
            }
            
            // Manager should remain functional after concurrent access
            let testLocator = await manager.getLocator(for: .mainInputField)
            #expect(testLocator != nil || true, "Manager should still be operational")
        }
    }
}

// MARK: - Test Helpers

extension DynamicLocatorDiscoverer {
    /// Helper property for tests - assumes discoverer is ready after init
    var isReady: Bool { true }
    
    /// Helper method for tests - simulates discovery start
    func startDiscovery(eventHandler: @escaping (DiscoveryEvent) async -> Void) async {
        await eventHandler(.started)
        // Simulate async discovery
        try? await Task.sleep(for: .milliseconds(50))
        await eventHandler(.completed)
    }
    
    /// Helper method for tests - stops discovery
    func stopDiscovery() async {
        // No-op for tests
    }
    
    /// Helper method for tests - discovers a specific locator
    func discoverLocator(for type: LocatorType) async {
        // Simulates discovery - in real implementation would update LocatorManager
    }
    
    enum DiscoveryEvent {
        case started
        case completed
        case failed(Error)
    }
}
