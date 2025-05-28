import SwiftUI

public extension View {
    func textStyle(_ style: TextStyle) -> some View {
        self
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}

public struct TextStyle: Sendable {
    // MARK: Lifecycle

    public init(
        font: Font,
        color: Color? = nil,
        lineSpacing: CGFloat = 0,
        tracking: CGFloat = 0
    ) {
        self.font = font
        self.color = color ?? ColorPalette.text
        self.lineSpacing = lineSpacing
        self.tracking = tracking
    }

    // MARK: Public

    public let font: Font
    public let color: Color
    public let lineSpacing: CGFloat
    public let tracking: CGFloat
}

public enum TextStyles {
    // MARK: - Display Styles

    public static let displayLarge = TextStyle(
        font: Typography.largeTitle(),
        lineSpacing: 4,
        tracking: -0.5
    )

    public static let displayMedium = TextStyle(
        font: Typography.title1(),
        lineSpacing: 2,
        tracking: -0.3
    )

    public static let displaySmall = TextStyle(
        font: Typography.title2(),
        lineSpacing: 1,
        tracking: -0.2
    )

    // MARK: - Heading Styles

    public static let headingLarge = TextStyle(
        font: Typography.title3()
    )

    public static let headingMedium = TextStyle(
        font: Typography.headline()
    )

    public static let headingSmall = TextStyle(
        font: Typography.subheadline(.semibold)
    )

    // MARK: - Body Styles

    public static let bodyLarge = TextStyle(
        font: Typography.body(),
        lineSpacing: 4
    )

    public static let bodyMedium = TextStyle(
        font: Typography.callout(),
        lineSpacing: 3
    )

    public static let bodySmall = TextStyle(
        font: Typography.footnote(),
        lineSpacing: 2
    )

    // MARK: - Caption Styles

    public static let captionLarge = TextStyle(
        font: Typography.caption1(),
        color: ColorPalette.textSecondary
    )

    public static let captionMedium = TextStyle(
        font: Typography.caption2(),
        color: ColorPalette.textSecondary
    )

    // MARK: - Code Styles

    public static let codeLarge = TextStyle(
        font: Typography.monospaced(.large)
    )

    public static let codeMedium = TextStyle(
        font: Typography.monospaced(.medium)
    )

    public static let codeSmall = TextStyle(
        font: Typography.monospaced(.small)
    )
}
