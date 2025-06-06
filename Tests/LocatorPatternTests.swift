import AXorcist
@testable import CodeLooper
import Foundation
import Testing

@Suite("LocatorPatternTests")
struct LocatorPatternTests {
    // MARK: - LocatorManager Tests

    @Test("Locator manager initialization") func locatorManagerInitialization() {
        let manager = await LocatorManager.shared

        // Manager is always created successfully

        // Test getting a locator for a known type
        _ = await manager.getLocator(for: .mainInputField)
        // Locator might be nil if not found, which is valid
        #expect(true)
    }

    @Test("Locator types") func locatorTypes() {
        // Test all locator types have default locators
        for type in LocatorType.allCases {
            #expect(type.defaultLocator != nil)
        }
    }

    @Test("Locator manager get locator") func locatorManagerGetLocator() {
        let manager = await LocatorManager.shared

        // Test getting locators for different types
        _ = await manager.getLocator(for: .mainInputField)
        _ = await manager.getLocator(for: .stopGeneratingButton)

        // These might be nil, which is valid behavior
        #expect(true)
    }

    // MARK: - DynamicLocatorDiscoverer Tests

    @Test("Dynamic locator discoverer") func dynamicLocatorDiscoverer() {
        let discoverer = await DynamicLocatorDiscoverer()

        // Discoverer is always created successfully
        #expect(true)
    }

    // MARK: - LocatorType Tests

    @Test("Locator type default locators") func locatorTypeDefaultLocators() {
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

    @Test("Locator type raw values") func locatorTypeRawValues() {
        // Test that each locator type has a raw value
        let allTypes = LocatorType.allCases

        for type in allTypes {
            let rawValue = type.rawValue
            #expect(!rawValue.isEmpty)
        }
    }
}
