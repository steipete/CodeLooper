import AppKit
import Defaults
import SwiftUI

/// General settings tab view
struct GeneralSettingsTab: View {
    // Use @Bindable to enable proper bindings with @Observable
    @Bindable var viewModel: MainSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Using Grid layout for better alignment
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    // Menu Bar icon
                    GridRow {
                        Text("Menu Bar icon:")
                            .frame(width: 120, alignment: .trailing)
                            .gridColumnAlignment(.trailing)

                        Toggle("Show CodeLooper in Menu Bar", isOn: Binding(
                            get: { viewModel.showInMenuBar },
                            set: { viewModel.updateShowInMenuBar($0) }
                        ))
                        .toggleStyle(.checkbox)
                        .help("Show or hide the CodeLooper icon in the menu bar")
                        .gridColumnAlignment(.leading)
                    }
                    .padding(.vertical, 6)

                    GridRow {
                        Divider()
                            .gridCellColumns(2)
                    }

                    // Launch Settings
                    GridRow {
                        Text("Launch settings:")
                            .frame(width: 120, alignment: .trailing)
                            .gridCellAnchor(.topTrailing)
                            .gridColumnAlignment(.trailing)

                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Start at login", isOn: Binding(
                                get: { viewModel.startAtLogin },
                                set: { viewModel.updateStartAtLogin($0) }
                            ))
                            .toggleStyle(.checkbox)
                            .help("Automatically start CodeLooper when you log in to your Mac")

                            Toggle("Show welcome screen on next launch", isOn: Binding(
                                get: { viewModel.showWelcomeScreen },
                                set: { viewModel.updateShowWelcomeScreen($0) }
                            ))
                            .toggleStyle(.checkbox)
                            .help("Show the welcome screen next time the app launches")
                        }
                        .gridColumnAlignment(.leading)
                    }
                    .padding(.vertical, 6)

                    GridRow {
                        Divider()
                            .gridCellColumns(2)
                    }

                    // Application Info
                    GridRow {
                        Text("Application:")
                            .frame(width: 120, alignment: .trailing)
                            .gridColumnAlignment(.trailing)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("CodeLooper is your coding companion for macOS")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .gridColumnAlignment(.leading)
                    }
                    .padding(.vertical, 6)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    GeneralSettingsTab(viewModel: MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared
    ))
}