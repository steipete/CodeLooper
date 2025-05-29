import SwiftUI

@Observable
public final class ColorTheme {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var isDarkMode: Bool = false

    // MARK: - Dynamic Colors

    public var primary: Color {
        ColorPalette.loopTint
    }

    public var background: Color {
        Color(NSColor.windowBackgroundColor)
    }

    public var backgroundSecondary: Color {
        ColorPalette.backgroundTertiary
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

    @MainActor
    public func updateFromSystem() {
        isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

public struct ColorThemeKey: EnvironmentKey {
    public nonisolated(unsafe) static let defaultValue = ColorTheme()
}

public extension EnvironmentValues {
    var colorTheme: ColorTheme {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}
