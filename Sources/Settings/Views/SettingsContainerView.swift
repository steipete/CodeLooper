import Defaults
import DesignSystem
import SwiftUI

struct SettingsContainerView: View {
    // MARK: Internal

    @EnvironmentObject var viewModel: MainSettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with app branding
            HeaderView()

            // Custom tab navigation
            TabNavigationView(selectedTab: $selectedTab, tabs: tabs)

            // Content area
            ScrollView {
                VStack(spacing: 0) {
                    tabContent
                        .padding(Spacing.xLarge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, idealWidth: 800, maxWidth: .infinity, 
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @State private var selectedTab: SettingsTab = .general

    // Tab definitions
    private let tabs: [(id: SettingsTab, title: String, icon: String)] = [
        (.general, "General", "gearshape"),
        (.supervision, "Supervision", "eye"),
        (.ruleSets, "Rules", "checklist"),
        (.externalMCPs, "Extensions", "puzzlepiece.extension"),
        (.ai, "AI", "brain"),
        (.advanced, "Advanced", "wrench.and.screwdriver"),
        (.about, "About", "info.circle"),
    ]

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
        case .ai:
            AISettingsView()
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
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadiusDS(Layout.CornerRadius.large)
            }

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
    // MARK: Internal

    @Binding var selectedTab: SettingsTab

    let tabs: [(id: SettingsTab, title: String, icon: String)]

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
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
        }
        .background(ColorPalette.backgroundTertiary)
        .overlay(
            DSDivider()
                .frame(height: Layout.BorderWidth.regular),
            alignment: .bottom
        )
    }

    // MARK: Private

    @State private var hoveredTab: SettingsTab?
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

    // MARK: Private

    private var iconColor: Color {
        if isSelected {
            ColorPalette.primary
        } else if isHovered {
            ColorPalette.text
        } else {
            ColorPalette.textSecondary
        }
    }

    private var textColor: Color {
        if isSelected {
            ColorPalette.text
        } else if isHovered {
            ColorPalette.text
        } else {
            ColorPalette.textSecondary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            ColorPalette.background
        } else if isHovered {
            ColorPalette.backgroundSecondary
        } else {
            Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            ColorPalette.primary.opacity(0.3)
        } else {
            Color.clear
        }
    }

    private var borderWidth: CGFloat {
        isSelected ? Layout.BorderWidth.medium : 0
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
