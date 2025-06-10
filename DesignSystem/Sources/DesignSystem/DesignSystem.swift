import SwiftUI

/// The main entry point for the DesignSystem framework.
///
/// DesignSystem provides a comprehensive set of design tokens, components,
/// and utilities for building consistent user interfaces in CodeLooper.
///
/// ## Topics
///
/// ### Design Tokens
/// - ``colors``
/// - ``typography``
/// - ``textStyles``
/// - ``spacing``
/// - ``layout``
///
/// ### Components
/// - ``DSButton``
/// - ``DSIconButton``
/// - ``DSCard``
/// - ``DSTextField``
/// - ``DSToggle``
/// - ``DSSlider``
///
/// ### Extensions
/// - ``View/withDesignSystem()``
///
/// ## Usage
///
/// Apply the design system to your SwiftUI views:
///
/// ```swift
/// struct MyView: View {
///     var body: some View {
///         VStack {
///             Text("Hello")
///                 .font(DesignSystem.typography.body())
///                 .foregroundColor(DesignSystem.colors.primary)
///         }
///         .withDesignSystem()
///     }
/// }
/// ```
public struct DesignSystem {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    /// Access to the color palette and theming system.
    public static let colors = ColorPalette.self

    /// Access to typography utilities and font definitions.
    public static let typography = Typography.self

    /// Access to predefined text styles.
    public static let textStyles = TextStyles.self

    /// Access to spacing constants and utilities.
    public static let spacing = Spacing.self

    /// Access to layout utilities and constants.
    public static let layout = Layout.self
}

// MARK: - Environment Setup

/// A view modifier that sets up the DesignSystem environment.
///
/// This modifier configures the color theme and handles system appearance changes
/// automatically. Apply it to your root views to enable design system functionality.
public struct DesignSystemViewModifier: ViewModifier {
    // MARK: Public

    public func body(content: Content) -> some View {
        content
            .environment(\.colorTheme, colorTheme)
            .tint(ColorPalette.loopTint) // Apply CodeLooper brand tint
            .onReceive(NotificationCenter.default
                .publisher(for: NSApplication.didChangeOcclusionStateNotification))
            { _ in
                colorTheme.updateFromSystem()
            }
    }

    // MARK: Private

    @State private var colorTheme = ColorTheme()
}

public extension View {
    /// Applies the DesignSystem environment to this view.
    ///
    /// This method configures the view with the design system's color theme
    /// and automatically handles system appearance changes.
    ///
    /// - Returns: A view with the DesignSystem environment applied
    ///
    /// ## Example
    ///
    /// ```swift
    /// ContentView()
    ///     .withDesignSystem()
    /// ```
    func withDesignSystem() -> some View {
        modifier(DesignSystemViewModifier())
    }
}
