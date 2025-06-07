import AppKit
import Defaults
import SwiftUI

/// Advanced settings tab view
struct AdvancedSettingsTab: View {
    // MARK: Internal

    // Use @Bindable to enable proper bindings with @Observable
    @Bindable var viewModel: MainSettingsViewModel

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

                    // HTTP Server Settings
                    GridRow {
                        Text("HTTP Server:")
                            .frame(width: 120, alignment: .trailing)
                            .gridCellAnchor(.topTrailing)
                            .gridColumnAlignment(.trailing)

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable HTTP Server", isOn: Binding(
                                get: { Defaults[.httpServerEnabled] },
                                set: { newValue in
                                    Defaults[.httpServerEnabled] = newValue
                                    if newValue {
                                        Task { await HTTPServerService.shared.startServer() }
                                    } else {
                                        Task { await HTTPServerService.shared.stopServer() }
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .help("Enable HTTP server for remote monitoring and control")

                            HStack {
                                Text("Port:")
                                    .frame(width: 40, alignment: .leading)
                                TextField("8080", value: Binding(
                                    get: { Defaults[.httpServerPort] },
                                    set: { newValue in
                                        Defaults[.httpServerPort] = newValue
                                        if Defaults[.httpServerEnabled] {
                                            Task {
                                                await HTTPServerService.shared.restartServer()
                                            }
                                        }
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            }

                            HStack {
                                Text("ngrok API Key:")
                                    .frame(width: 100, alignment: .leading)
                                SecureField("API Key", text: Binding(
                                    get: { Defaults[.ngrokAPIKey] },
                                    set: { newValue in Defaults[.ngrokAPIKey] = newValue }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                            }

                            HStack {
                                Text("Screenshot Refresh:")
                                    .frame(width: 120, alignment: .leading)
                                TextField("1000", value: Binding(
                                    get: { Defaults[.httpServerScreenshotRefreshRate] },
                                    set: { newValue in Defaults[.httpServerScreenshotRefreshRate] = newValue }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                Text("ms")
                                    .foregroundColor(.secondary)
                            }

                            if Defaults[.httpServerEnabled] {
                                Text("Access your instances at: http://localhost:\(Defaults[.httpServerPort])")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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

    // MARK: Private

    @State private var showResetConfirmation = false
}

#if hasFeature(PreviewsMacros)
    #Preview {
        // Create dummy UpdaterViewModel for the preview
        let dummySparkleUpdaterManager = SparkleUpdaterManager()
        let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

        AdvancedSettingsTab(viewModel: MainSettingsViewModel(
            loginItemManager: LoginItemManager.shared,
            updaterViewModel: dummyUpdaterViewModel // Added dummyUpdaterViewModel
        ))
    }
#endif
