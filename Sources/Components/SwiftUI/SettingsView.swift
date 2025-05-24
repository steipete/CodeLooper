import SwiftUI
import AXorcist
import Diagnostics
// import AppState // Remove if AppState is no longer used directly

// Assuming AXpectorView is in a module that's imported or accessible.
// If AXpector is a separate module, you'll need an import AXpector

@MainActor
struct SettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: MainSettingsViewModel
    @State private var showingAXpectorView = false
    @State private var selectedTab: SettingsTab = .general

    // Initializer to receive dependencies for MainSettingsViewModel
    init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        _viewModel = StateObject(wrappedValue: MainSettingsViewModel(loginItemManager: loginItemManager, updaterViewModel: updaterViewModel))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(updaterViewModel: viewModel.updaterViewModel)
                .tabItem { Label("General", systemImage: SettingsTab.general.systemImageName) }
                .tag(SettingsTab.general)
            
            CursorSupervisionSettingsView()
                .tabItem { Label("Supervision", systemImage: SettingsTab.supervision.systemImageName) }
                .tag(SettingsTab.supervision)

            // Example for Rule Sets tab
            RuleSetsSettingsView()
                .tabItem { Label("Rule Sets", systemImage: SettingsTab.ruleSets.systemImageName) }
                .tag(SettingsTab.ruleSets)

            // Example for External MCPs tab
            ExternalMCPsSettingsView()
                .tabItem { Label("External MCPs", systemImage: SettingsTab.externalMCPs.systemImageName) }
                .tag(SettingsTab.externalMCPs)
            
            AdvancedSettingsView()
                 .tabItem { Label("Advanced", systemImage: SettingsTab.advanced.systemImageName) }
                 .tag(SettingsTab.advanced)

            // Example for Log tab
            // LogSettingsView() // TODO: LogSettingsView is in Diagnostics module, need to expose it
                // .tabItem { Label("Log", systemImage: SettingsTab.log.systemImageName) }
                // .tag(SettingsTab.log)
            Text("Log View - Coming Soon")
                .tabItem { Label("Log", systemImage: SettingsTab.log.systemImageName) }
                .tag(SettingsTab.log)
            
            VStack {
                Text("Developer & Debug Tools")
                    .font(.title2)
                    .padding(.top)
                Button("Open Accessibility Inspector") {
                    showingAXpectorView = true
                }
                .padding()
                Spacer()
            }
            .tabItem { Label("Developer", systemImage: SettingsTab.developer.systemImageName) }
            .tag(SettingsTab.developer)
            
        }
        .padding(20)
        .frame(width: 700, height: 450)
        // TODO: AXpectorView needs to be exposed from AXorcist package
        // .sheet(isPresented: $showingAXpectorView) {
        //     AXpectorView()
        //         .environmentObject(appEnvironment)
        // }
        .onAppear {
            Task {
                await viewModel.refreshSettings()
            }
        }
    }
}

// You might need to add a .developer case to your SettingsTab enum
// enum SettingsTab: String, CaseIterable, Identifiable {
//    case general = "General"
//    case supervision = "Supervision"
//    case advanced = "Advanced"
//    case developer = "Developer" // New Case
//    var id: String { self.rawValue }
// }

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // For preview, create dummy or shared instances for dependencies
        SettingsView(
            loginItemManager: LoginItemManager.shared, // Use shared instance for preview
            updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil) // Create a dummy/preview UpdaterViewModel
        )
        .environmentObject(AppEnvironment()) // Use AppEnvironment for preview
    }
}

// Placeholder for missing views to allow compilation - these should be actual views
struct RuleSetsSettingsView: View { var body: some View { Text("Rule Sets Settings") } }
struct ExternalMCPsSettingsView: View { var body: some View { Text("External MCPs Settings") } }
// LogSettingsView is already defined in Sources/Diagnostics/LogSettingsView.swift
