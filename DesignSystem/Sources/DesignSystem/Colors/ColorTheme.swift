import SwiftUI

@Observable
public final class ColorTheme {
    public var isDarkMode: Bool = false
    
    public init() {}
    
    @MainActor
    public func updateFromSystem() {
        isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    // MARK: - Dynamic Colors
    public var primary: Color {
        isDarkMode ? ColorPalette.primaryLight : ColorPalette.primary
    }
    
    public var background: Color {
        ColorPalette.background
    }
    
    public var backgroundSecondary: Color {
        ColorPalette.backgroundSecondary
    }
    
    public var text: Color {
        ColorPalette.text
    }
    
    public var textSecondary: Color {
        ColorPalette.textSecondary
    }
    
    public var border: Color {
        ColorPalette.border
    }
    
    public var success: Color {
        ColorPalette.success
    }
    
    public var warning: Color {
        ColorPalette.warning
    }
    
    public var error: Color {
        ColorPalette.error
    }
}

public struct ColorThemeKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue = ColorTheme()
}

public extension EnvironmentValues {
    var colorTheme: ColorTheme {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}