import Defaults
import SwiftUI

// Assuming MainSettingsViewModel and MCPConfigManager are accessible
// (e.g., part of the main app target or a shared module)

struct CursorRuleSetsSettingsTab: View {
    // Changed from @Bindable to @ObservedObject as MainSettingsViewModel is a class
    @ObservedObject var viewModel: MainSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Manage Cursor Project Rule Sets")
                    .font(.title2)
                Text("Install, update, or verify rule sets for your Cursor projects. These rules can help Cursor understand specific project contexts better.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)

                // Terminator Terminal Controller Rule Set section removed

                Spacer()
            }
            .padding()
        }
    }

    // statusColor, buttonText, and canInstallWithoutProject methods removed as they were specific to Terminator Rule Set.
}

#if DEBUG
struct CursorRuleSetsSettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        // Create dummy UpdaterViewModel for the preview
        let dummySparkleUpdaterManager = SparkleUpdaterManager()
        let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)
        
        let mockViewModel = MainSettingsViewModel(
            loginItemManager: LoginItemManager.shared,
            updaterViewModel: dummyUpdaterViewModel // Added dummyUpdaterViewModel
        )
        // Example: Set up a specific state for previewing
        // mockViewModel.selectedProjectURL = URL(fileURLWithPath: "/Users/steipete/DummyProject")
        // mockViewModel.projectDisplayName = "DummyProject"
        // mockViewModel.currentRuleSetStatus = .updateAvailable(installedVersion: "1.0.0", newVersion: "1.1.0")
        
        return CursorRuleSetsSettingsTab(viewModel: mockViewModel)
    }
}
#endif 
