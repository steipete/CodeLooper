import SwiftUI

public struct DSBadge: View {
    public enum Style {
        case `default`
        case primary
        case success
        case warning
        case error
        case info
    }
    
    private let text: String
    private let style: Style
    
    public init(_ text: String, style: Style = .default) {
        self.text = text
        self.style = style
    }
    
    public init(text: String, style: Style = .default) {
        self.text = text
        self.style = style
    }
    
    public var body: some View {
        Text(text)
            .font(Typography.caption1(.medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, Spacing.xxxSmall)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.round))
    }
    
    private var backgroundColor: Color {
        switch style {
        case .default:
            return ColorPalette.backgroundTertiary
        case .primary:
            return ColorPalette.primary.opacity(0.15)
        case .success:
            return ColorPalette.success.opacity(0.15)
        case .warning:
            return ColorPalette.warning.opacity(0.15)
        case .error:
            return ColorPalette.error.opacity(0.15)
        case .info:
            return ColorPalette.info.opacity(0.15)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .default:
            return ColorPalette.textSecondary
        case .primary:
            return ColorPalette.primary
        case .success:
            return ColorPalette.success
        case .warning:
            return ColorPalette.warning.opacity(0.9)
        case .error:
            return ColorPalette.error
        case .info:
            return ColorPalette.info
        }
    }
}