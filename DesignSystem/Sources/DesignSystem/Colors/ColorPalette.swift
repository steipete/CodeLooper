import SwiftUI

public struct ColorPalette {
    // MARK: - Brand Colors
    public static let primary = Color(red: 0.0, green: 0.478, blue: 1.0)
    public static let primaryLight = Color(red: 0.2, green: 0.6, blue: 1.0)
    public static let primaryDark = Color(red: 0.0, green: 0.35, blue: 0.8)
    
    // MARK: - Semantic Colors
    public static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    public static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)
    public static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
    public static let info = Color(red: 0.3, green: 0.7, blue: 1.0)
    
    // MARK: - Neutral Colors
    public static let text = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.6)
    
    public static let background = Color(NSColor.windowBackgroundColor)
    public static let backgroundSecondary = Color(NSColor.controlBackgroundColor).opacity(0.6)
    public static let backgroundTertiary = Color(NSColor.underPageBackgroundColor)
    
    public static let border = Color(NSColor.separatorColor)
    public static let borderLight = Color(NSColor.separatorColor).opacity(0.5)
    
    // MARK: - Interactive States
    public static let accent = Color.accentColor
    public static let hover = Color.accentColor.opacity(0.1)
    public static let pressed = Color.accentColor.opacity(0.2)
    public static let disabled = Color.gray.opacity(0.3)
    
    // MARK: - Shadows
    public static let shadowLight = Color.black.opacity(0.1)
    public static let shadowMedium = Color.black.opacity(0.2)
    public static let shadowDark = Color.black.opacity(0.3)
}