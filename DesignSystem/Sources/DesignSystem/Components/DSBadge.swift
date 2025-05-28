import SwiftUI

public struct DSBadge: View {
    // MARK: Lifecycle

    public init(_ text: String, style: Style = .default) {
        self.text = text
        self.style = style
    }

    public init(text: String, style: Style = .default) {
        self.text = text
        self.style = style
    }

    // MARK: Public

    public enum Style {
        case `default`
        case primary
        case success
        case warning
        case error
        case info
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

    // MARK: Private

    private let text: String
    private let style: Style

    private var backgroundColor: Color {
        switch style {
        case .default:
            ColorPalette.backgroundTertiary
        case .primary:
            ColorPalette.primary.opacity(0.15)
        case .success:
            ColorPalette.success.opacity(0.15)
        case .warning:
            ColorPalette.warning.opacity(0.15)
        case .error:
            ColorPalette.error.opacity(0.15)
        case .info:
            ColorPalette.info.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .default:
            ColorPalette.textSecondary
        case .primary:
            ColorPalette.primary
        case .success:
            ColorPalette.success
        case .warning:
            ColorPalette.warning.opacity(0.9)
        case .error:
            ColorPalette.error
        case .info:
            ColorPalette.info
        }
    }
}
