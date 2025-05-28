import SwiftUI

/// A versatile button component with consistent styling across the design system.
///
/// DSButton provides various styles and sizes to fit different use cases while
/// maintaining visual consistency throughout the application.
///
/// ## Topics
///
/// ### Button Styles
/// - ``Style``
/// - ``Size``
///
/// ### Creating Buttons
/// - ``init(title:icon:style:size:isFullWidth:action:)``
/// - ``init(title:style:size:isFullWidth:action:)``
///
/// ## Usage
///
/// ```swift
/// DSButton(
///     title: "Save Changes",
///     style: .primary,
///     size: .medium
/// ) {
///     // Handle button tap
/// }
/// ```
public struct DSButton: View {
    // MARK: Lifecycle

    public init(
        _ title: String,
        icon: Image? = nil,
        style: Style = .primary,
        size: Size = .medium,
        isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
        self.action = action
    }

    // MARK: Public

    /// The visual style of the button.
    public enum Style {
        /// Primary action button with high emphasis
        case primary
        /// Secondary action button with medium emphasis
        case secondary
        /// Tertiary action button with low emphasis
        case tertiary
        /// Destructive action button for dangerous operations
        case destructive
        /// Ghost button with minimal visual weight
        case ghost
    }

    /// The size of the button.
    public enum Size {
        /// Small button for compact layouts
        case small
        /// Medium button for standard use
        case medium
        /// Large button for prominent actions
        case large
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: iconSpacing) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                }
                Text(title)
                    .font(font)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: Private

    @State private var isHovered = false
    @State private var isPressed = false

    private let title: String
    private let icon: Image?
    private let style: Style
    private let size: Size
    private let isFullWidth: Bool
    private let action: () -> Void

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: Spacing.small
        case .medium: Spacing.medium
        case .large: Spacing.large
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: Spacing.xSmall // Match DSTextField padding
        case .medium: Spacing.xSmall
        case .large: Spacing.small
        }
    }

    private var font: Font {
        switch size {
        case .small: Typography.caption1(.medium)
        case .medium: Typography.callout(.medium)
        case .large: Typography.body(.medium)
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: Layout.Dimensions.iconSmall
        case .medium: 20
        case .large: Layout.Dimensions.iconMedium
        }
    }

    private var iconSpacing: CGFloat {
        switch size {
        case .small: Spacing.xxSmall
        case .medium: Spacing.xSmall
        case .large: Spacing.small
        }
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .primary, .secondary, .destructive:
            Layout.CornerRadius.medium
        case .tertiary, .ghost:
            Layout.CornerRadius.small
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            isHovered ? ColorPalette.primaryDark : ColorPalette.primary
        case .secondary:
            isHovered ? ColorPalette.backgroundTertiary : ColorPalette.backgroundSecondary
        case .tertiary:
            isHovered ? ColorPalette.hover : Color.clear
        case .destructive:
            isHovered ? ColorPalette.error.opacity(0.9) : ColorPalette.error
        case .ghost:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            .white
        case .secondary:
            ColorPalette.text
        case .tertiary, .ghost:
            ColorPalette.primary
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary, .destructive:
            Color.clear
        case .secondary:
            ColorPalette.border
        case .tertiary:
            isHovered ? ColorPalette.primary.opacity(0.3) : Color.clear
        case .ghost:
            Color.clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .secondary, .tertiary:
            Layout.BorderWidth.regular
        default:
            0
        }
    }
}
