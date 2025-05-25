import SwiftUI

public struct DSCard<Content: View>: View {
    public enum Style {
        case elevated
        case outlined
        case filled
    }
    
    private let style: Style
    private let content: () -> Content
    
    public init(
        style: Style = .elevated,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.content = content
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
    
    private var backgroundColor: Color {
        switch style {
        case .elevated, .outlined:
            return ColorPalette.background
        case .filled:
            return ColorPalette.backgroundSecondary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outlined:
            return ColorPalette.border
        case .elevated, .filled:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outlined:
            return Layout.BorderWidth.regular
        case .elevated, .filled:
            return 0
        }
    }
    
    private var shadowStyle: ShadowStyle {
        switch style {
        case .elevated:
            return Layout.Shadow.medium
        case .outlined, .filled:
            return Layout.Shadow.none
        }
    }
}