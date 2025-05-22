import SwiftUI
import Defaults

// Ensure these are globally accessible or defined if not already
// extension Notification.Name {
//    static let menuBarVisibilityChanged = Notification.Name(\"menuBarVisibilityChanged\")
// }
// extension KeyboardShortcuts.Name {
//    static let toggleMonitoring = Self(\"toggleMonitoring\")
// }

struct SettingsPanesContainerView: View {
    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(loginItemManager: LoginItemManager.shared)
    @EnvironmentObject var sessionLogger: SessionLogger // Assuming SessionLogger is provided higher up

    var body: some View {
        TabView {
            GeneralSettingsView()
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
            
            LogSettingsView()
                 // .environmentObject(sessionLogger) // Pass if LogSettingsView expects it as an EnvironmentObject and not from SessionLogger.shared
                .tabItem {
                    Label("Log", systemImage: "doc.text.fill")
                }
                .tag(SettingsTab.log)
        }
        .environmentObject(mainSettingsViewModel) // Provide to tabs that need it
        .frame(minWidth: 650, idealWidth: 750, minHeight: 450, idealHeight: 550) // Adjusted size slightly
        .padding()

        // Common Footer (Spec 3.3)
        Divider()
        HStack(spacing: 20) {
            Link("CodeLooper.app", destination: URL(string: "https://codelooper.app/")!)
            Link("Follow @CodeLoopApp on X", destination: URL(string: "https://x.com/CodeLoopApp")!)
            Link("View on GitHub", destination: URL(string: "https://github.com/steipete/CodeLooper")!)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .font(.caption)
    }
}

// Enum to define tags for programmatic navigation if needed later
enum SettingsTab: Hashable {
    case general, supervision, ruleSets, externalMCPs, advanced, log
}

#if DEBUG
struct SettingsPanesContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPanesContainerView()
            .environmentObject(SessionLogger.shared) // Provide mock/shared logger for preview
    }
}
#endif 