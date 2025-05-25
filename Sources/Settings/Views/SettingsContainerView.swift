import SwiftUI
import DesignSystem
import Defaults

struct SettingsContainerView: View {
    @EnvironmentObject var viewModel: MainSettingsViewModel
    @State private var selectedTab: SettingsTab = .general
    @State private var contentHeight: CGFloat = 600
    @State private var isAnimating = false
    
    // Tab definitions
    private let tabs: [(id: SettingsTab, title: String, icon: String)] = [
        (.general, "General", "gearshape"),
        (.supervision, "Supervision", "eye"),
        (.ruleSets, "Rules", "checklist"),
        (.externalMCPs, "Extensions", "puzzlepiece.extension"),
        (.advanced, "Advanced", "wrench.and.screwdriver"),
        (.about, "About", "info.circle")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app branding
            HeaderView()
            
            // Custom tab navigation
            TabNavigationView(selectedTab: $selectedTab, tabs: tabs)
            
            // Content area with animated height
            ScrollView {
                VStack(spacing: 0) {
                    tabContent
                        .padding(Spacing.xLarge)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: ContentHeightPreferenceKey.self,
                                value: geometry.size.height
                            )
                        })
                }
            }
            .frame(height: contentHeight)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: contentHeight)
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                if !isAnimating {
                    isAnimating = true
                    contentHeight = min(max(height + 40, 400), 800) // Min 400, max 800
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimating = false
                    }
                }
            }
            
            // Footer
            SettingsFooterView()
        }
        .frame(width: 700) // Fixed width for settings
        .background(ColorPalette.background)
        .withDesignSystem()
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(updaterViewModel: viewModel.updaterViewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .supervision:
            CursorSupervisionSettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .ruleSets:
            CursorRuleSetsSettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .externalMCPs:
            ExternalMCPsSettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .advanced:
            AdvancedSettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .about:
            AboutSettingsView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        default:
            EmptyView()
        }
    }
}

// MARK: - Header View
private struct HeaderView: View {
    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image("AppIcon")
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadiusDS(Layout.CornerRadius.large)
            
            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text("CodeLooper Settings")
                    .font(Typography.title2(.semibold))
                    .foregroundColor(ColorPalette.text)
                
                Text("Configure your Cursor supervision preferences")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.large)
        .background(ColorPalette.backgroundSecondary)
    }
}

// MARK: - Tab Navigation
private struct TabNavigationView: View {
    @Binding var selectedTab: SettingsTab
    let tabs: [(id: SettingsTab, title: String, icon: String)]
    @State private var hoveredTab: SettingsTab?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.medium) {
                ForEach(tabs, id: \.id) { tab in
                    TabButton(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: selectedTab == tab.id,
                        isHovered: hoveredTab == tab.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab.id
                        }
                    }
                    .onHover { hovering in
                        hoveredTab = hovering ? tab.id : nil
                    }
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
        }
        .background(ColorPalette.backgroundTertiary)
        .overlay(
            DSDivider()
                .frame(height: Layout.BorderWidth.regular),
            alignment: .bottom
        )
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
            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(height: 24)
                
                Text(title)
                    .font(Typography.caption1(.medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .background(backgroundColor)
            .cornerRadiusDS(Layout.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isSelected ? 1.0 : (isHovered ? 0.95 : 1.0))
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        if isSelected {
            return ColorPalette.primary
        } else if isHovered {
            return ColorPalette.text
        } else {
            return ColorPalette.textSecondary
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return ColorPalette.text
        } else if isHovered {
            return ColorPalette.text
        } else {
            return ColorPalette.textSecondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return ColorPalette.background
        } else if isHovered {
            return ColorPalette.backgroundSecondary
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return ColorPalette.primary.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? Layout.BorderWidth.medium : 0
    }
}

// MARK: - Footer
private struct SettingsFooterView: View {
    var body: some View {
        HStack {
            Button(action: openGitHub) {
                Label("GitHub", systemImage: "link")
                    .font(Typography.caption1())
            }
            .buttonStyle(.plain)
            .foregroundColor(ColorPalette.primary)
            
            Text("•")
                .foregroundColor(ColorPalette.textTertiary)
            
            Button(action: openDocumentation) {
                Label("Documentation", systemImage: "book")
                    .font(Typography.caption1())
            }
            .buttonStyle(.plain)
            .foregroundColor(ColorPalette.primary)
            
            Spacer()
            
            Text("Made with ❤️ for Cursor users")
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textSecondary)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .background(ColorPalette.backgroundSecondary)
    }
    
    private func openGitHub() {
        if let url = URL(string: "https://github.com/steipete/codelooper") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openDocumentation() {
        if let url = URL(string: "https://github.com/steipete/codelooper/wiki") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preference Key for Content Height
private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 600
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
#if DEBUG
struct SettingsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainerView()
    }
}
#endif