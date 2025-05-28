import SwiftUI

public struct DSTabView<Content: View>: View {
    @Binding private var selection: String
    private let tabs: [(id: String, title: String, icon: String)]
    private let content: () -> Content
    
    @State private var hoveredTab: String?
    
    public init(
        selection: Binding<String>,
        tabs: [(id: String, title: String, icon: String)],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._selection = selection
        self.tabs = tabs
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.id) { tab in
                    TabButton(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: selection == tab.id,
                        isHovered: hoveredTab == tab.id
                    ) {
                        selection = tab.id
                    }
                    .onHover { hovering in
                        hoveredTab = hovering ? tab.id : nil
                    }
                    
                    if tab.id != tabs.last?.id {
                        DSDivider(orientation: .vertical)
                            .frame(height: 20)
                            .opacity(0.3)
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(ColorPalette.backgroundSecondary)
            
            DSDivider()
            
            // Content area
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorPalette.background)
        }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(foregroundColor)
                
                Text(title)
                    .font(Typography.callout(.medium))
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .background(backgroundColor)
            .cornerRadiusDS(Layout.CornerRadius.medium)
            .scaleEffect(isSelected ? 1.0 : (isHovered ? 0.98 : 1.0))
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        }
        .buttonStyle(.plain)
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return ColorPalette.primary
        } else if isHovered {
            return ColorPalette.text
        } else {
            return ColorPalette.textSecondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return ColorPalette.primary.opacity(0.1)
        } else if isHovered {
            return ColorPalette.hover
        } else {
            return Color.clear
        }
    }
}