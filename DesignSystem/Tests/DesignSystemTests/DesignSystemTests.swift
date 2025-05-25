import XCTest
@testable import DesignSystem

final class DesignSystemTests: XCTestCase {
    func testSpacingValues() {
        XCTAssertEqual(Spacing.xxxSmall, 2)
        XCTAssertEqual(Spacing.xxSmall, 4)
        XCTAssertEqual(Spacing.xSmall, 8)
        XCTAssertEqual(Spacing.small, 12)
        XCTAssertEqual(Spacing.medium, 16)
        XCTAssertEqual(Spacing.large, 20)
        XCTAssertEqual(Spacing.xLarge, 24)
        XCTAssertEqual(Spacing.xxLarge, 32)
        XCTAssertEqual(Spacing.xxxLarge, 40)
    }
    
    func testTypographySizes() {
        XCTAssertEqual(Typography.Size.xxxSmall.rawValue, 10)
        XCTAssertEqual(Typography.Size.xxSmall.rawValue, 11)
        XCTAssertEqual(Typography.Size.xSmall.rawValue, 12)
        XCTAssertEqual(Typography.Size.small.rawValue, 13)
        XCTAssertEqual(Typography.Size.medium.rawValue, 14)
        XCTAssertEqual(Typography.Size.large.rawValue, 16)
        XCTAssertEqual(Typography.Size.xLarge.rawValue, 18)
        XCTAssertEqual(Typography.Size.xxLarge.rawValue, 22)
        XCTAssertEqual(Typography.Size.xxxLarge.rawValue, 28)
        XCTAssertEqual(Typography.Size.display.rawValue, 36)
    }
    
    func testLayoutDimensions() {
        XCTAssertEqual(Layout.Dimensions.iconSmall, 16)
        XCTAssertEqual(Layout.Dimensions.iconMedium, 24)
        XCTAssertEqual(Layout.Dimensions.iconLarge, 32)
        XCTAssertEqual(Layout.Dimensions.iconXLarge, 48)
        
        XCTAssertEqual(Layout.Dimensions.buttonHeightSmall, 28)
        XCTAssertEqual(Layout.Dimensions.buttonHeightMedium, 36)
        XCTAssertEqual(Layout.Dimensions.buttonHeightLarge, 44)
        
        XCTAssertEqual(Layout.Dimensions.minTouchTarget, 44)
    }
    
    func testCornerRadius() {
        XCTAssertEqual(Layout.CornerRadius.none, 0)
        XCTAssertEqual(Layout.CornerRadius.small, 4)
        XCTAssertEqual(Layout.CornerRadius.medium, 8)
        XCTAssertEqual(Layout.CornerRadius.large, 12)
        XCTAssertEqual(Layout.CornerRadius.xLarge, 16)
        XCTAssertEqual(Layout.CornerRadius.round, 9999)
    }
}