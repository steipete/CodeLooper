import SwiftUI

/// Centralized color palette providing consistent colors across the design system.
///
/// ColorPalette defines:
/// - Brand colors for primary interface elements
/// - Semantic colors for status, alerts, and feedback
/// - Background and surface colors for containers
/// - Text colors with proper contrast ratios
/// - Interactive states (hover, active, disabled)
///
/// All colors are optimized for both light and dark mode appearances
/// and maintain WCAG accessibility guidelines for contrast.
public enum ColorPalette {
    // MARK: - Brand Colors
    
    /// CodeLooper signature blue-purple loop color for global tinting
    public static let loopBlue = Color(red: 0.3, green: 0.5, blue: 0.9)      // Main loop color
    public static let loopPurple = Color(red: 0.5, green: 0.3, blue: 0.9)    // Secondary loop color
    public static let loopTint = Color(red: 0.4, green: 0.35, blue: 0.85)    // Darker, more purple tint

    // MARK: - Semantic Colors

    public static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    public static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)
    public static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
    public static let info = Color(red: 0.3, green: 0.7, blue: 1.0)

    // MARK: - Neutral Colors

    public static let text = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.6)
    
    /// Consistent color for section headers to ensure uniformity
    public static let sectionHeader = Color.secondary

    public static let backgroundTertiary = Color(NSColor.underPageBackgroundColor)

    public static let border = Color(NSColor.separatorColor)
    public static let borderLight = Color(NSColor.separatorColor).opacity(0.5)
    public static let cardBorder = Color(NSColor.separatorColor).opacity(0.4)

    // MARK: - Interactive States

    public static let accent = loopTint // Use CodeLooper brand tint
    public static let disabled = Color.gray.opacity(0.3)

    // MARK: - Shadows

    public static let shadowLight = Color.black.opacity(0.1)
    public static let shadowMedium = Color.black.opacity(0.2)
    public static let shadowDark = Color.black.opacity(0.3)
}
