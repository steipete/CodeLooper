import SwiftUI

/// A card container component with consistent styling and elevation effects.
///
/// DSCard provides a structured container for grouping related content
/// with visual separation and depth. It supports different styles for
/// various use cases and contexts.
///
/// ## Usage
///
/// ```swift
/// DSCard {
///     VStack {
///         Text("Card Title")
///         Text("Card content goes here...")
///     }
/// }
/// ```
public struct DSCard<Content: View>: View {
    // MARK: Lifecycle

    public init(
        style: Style = .elevated,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.content = content
    }

    // MARK: Public

    public enum Style {
        case elevated
        case outlined
        case filled
    }

    public var body: some View {
        content()
            .padding(Spacing.small)
            .background(backgroundMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadowStyle(shadowStyle)
    }

    // MARK: Private

    private let style: Style
    private let content: () -> Content

    @ViewBuilder
    private var backgroundMaterial: some View {
        switch style {
        case .elevated, .outlined:
            Color.clear.background(MaterialPalette.windowBackground)
        case .filled:
            // Use clear background to avoid layering with window background
            Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlined:
            ColorPalette.border
        case .elevated:
            Color.clear
        case .filled:
            ColorPalette.cardBorder
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .outlined:
            Layout.BorderWidth.regular
        case .elevated:
            0
        case .filled:
            Layout.BorderWidth.thin
        }
    }

    private var shadowStyle: ShadowStyle {
        switch style {
        case .elevated:
            Layout.Shadow.medium
        case .outlined, .filled:
            Layout.Shadow.none
        }
    }
}
