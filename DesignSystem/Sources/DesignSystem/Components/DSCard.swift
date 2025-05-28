import SwiftUI

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
            .padding(Spacing.medium)
            .background(backgroundColor)
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

    private var backgroundColor: Color {
        switch style {
        case .elevated, .outlined:
            ColorPalette.background
        case .filled:
            ColorPalette.backgroundSecondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlined:
            ColorPalette.border
        case .elevated, .filled:
            Color.clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .outlined:
            Layout.BorderWidth.regular
        case .elevated, .filled:
            0
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
