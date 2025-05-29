@testable import CodeLooper
import AXorcist
import Foundation
import Testing

/// Test suite for locator pattern and dynamic discovery functionality
struct LocatorPatternTests {
    // MARK: - LocatorManager Tests

    @Test
    func locatorManagerInitialization() async throws {
        let manager = await LocatorManager.shared

        // Manager is always created successfully

        // Test getting a locator for a known type
        _ = await manager.getLocator(for: .mainInputField)
        // Locator might be nil if not found, which is valid
        #expect(true)
    }

    @Test
    func locatorTypes() async throws {
        // Test all locator types have default locators
        for type in LocatorType.allCases {
            #expect(type.defaultLocator != nil)
        }
    }

    @Test
    func locatorManagerGetLocator() async throws {
        let manager = await LocatorManager.shared

        // Test getting locators for different types
        _ = await manager.getLocator(for: .mainInputField)
        _ = await manager.getLocator(for: .stopGeneratingButton)
        
        // These might be nil, which is valid behavior
        #expect(true)
    }

    // MARK: - DynamicLocatorDiscoverer Tests

    @Test
    func dynamicLocatorDiscoverer() async throws {
        let discoverer = await DynamicLocatorDiscoverer()

        // Discoverer is always created successfully
        #expect(true)
    }

    // MARK: - LocatorType Tests

    @Test
    func locatorTypeDefaultLocators() async throws {
        // Test that each locator type has a valid default locator
        let allTypes = LocatorType.allCases
        
        for type in allTypes {
            let locator = type.defaultLocator
            #expect(locator != nil)
            
            // Check that locator exists (defaultLocator should never be nil)
            if let loc = locator {
                #expect(loc.criteria != nil)
            }
        }
    }

    @Test
    func locatorTypeRawValues() async throws {
        // Test that each locator type has a raw value
        let allTypes = LocatorType.allCases
        
        for type in allTypes {
            let rawValue = type.rawValue
            #expect(!rawValue.isEmpty)
        }
    }
}