import AppKit
import Defaults
import SwiftUI

/// Advanced settings tab view
struct AdvancedSettingsTab: View {
    // Use @Bindable to enable proper bindings with @Observable
    @Bindable var viewModel: MainSettingsViewModel
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Using Grid for better alignment
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    // Debug Options
                    GridRow {
                        Text("Debug options:")
                            .frame(width: 120, alignment: .trailing)
                            .gridCellAnchor(.topTrailing)
                            .gridColumnAlignment(.trailing)

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show debug menu", isOn: $viewModel.showDebugMenu)
                                .toggleStyle(.checkbox)
                                .onChange(of: viewModel.showDebugMenu) { oldValue, newValue in
                                    // Only call the toggle method if the value actually changed
                                    if oldValue != newValue {
                                        viewModel.toggleDebugMenu()
                                    }
                                }
                                .help("Show additional debug options in the menu bar menu")

                            Grid(alignment: .leading, verticalSpacing: 10) {
                                GridRow {
                                    Button("Show Welcome Screen") {
                                        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
                                    }
                                    .help("Show the welcome and onboarding screen")
                                }
                            }
                            .padding(.top, 5)
                        }
                        .gridColumnAlignment(.leading)
                    }
                    .padding(.vertical, 6)

                    GridRow {
                        Divider()
                            .gridCellColumns(2)
                    }

                    // Reset
                    GridRow {
                        Text("Reset settings:")
                            .frame(width: 120, alignment: .trailing)
                            .gridColumnAlignment(.trailing)

                        Button("Reset All Settings to Defaults") {
                            showResetConfirmation = true
                        }
                        .foregroundColor(.red)
                        .gridColumnAlignment(.leading)
                        .alert("Reset Settings", isPresented: $showResetConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Reset", role: .destructive) {
                                Task {
                                    await viewModel.resetToDefaults()
                                }
                            }
                        } message: {
                            Text("This will reset all settings to their default values. This cannot be undone.")
                        }
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
    // Create dummy UpdaterViewModel for the preview
    let dummySparkleUpdaterManager = SparkleUpdaterManager()
    let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

    AdvancedSettingsTab(viewModel: MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: dummyUpdaterViewModel // Added dummyUpdaterViewModel
    ))
}
