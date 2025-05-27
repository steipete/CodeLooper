import Defaults
import SwiftUI

struct XcodeBuildConfigView: View {
    // MARK: Lifecycle

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        // Initialize local state from viewModel. These should be pre-filled by the viewModel.
        // This assumes MainSettingsViewModel has properties that hold these current values.
        // If viewModel is not directly available here or doesn't have them, use Defaults directly onAppear.
        // For this example, assuming MainSettingsViewModel loads these values.
        let mcpStatus = MainSettingsViewModel.sharedForPreview.mcpConfigManager
            .getMCPStatus(mcpIdentifier: "XcodeBuildMCP")
        _incrementalBuilds = State(initialValue: mcpStatus.incrementalBuildsEnabled ?? false)
        _sentryDisabled = State(initialValue: mcpStatus.sentryDisabled ?? false)
        _versionOverride = State(initialValue: mcpStatus.version ?? "")
    }

    // MARK: Internal

    @Binding var isPresented: Bool

    // Access to MainSettingsViewModel to save and refresh
    @EnvironmentObject var viewModel: MainSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("XcodeBuild MCP Configuration")
                .font(.title2)
                .padding(.bottom)

            Form {
                Toggle("Enable Incremental Builds", isOn: $incrementalBuilds)
                    .help("If enabled, xcodebuild will attempt to perform incremental builds. (default: Off)")

                Toggle("Disable Sentry Integration", isOn: $sentryDisabled)
                    .help("If enabled, Sentry integration for xcodebuild will be disabled. (default: Off)")

                HStack {
                    Text("Xcode Version Override:")
                    TextField("e.g., 15.2 (Optional)", text: $versionOverride)
                        .textFieldStyle(.roundedBorder)
                }
                .help("Specify a particular Xcode version for xcodebuild to use. Leave blank for default.")
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Save") {
                    saveConfiguration()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 450, height: 300)
        .padding()
        .onAppear {
            // Re-fetch current settings when view appears to ensure freshness,
            // especially if viewModel might not be updated synchronously before sheet shows.
            let status = viewModel.mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP")
            incrementalBuilds = status.incrementalBuildsEnabled ?? false
            sentryDisabled = status.sentryDisabled ?? false
            versionOverride = status.version ?? ""
        }
    }

    // MARK: Private

    // Local state for the form, initialized from viewModel or Defaults
    @State private var incrementalBuilds: Bool
    @State private var sentryDisabled: Bool
    @State private var versionOverride: String

    private func saveConfiguration() {
        let params: [String: Any] = [
            "incrementalBuildsEnabled": incrementalBuilds,
            "sentryDisabled": sentryDisabled,
            "version": versionOverride.isEmpty ? NSNull() : versionOverride, // Send NSNull to clear if empty
        ]
        _ = viewModel.mcpConfigManager.updateMCPConfiguration(mcpIdentifier: "XcodeBuildMCP", params: params)
        viewModel.refreshAllMCPStatusMessages() // Refresh status in main settings view
    }
}

// Required for initializing State from a non-literal value IF viewModel is not directly usable in init().
// For preview purposes or if MainSettingsViewModel is harder to inject into init.
extension MainSettingsViewModel {
    static var sharedForPreview: MainSettingsViewModel {
        // This creates a temporary instance for preview and init state. Consider if a proper singleton access is
        // better.
        // Or pass the necessary values directly to init for XcodeBuildConfigView.
        let dummySparkleUpdaterManager = SparkleUpdaterManager()
        let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)
        return MainSettingsViewModel(
            loginItemManager: LoginItemManager.shared,
            updaterViewModel: dummyUpdaterViewModel
        )
    }
}

#if DEBUG
    struct XcodeBuildConfigView_Previews: PreviewProvider {
        static var previews: some View {
            // Create a mock viewModel for the preview
            let mockViewModel = MainSettingsViewModel.sharedForPreview
            // You might want to set some default values in the mockViewModel or MCPConfigManager for preview
            // e.g., mockViewModel.mcpConfigManager.updateMCPConfiguration(...)

            XcodeBuildConfigView(isPresented: .constant(true))
                .environmentObject(mockViewModel)
        }
    }
#endif
