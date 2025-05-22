import AppKit
import Defaults
import OSLog
import SwiftUI

/**
 * Main settings view for FriendshipAI using the native macOS Settings framework.
 * This view uses TabView to organize settings by category for a consistent macOS experience.
 */
struct SettingsView: View {
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "SettingsView")

    // Use @Bindable with @Observable model to enable proper binding support
    @Bindable var viewModel: MainSettingsViewModel

    // Make initializer public so it can be accessed from AppMain
    init(viewModel: MainSettingsViewModel) {
        self.viewModel = viewModel
    }

    // Tab identifiers for settings organization
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case advanced = "Advanced"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gear"
            case .advanced: "wrench.and.screwdriver"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        TabView {
            // General Settings Tab
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            // These tabs are not needed for CodeLooper
            // Account and Contacts functionality removed

            // Advanced Settings Tab
            AdvancedSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
                .tag(SettingsTab.advanced)

            // About Tab
            AboutSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        // Always use the app name as the title even when switching tabs
        .navigationTitle(Constants.appName)
        .onAppear {
            logger.info("Settings view appeared")

            // Refresh settings when view appears
            Task {
                await viewModel.refreshSettings()
            }
        }
    }
}

#Preview {
    SettingsView(
        viewModel: MainSettingsViewModel(
            loginItemManager: LoginItemManager.shared
        )
    )
}
