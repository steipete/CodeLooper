import Combine
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct SettingsContentView: View {
    // MARK: Internal

    let viewModel: MainSettingsViewModel
    let selectedTab: CurrentValueSubject<SettingsTab, Never>

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(spacing: 0) {
                    tabContent
                        .padding(Spacing.xLarge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .withDesignSystem()
        .environmentObject(viewModel)
        .environmentObject(SessionLogger.shared)
        .onChange(of: debugMode) { _, newValue in
            if !newValue, currentTab == .debug {
                currentTab = .general
                selectedTab.send(.general)
            }
        }
        .onAppear {
            currentTab = selectedTab.value
        }
        .onReceive(selectedTab) { newTab in
            currentTab = newTab
        }
    }

    // MARK: Private

    @State private var currentTab: SettingsTab = .general

    @Default(.debugMode) private var debugMode

    @ViewBuilder
    private var tabContent: some View {
        switch currentTab {
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
        }
    }
}
