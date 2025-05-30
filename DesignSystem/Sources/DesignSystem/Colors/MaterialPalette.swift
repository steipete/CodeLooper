import SwiftUI

/// Centralized material palette for consistent visual effects across the design system.
///
/// MaterialPalette provides semantic material usage following Apple's design guidelines
/// for proper macOS integration with Desktop Tinting and transparency effects.
///
/// ## Material Hierarchy
///
/// - **Primary surfaces**: Main content areas and cards
/// - **Secondary surfaces**: Sidebars, toolbars, and auxiliary content
/// - **Interactive states**: Hover, selection, and pressed states
/// - **Overlay surfaces**: Popovers, menus, and temporary content
///
/// All materials automatically adapt to system appearance and provide
/// proper translucency effects that blend with the desktop background.
public enum MaterialPalette {
    // MARK: - Window Backgrounds

    /// Main window background material (matches macOS Settings)
    /// Used in: Primary window backgrounds, main content areas
    public static let windowBackground = Material.regularMaterial

    // MARK: - Primary Surfaces

    /// Ultra-thin material for primary content cards and sections
    /// Used in: DSCard.filled, main content backgrounds
    public static let cardBackground = Material.ultraThinMaterial

    /// Regular material for more prominent surfaces
    /// Used in: Secondary panels, emphasized containers
    public static let panelBackground = Material.regularMaterial

    /// Thick material for high-prominence surfaces
    /// Used in: Modal backgrounds, overlay containers
    public static let modalBackground = Material.thickMaterial

    // MARK: - Navigation & Chrome

    /// Thin material for sidebar areas (using available materials)
    /// Used in: Settings sidebars, navigation panels
    public static let sidebarBackground = Material.thinMaterial

    /// Bar material for app chrome
    /// Used in: Toolbars, status bars, window chrome
    public static let toolbarBackground = Material.bar

    // MARK: - Interactive States

    /// Ultra-thin material for subtle interactive states
    /// Used in: Button hover, list item selection
    public static let selectionBackground = Material.ultraThinMaterial

    // MARK: - Overlay Surfaces

    /// Thick material for overlay content
    /// Used in: Popovers, tooltips, dropdown menus
    public static let popoverBackground = Material.thickMaterial

    /// Regular material for menu content
    /// Used in: Context menus, dropdown content
    public static let menuBackground = Material.regularMaterial
}

// MARK: - Convenience Extensions

public extension View {
    /// Applies card background material with proper styling
    func cardBackground() -> some View {
        self.background(MaterialPalette.cardBackground)
    }

    /// Applies panel background material with proper styling
    func panelBackground() -> some View {
        self.background(MaterialPalette.panelBackground)
    }

    /// Applies selection background for interactive states
    func selectionBackground() -> some View {
        self.background(MaterialPalette.selectionBackground)
    }

    /// Applies sidebar background material
    func sidebarBackground() -> some View {
        self.background(MaterialPalette.sidebarBackground)
    }

    /// Applies popover background material
    func popoverBackground() -> some View {
        self.background(MaterialPalette.popoverBackground)
    }

    /// Applies window background material (matches macOS Settings)
    func windowBackground() -> some View {
        self.background(MaterialPalette.windowBackground)
    }
}
