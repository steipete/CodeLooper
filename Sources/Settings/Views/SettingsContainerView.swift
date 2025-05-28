import Defaults
import DesignSystem
import SwiftUI

struct SettingsContainerView: View {
    // MARK: Internal

    @EnvironmentObject var viewModel: MainSettingsViewModel
    @Default(.showDebugTab) private var showDebugTab

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with app branding
                HeaderView()

                // Custom tab navigation
                TabNavigationView(selectedTab: $selectedTab, tabs: tabs)
                    .onChange(of: showDebugTab) { oldValue, newValue in
                        // If debug tab is disabled and currently selected, switch to general tab
                        if !newValue && selectedTab == .debug {
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
            .onPreferenceChange(HeaderHeightKey.self) { height in
                headerHeight = height
            }
        }
        .frame(minWidth: 600, maxWidth: 880, 
               minHeight: 800, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @State private var selectedTab: SettingsTab = .general
    @State private var headerHeight: CGFloat = 0

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
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .supervision:
            CursorSupervisionSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .ruleSets:
            CursorRuleSetsSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .externalMCPs:
            ExternalMCPsSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .ai:
            AISettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .advanced:
            AdvancedSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .debug:
            AboutSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
        case .about:
            AboutSettingsView()
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
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
            // Add leading space to account for window buttons (close, minimize, maximize)
            // Standard macOS window buttons are about 68pt wide
            Spacer()
                .frame(width: 68)
            
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 32, height: 32) // Smaller icon for unified header
                    .cornerRadiusDS(Layout.CornerRadius.medium)
            }

            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text("CodeLooper Settings")
                    .font(Typography.title3(.semibold)) // Smaller font for unified header
                    .foregroundColor(ColorPalette.text)

                Text("Configure your Cursor supervision preferences")
                    .font(Typography.caption2()) // Smaller caption
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.small) // Reduced top padding to align with window buttons
        .padding(.bottom, Spacing.medium)
        .background(ColorPalette.backgroundSecondary)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: HeaderHeightKey.self,
                        value: geometry.size.height
                    )
            }
        )
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


private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
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
