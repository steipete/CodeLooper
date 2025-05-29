import SwiftUI

/// Typography system providing consistent text styling and hierarchy.
///
/// Typography defines:
/// - Font size scale from xxx-small to xxx-large
/// - Font weight options for different emphasis levels
/// - Text style functions for common use cases
/// - Semantic text styles (title, headline, body, caption)
/// - Line height and spacing calculations
///
/// The typography system ensures readable text hierarchy and
/// consistent spacing throughout the application interface.
public enum Typography {
    // MARK: - Font Sizes

    public enum Size: CGFloat {
        case xxxSmall = 10
        case xxSmall = 11
        case xSmall = 12
        case small = 13
        case medium = 14
        case large = 16
        case xLarge = 18
        case xxLarge = 22
        case xxxLarge = 28
        case display = 36
    }

    // MARK: - Font Weights

    public enum Weight {
        case ultraLight
        case thin
        case light
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black

        // MARK: Internal

        var fontWeight: Font.Weight {
            switch self {
            case .ultraLight: .ultraLight
            case .thin: .thin
            case .light: .light
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .heavy: .heavy
            case .black: .black
            }
        }
    }

    // MARK: - Text Styles

    public static func largeTitle(_ weight: Weight = .bold) -> Font {
        .system(size: Size.xxxLarge.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func title1(_ weight: Weight = .semibold) -> Font {
        .system(size: Size.xxLarge.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func title2(_ weight: Weight = .semibold) -> Font {
        .system(size: Size.xLarge.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func title3(_ weight: Weight = .semibold) -> Font {
        .system(size: Size.large.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func headline(_ weight: Weight = .semibold) -> Font {
        .system(size: Size.medium.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func body(_ weight: Weight = .regular) -> Font {
        .system(size: Size.medium.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func callout(_ weight: Weight = .regular) -> Font {
        .system(size: Size.small.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func subheadline(_ weight: Weight = .regular) -> Font {
        .system(size: Size.small.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func footnote(_ weight: Weight = .regular) -> Font {
        .system(size: Size.xSmall.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func caption1(_ weight: Weight = .regular) -> Font {
        .system(size: Size.xxSmall.rawValue, weight: weight.fontWeight, design: .default)
    }

    public static func caption2(_ weight: Weight = .regular) -> Font {
        .system(size: Size.xxxSmall.rawValue, weight: weight.fontWeight, design: .default)
    }

    // MARK: - Monospaced Fonts

    public static func monospaced(_ size: Size = .medium, weight: Weight = .regular) -> Font {
        .system(size: size.rawValue, weight: weight.fontWeight, design: .monospaced)
    }

    // MARK: - Custom Fonts

    public static func custom(_ name: String, size: Size, weight: Weight = .regular) -> Font {
        .custom(name, size: size.rawValue).weight(weight.fontWeight)
    }
}
