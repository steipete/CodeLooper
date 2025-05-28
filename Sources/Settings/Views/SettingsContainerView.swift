import Defaults
import DesignSystem
import SwiftUI

struct SettingsContainerView: View {
    // MARK: Internal

    @EnvironmentObject var viewModel: MainSettingsViewModel
    @Default(.showDebugTab) private var showDebugTab

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                // Title bar area with integrated header and tabs
                TitleBarView(selectedTab: $selectedTab, tabs: tabs)
                    .onChange(of: showDebugTab) { _, newValue in
                        // If debug tab is disabled and currently selected, switch to general tab
                        if !newValue, selectedTab == .debug {
                            selectedTab = .general
                        }
                    }

                // Content area with dynamic sizing
                ScrollView {
                    VStack(spacing: 0) {
                        tabContent
                            .padding(Spacing.xLarge)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, maxWidth: 880,
               minHeight: 400, maxHeight: 1200)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @State private var selectedTab: SettingsTab = .general

    // Tab definitions
    private var tabs: [(id: SettingsTab, title: String, icon: String)] {
        var baseTabs: [(id: SettingsTab, title: String, icon: String)] = [
            (.general, "General", "gearshape"),
            (.supervision, "Supervision", "eye"),
            (.ruleSets, "Rules", "checklist"),
            (.externalMCPs, "Extensions", "puzzlepiece.extension"),
            (.ai, "AI", "brain"),
            (.advanced, "Advanced", "wrench.and.screwdriver"),
        ]

        if showDebugTab {
            baseTabs.append((.debug, "Debug", "ladybug"))
        }

        baseTabs.append((.about, "About", "info.circle"))
        return baseTabs
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(updaterViewModel: viewModel.updaterViewModel)
        case .supervision:
            CursorSupervisionSettingsView()
        case .ruleSets:
            CursorRuleSetsSettingsView()
        case .externalMCPs:
            ExternalMCPsSettingsView()
        case .ai:
            AISettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .debug:
            DebugSettingsView()
        case .about:
            AboutSettingsView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Title Bar View

private struct TitleBarView: View {
    // MARK: Internal

    @Binding var selectedTab: SettingsTab

    let tabs: [(id: SettingsTab, title: String, icon: String)]

    var body: some View {
        HStack(spacing: 0) {
            // Left side with app icon and title
            HStack(spacing: Spacing.small) {
                // App icon and title
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadiusDS(Layout.CornerRadius.small)
                }

                Text("CodeLooper")
                    .font(Typography.body(.semibold))
                    .foregroundColor(ColorPalette.text)
            }

            Spacer()

            // Tabs in the center
            HStack(spacing: Spacing.small) {
                ForEach(tabs, id: \.id) { tab in
                    TitleBarTabButton(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: selectedTab == tab.id,
                        isHovered: hoveredTab == tab.id
                    ) {
                        selectedTab = tab.id
                    }
                    .onHover { hovering in
                        hoveredTab = hovering ? tab.id : nil
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xSmall)
        .background(ColorPalette.backgroundSecondary)
        .overlay(
            DSDivider()
                .frame(height: Layout.BorderWidth.regular),
            alignment: .bottom
        )
        .gesture(
            DragGesture()
                .onChanged { _ in
                    // Move the window when dragging the title bar
                    if let window = NSApp.keyWindow {
                        window.performDrag(with: NSApp.currentEvent!)
                    }
                }
        )
    }

    // MARK: Private

    @State private var hoveredTab: SettingsTab?
}

private struct TitleBarTabButton: View {
    // MARK: Internal

    let title: String
    let icon: String
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxxSmall) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(height: 20)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(backgroundColor)
            .cornerRadiusDS(Layout.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
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
            ColorPalette.backgroundSecondary.opacity(0.7)
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
        isSelected ? Layout.BorderWidth.thin : 0
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
