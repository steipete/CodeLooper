import SwiftUI

/// A circular icon button component with hover effects and optional destructive styling.
///
/// DSIconButton provides a consistent way to display icon-only buttons throughout
/// the application, with smooth animations and proper accessibility support.
///
/// Based on VibeMeter's IconButtonStyle pattern for consistent user experience.
///
/// ## Usage
///
/// ```swift
/// DSIconButton(
///     icon: "power",
///     isDestructive: true,
///     action: { NSApp.terminate(nil) }
/// )
/// .help("Quit CodeLooper (⌘Q)")
/// ```
public struct DSIconButton: View {
    // MARK: Lifecycle
    
    public init(
        icon: String,
        isDestructive: Bool = false,
        size: CGFloat = 16,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.isDestructive = isDestructive
        self.size = size
        self.action = action
    }
    
    // MARK: Public
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.75, weight: .medium))
                .foregroundStyle(foregroundColor)
        }
        .buttonStyle(IconButtonStyle(isDestructive: isDestructive))
    }
    
    // MARK: Private
    
    private let icon: String
    private let isDestructive: Bool
    private let size: CGFloat
    private let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var foregroundColor: Color {
        if isDestructive {
            return ColorPalette.error
        } else {
            return ColorPalette.textSecondary
        }
    }
}

/// Button style that provides circular hover effects for icon buttons.
///
/// This style creates a circular background on hover with smooth animations,
/// making it perfect for toolbar and action buttons.
public struct IconButtonStyle: ButtonStyle {
    // MARK: Lifecycle
    
    public init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }
    
    // MARK: Public
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill(backgroundColor(for: configuration))
            )
            .foregroundStyle(foregroundColor(for: configuration))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    // MARK: Private
    
    private let isDestructive: Bool
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private func backgroundColor(for configuration: Configuration) -> Color {
        if isHovering || configuration.isPressed {
            return hoverBackgroundColor
        } else {
            return Color.clear
        }
    }
    
    private func foregroundColor(for configuration: Configuration) -> Color {
        if isDestructive {
            return isHovering ? ColorPalette.error : ColorPalette.error.opacity(0.8)
        } else {
            return isHovering ? ColorPalette.text : ColorPalette.textSecondary
        }
    }
    
    private var hoverBackgroundColor: Color {
        colorScheme == .dark ? 
            Color.white.opacity(0.1) : 
            Color.black.opacity(0.05)
    }
}

#Preview("DSIconButton Examples") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            DSIconButton(icon: "gearshape") {
                print("Settings tapped")
            }
            .help("Settings")
            
            DSIconButton(icon: "eye.fill") {
                print("Toggle monitoring")
            }
            .help("Toggle Monitoring")
            
            DSIconButton(
                icon: "power",
                isDestructive: true
            ) {
                print("Quit tapped")
            }
            .help("Quit Application")
        }
        
        Text("Hover over the buttons to see the hover effect")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .withDesignSystem()
}