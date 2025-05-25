import SwiftUI

public struct Typography {
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
        
        var fontWeight: Font.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
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