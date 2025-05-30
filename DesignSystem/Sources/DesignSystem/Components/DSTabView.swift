import SwiftUI

public struct DSTabView<Content: View>: View {
    // MARK: Lifecycle

    public init(
        selection: Binding<String>,
        tabs: [(id: String, title: String, icon: String)],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._selection = selection
        self.tabs = tabs
        self.content = content
    }

    // MARK: Public

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
            .background(MaterialPalette.cardBackground)

            DSDivider()

            // Content area
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .windowBackground() // Use proper material background
        }
    }

    // MARK: Private

    @Binding private var selection: String
    @State private var hoveredTab: String?

    private let tabs: [(id: String, title: String, icon: String)]
    private let content: () -> Content
}

private struct TabButton: View {
    // MARK: Internal

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
            .background(backgroundMaterial)
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

    // MARK: Private

    private var foregroundColor: Color {
        if isSelected {
            ColorPalette.loopTint
        } else if isHovered {
            ColorPalette.text
        } else {
            ColorPalette.textSecondary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            ColorPalette.loopTint.opacity(0.15)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
        if isHovered, !isSelected {
            Rectangle().fill(MaterialPalette.selectionBackground)
        } else {
            backgroundColor
        }
    }
}
