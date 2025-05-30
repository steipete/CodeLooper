import Foundation

/// Spacing system providing consistent spacing values across the design system.
///
/// Spacing defines:
/// - Base spacing scale from xx-small to xxx-large
/// - Component-specific spacing (padding, gaps, margins)
/// - Layout spacing for containers and sections
/// - Responsive spacing adjustments
/// - Consistent vertical and horizontal rhythm
///
/// The spacing system creates visual harmony and improves
/// readability through consistent whitespace usage.
public enum Spacing {
    // MARK: Public

    // MARK: - Component Spacing

    public enum Component {
        public static let paddingSmall: CGFloat = xSmall
        public static let paddingMedium: CGFloat = medium
        public static let paddingLarge: CGFloat = large

        public static let gapSmall: CGFloat = xxSmall
        public static let gapMedium: CGFloat = xSmall
        public static let gapLarge: CGFloat = small
    }

    // MARK: - Layout Spacing

    public enum Layout {
        public static let marginSmall: CGFloat = medium
        public static let marginMedium: CGFloat = xLarge
        public static let marginLarge: CGFloat = xxLarge

        public static let sectionSpacing: CGFloat = xxxLarge
        public static let containerPadding: CGFloat = xLarge
    }

    // MARK: - Grid Spacing

    public enum Grid {
        public static let columns: Int = 12
        public static let gutter: CGFloat = medium
        public static let margin: CGFloat = xLarge
    }

    // MARK: - Spacing Scale

    public static let xxxSmall: CGFloat = baseUnit * 0.5 // 2
    public static let xxSmall: CGFloat = baseUnit * 1 // 4
    public static let xSmall: CGFloat = baseUnit * 2 // 8
    public static let small: CGFloat = baseUnit * 3 // 12
    public static let medium: CGFloat = baseUnit * 4 // 16
    public static let large: CGFloat = baseUnit * 5 // 20
    public static let xLarge: CGFloat = baseUnit * 6 // 24
    public static let xxLarge: CGFloat = baseUnit * 8 // 32
    public static let xxxLarge: CGFloat = baseUnit * 10 // 40
    public static let huge: CGFloat = baseUnit * 12 // 48
    public static let massive: CGFloat = baseUnit * 16 // 64

    // MARK: Private

    // MARK: - Base Unit

    private static let baseUnit: CGFloat = 4
}
