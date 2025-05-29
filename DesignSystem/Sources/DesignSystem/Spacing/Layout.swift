import SwiftUI

public enum Layout {
    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let none: CGFloat = 0
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 8
        public static let xLarge: CGFloat = 16
        public static let button: CGFloat = 6
        public static let round: CGFloat = 9999
    }

    // MARK: - Border Width

    public enum BorderWidth {
        public static let none: CGFloat = 0
        public static let thin: CGFloat = 0.5
        public static let regular: CGFloat = 1
        public static let medium: CGFloat = 2
        public static let thick: CGFloat = 3
    }

    // MARK: - Shadow

    public enum Shadow {
        public static let none = ShadowStyle(radius: 0, y: 0)
        public static let small = ShadowStyle(radius: 2, y: 1)
        public static let medium = ShadowStyle(radius: 4, y: 2)
        public static let large = ShadowStyle(radius: 8, y: 4)
        public static let xLarge = ShadowStyle(radius: 16, y: 8)
        public static let contentCard = ShadowStyle(color: ColorPalette.shadowLight.opacity(0.5), radius: 3, y: 1)
    }

    // MARK: - Animation

    public enum Animation {
        public static let fast: Double = 0.2
        public static let normal: Double = 0.3
        public static let slow: Double = 0.5
        public static let verySlow: Double = 0.8

        public static let springResponse: Double = 0.4
        public static let springDamping: Double = 0.8
    }

    // MARK: - Dimensions

    public enum Dimensions {
        public static let iconSmall: CGFloat = 16
        public static let iconMedium: CGFloat = 24
        public static let iconLarge: CGFloat = 32
        public static let iconXLarge: CGFloat = 48

        public static let buttonHeightSmall: CGFloat = 28
        public static let buttonHeightMedium: CGFloat = 36
        public static let buttonHeightLarge: CGFloat = 44

        public static let minTouchTarget: CGFloat = 44
    }
}

public struct ShadowStyle: Sendable {
    // MARK: Lifecycle

    public init(
        color: Color? = nil,
        radius: CGFloat,
        x: CGFloat = 0,
        y: CGFloat
    ) {
        self.color = color ?? ColorPalette.shadowLight
        self.radius = radius
        self.x = x
        self.y = y
    }

    // MARK: Public

    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

public extension View {
    func shadowStyle(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}
