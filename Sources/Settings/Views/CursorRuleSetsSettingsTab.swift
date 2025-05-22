import SwiftUI
import Defaults

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

                // Terminator Terminal Controller Rule Set (Spec 3.3.C)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Terminator Terminal Controller")
                        .font(.headline)
                    Text("Provides rules for interacting with the macOS Terminal via AppleScript, allowing Cursor to execute commands or manage terminal windows as part of its workflows.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Verify in Project...") {
                        Task {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the project root directory to verify the Terminator Rule Set."
                            
                            if await panel.runModal() == .OK {
                                if let url = panel.url {
                                    viewModel.verifyTerminatorRuleSetStatus(projectURL: url)
                                } else {
                                    viewModel.verifyTerminatorRuleSetStatus(projectURL: nil)
                                }
                            } else {
                                // User cancelled panel - do nothing, ViewModel's state remains as is
                            }
                        }
                    }

                    // Display Rule Set Status
                    if viewModel.selectedProjectURL != nil {
                        HStack {
                            Text("Status for \\(viewModel.projectDisplayName):")
                                .font(.callout) // Adjusted for consistency
                            Text(viewModel.currentRuleSetStatus.displayName)
                                .font(.callout.bold())
                                .foregroundColor(statusColor(for: viewModel.currentRuleSetStatus))
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    } else {
                        Text("Select a project directory to verify or install the rule set.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 5)
                    }
                    
                    // Action buttons based on status
                    HStack {
                        Button(action: {
                            Task {
                                // Ensure projectURL is available before calling install
                                if let projectURL = viewModel.selectedProjectURL {
                                   await viewModel.installTerminatorRuleSet(forProject: projectURL)
                                } else {
                                    // Optionally, prompt user to select a project first
                                    // Or disable the button if projectURL is nil
                                    print("Cannot install rule set: No project selected.")
                                }
                            }
                        }) {
                            Text(buttonText(for: viewModel.currentRuleSetStatus, projectSelected: viewModel.selectedProjectURL != nil, projectDisplayName: viewModel.projectDisplayName))
                        }
                        .disabled(viewModel.selectedProjectURL == nil && !canInstallWithoutProject(status: viewModel.currentRuleSetStatus)) // Disable if no project and action requires one

                        if case .updateAvailable(_, let newVersionString) = viewModel.currentRuleSetStatus, viewModel.selectedProjectURL != nil {
                            Button("Update to v\\(newVersionString)") {
                                if let url = viewModel.selectedProjectURL {
                                    Task {
                                        await viewModel.installTerminatorRuleSet(forProject: url)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Spacer()
            }
            .padding()
        }
    }

    private func statusColor(for status: MCPConfigManager.RuleSetStatus) -> Color {
        switch status {
        case .notInstalled, .bundleResourceMissing:
            return .orange
        case .corrupted:
            return .red
        case .installed:
            return .green
        case .updateAvailable:
            return .blue
        }
    }

    private func buttonText(for status: MCPConfigManager.RuleSetStatus, projectSelected: Bool, projectDisplayName: String) -> String {
        if !projectSelected {
            // For .notInstalled, if a general install location is possible without a project, this text might change.
            // For now, assume project selection is always primary for these actions.
            return "Select Project to Install/Verify"
        }
        switch status {
        case .notInstalled, .bundleResourceMissing:
            return "Install Rule Set to \\(projectDisplayName)"
        case .corrupted:
            return "Re-install Rule Set to \\(projectDisplayName) (Corrupted)"
        case .installed(let versionString):
            return "Re-install v\\(versionString) to \\(projectDisplayName)"
        case .updateAvailable(let installedVersionString, _):
            return "Update Rule Set in \\(projectDisplayName) (was v\\(installedVersionString))"
        }
    }
    
    // Helper to determine if install button should be enabled when no project is selected
    private func canInstallWithoutProject(status: MCPConfigManager.RuleSetStatus) -> Bool {
        // Currently, all our install/verify actions are project-specific.
        // If there was a global rule set installation, this logic might change.
        return false
    }
}

#if DEBUG
struct CursorRuleSetsSettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = MainSettingsViewModel(loginItemManager: LoginItemManager.shared)
        // Example: Set up a specific state for previewing
        // mockViewModel.selectedProjectURL = URL(fileURLWithPath: "/Users/steipete/DummyProject")
        // mockViewModel.projectDisplayName = "DummyProject"
        // mockViewModel.currentRuleSetStatus = .updateAvailable(installedVersion: "1.0.0", newVersion: "1.1.0")
        
        return CursorRuleSetsSettingsTab(viewModel: mockViewModel)
    }
}
#endif 