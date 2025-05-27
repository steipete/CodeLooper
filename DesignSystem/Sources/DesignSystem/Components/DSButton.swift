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
    
    private let title: String
    private let icon: Image?
    private let style: Style
    private let size: Size
    private let isFullWidth: Bool
    private let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
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
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: iconSpacing) {
                if let icon = icon {
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
    
    // MARK: - Computed Properties
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return Spacing.small
        case .medium: return Spacing.medium
        case .large: return Spacing.large
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return Spacing.xxSmall
        case .medium: return Spacing.xSmall
        case .large: return Spacing.small
        }
    }
    
    private var font: Font {
        switch size {
        case .small: return Typography.caption1(.medium)
        case .medium: return Typography.callout(.medium)
        case .large: return Typography.body(.medium)
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return Layout.Dimensions.iconSmall
        case .medium: return 20
        case .large: return Layout.Dimensions.iconMedium
        }
    }
    
    private var iconSpacing: CGFloat {
        switch size {
        case .small: return Spacing.xxSmall
        case .medium: return Spacing.xSmall
        case .large: return Spacing.small
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .primary, .secondary, .destructive:
            return Layout.CornerRadius.medium
        case .tertiary, .ghost:
            return Layout.CornerRadius.small
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? ColorPalette.primaryDark : ColorPalette.primary
        case .secondary:
            return isHovered ? ColorPalette.backgroundTertiary : ColorPalette.backgroundSecondary
        case .tertiary:
            return isHovered ? ColorPalette.hover : Color.clear
        case .destructive:
            return isHovered ? ColorPalette.error.opacity(0.9) : ColorPalette.error
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return ColorPalette.text
        case .tertiary, .ghost:
            return ColorPalette.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .destructive:
            return Color.clear
        case .secondary:
            return ColorPalette.border
        case .tertiary:
            return isHovered ? ColorPalette.primary.opacity(0.3) : Color.clear
        case .ghost:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .secondary, .tertiary:
            return Layout.BorderWidth.regular
        default:
            return 0
        }
    }
}