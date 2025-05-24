import Defaults
import Diagnostics
import SwiftUI

// Ensure these are globally accessible or defined if not already
// extension Notification.Name {
//    static let menuBarVisibilityChanged = Notification.Name(\"menuBarVisibilityChanged\")
// }
// extension KeyboardShortcuts.Name {
//    static let toggleMonitoring = Self(\"toggleMonitoring\")
// }

struct SettingsPanesContainerView: View {
    @EnvironmentObject var mainSettingsViewModel: MainSettingsViewModel
    @EnvironmentObject var sessionLogger: SessionLogger // Assuming SessionLogger is provided higher up

    var body: some View {
        TabView {
            GeneralSettingsView(updaterViewModel: mainSettingsViewModel.updaterViewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)
            
            CursorSupervisionSettingsView()
                .tabItem {
                    Label("Supervision", systemImage: "eye.fill")
                }
                .tag(SettingsTab.supervision)
            
            CursorRuleSetsSettingsTab(viewModel: mainSettingsViewModel)
                .tabItem {
                    Label("Rule Sets", systemImage: "list.star")
                }
                .tag(SettingsTab.ruleSets)
            
            ExternalMCPsSettingsTab()
                .tabItem {
                    Label("External MCPs", systemImage: "server.rack")
                }
                .tag(SettingsTab.externalMCPs)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.advanced)
            
            // LogSettingsView() // TODO: LogSettingsView is in Diagnostics module, need to expose it
                 // .environmentObject(sessionLogger) // Pass if LogSettingsView expects it as an EnvironmentObject and not from SessionLogger.shared
            Text("Log View - Coming Soon")
                .tabItem {
                    Label("Log", systemImage: "doc.text.fill")
                }
                .tag(SettingsTab.log)
        }
        .environmentObject(mainSettingsViewModel) // Provide to tabs that need it
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Common Footer (Spec 3.3)
        Divider()
        HStack(spacing: 20) {
            Link("CodeLooper.app", destination: URL(string: "https://codelooper.app/")!)
            Link("Follow @CodeLoopApp on X", destination: URL(string: "https://x.com/CodeLoopApp")!)
            Link("View on GitHub", destination: URL(string: Constants.githubRepositoryURL)!)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .font(.caption)
    }
}

#if DEBUG
struct SettingsPanesContainerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create dummy UpdaterViewModel for the preview
        let dummySparkleUpdaterManager = SparkleUpdaterManager()
        let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

        SettingsPanesContainerView()
            .environmentObject(MainSettingsViewModel(loginItemManager: LoginItemManager.shared, updaterViewModel: dummyUpdaterViewModel))
            .environmentObject(SessionLogger.shared) // Provide a SessionLogger for the preview
    }
}
#endif 
