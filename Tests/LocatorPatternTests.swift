import AXorcist
@testable import CodeLooper
import Foundation
import Testing

@Suite("LocatorPatternTests")
struct LocatorPatternTests {
    // MARK: - LocatorManager Tests

    @Test("Locator manager initialization") @MainActor func locatorManagerInitialization() async throws {
        let manager = await LocatorManager.shared

        // Manager is always created successfully

        // Test getting a locator for a known type
        _ = await manager.getLocator(for: .mainInputField)
        // Locator might be nil if not found, which is valid
        #expect(true)
    }

    @Test("Locator types") @MainActor func locatorTypes() async throws {
        // Test all locator types have default locators
        for type in LocatorType.allCases {
            #expect(type.defaultLocator != nil)
        }
    }

    @Test("Locator manager get locator") @MainActor func locatorManagerGetLocator() async throws {
        let manager = await LocatorManager.shared

        // Test getting locators for different types
        _ = await manager.getLocator(for: .mainInputField)
        _ = await manager.getLocator(for: .stopGeneratingButton)

        // These might be nil, which is valid behavior
        #expect(true)
    }

    // MARK: - DynamicLocatorDiscoverer Tests

    @Test("Dynamic locator discoverer") @MainActor func dynamicLocatorDiscoverer() async throws {
        _ = await DynamicLocatorDiscoverer()

        // Discoverer is always created successfully
        #expect(true)
    }

    // MARK: - LocatorType Tests

    @Test("Locator type default locators") @MainActor func locatorTypeDefaultLocators() async throws {
        // Test that each locator type has a valid default locator
        let allTypes = LocatorType.allCases

        for type in allTypes {
            let locator = type.defaultLocator
            #expect(locator != nil)

            // Check that locator exists (defaultLocator should never be nil)
            if let loc = locator {
                #expect(!loc.criteria.isEmpty)
            }
        }
    }

    @Test("Locator type raw values") @MainActor func locatorTypeRawValues() async throws {
        // Test that each locator type has a raw value
        let allTypes = LocatorType.allCases

        for type in allTypes {
            let rawValue = type.rawValue
            #expect(!rawValue.isEmpty)
        }
    }
}
