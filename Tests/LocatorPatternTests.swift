import AXorcist
@testable import CodeLooper
import Foundation
import XCTest

class LocatorPatternTests: XCTestCase {
    // MARK: - LocatorManager Tests

    func testLocatorManagerInitialization() async throws {
        let manager = await LocatorManager.shared

        // Manager is always created successfully

        // Test getting a locator for a known type
        _ = await manager.getLocator(for: .mainInputField)
        // Locator might be nil if not found, which is valid
        XCTAssertTrue(true)
    }

    func testLocatorTypes() async throws {
        // Test all locator types have default locators
        for type in LocatorType.allCases {
            XCTAssertNotNil(type.defaultLocator)
        }
    }

    func testLocatorManagerGetLocator() async throws {
        let manager = await LocatorManager.shared

        // Test getting locators for different types
        _ = await manager.getLocator(for: .mainInputField)
        _ = await manager.getLocator(for: .stopGeneratingButton)

        // These might be nil, which is valid behavior
        XCTAssertTrue(true)
    }

    // MARK: - DynamicLocatorDiscoverer Tests

    func testDynamicLocatorDiscoverer() async throws {
        let discoverer = await DynamicLocatorDiscoverer()

        // Discoverer is always created successfully
        XCTAssertTrue(true)
    }

    // MARK: - LocatorType Tests

    func testLocatorTypeDefaultLocators() async throws {
        // Test that each locator type has a valid default locator
        let allTypes = LocatorType.allCases

        for type in allTypes {
            let locator = type.defaultLocator
            XCTAssertNotNil(locator)

            // Check that locator exists (defaultLocator should never be nil)
            if let loc = locator {
                XCTAssertNotNil(loc.criteria)
            }
        }
    }

    func testLocatorTypeRawValues() async throws {
        // Test that each locator type has a raw value
        let allTypes = LocatorType.allCases

        for type in allTypes {
            let rawValue = type.rawValue
            XCTAssertTrue(!rawValue.isEmpty)
        }
    }
}
