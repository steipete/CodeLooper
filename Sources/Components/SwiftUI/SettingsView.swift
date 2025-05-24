import SwiftUI
import AXorcist
import Diagnostics
// import AppState // Remove if AppState is no longer used directly

// Assuming AXpectorView is in a module that's imported or accessible.
// If AXpector is a separate module, you'll need an import AXpector

// PreferenceKey to communicate ideal height from child views
struct IdealHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue() // Use the latest reported height
    }
}

@MainActor
struct SettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: MainSettingsViewModel
    @State private var showingAXpectorView = false
    @State private var selectedTab: SettingsTab = .general
    @State private var idealContentHeight: CGFloat = 400 // Default/initial height

    // Initializer to receive dependencies for MainSettingsViewModel
    init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        _viewModel = StateObject(wrappedValue: MainSettingsViewModel(loginItemManager: loginItemManager, updaterViewModel: updaterViewModel))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(updaterViewModel: viewModel.updaterViewModel)
                .readHeight()
                .tabItem { Label("General", systemImage: SettingsTab.general.systemImageName) }
                .tag(SettingsTab.general)
            
            CursorSupervisionSettingsView()
                .readHeight()
                .tabItem { Label("Supervision", systemImage: SettingsTab.supervision.systemImageName) }
                .tag(SettingsTab.supervision)

            // Example for Rule Sets tab
            RuleSetsSettingsView()
                .readHeight()
                .tabItem { Label("Rule Sets", systemImage: SettingsTab.ruleSets.systemImageName) }
                .tag(SettingsTab.ruleSets)

            // Example for External MCPs tab
            ExternalMCPsSettingsView()
                .readHeight()
                .tabItem { Label("External MCPs", systemImage: SettingsTab.externalMCPs.systemImageName) }
                .tag(SettingsTab.externalMCPs)
            
            AdvancedSettingsView()
                 .readHeight()
                 .tabItem { Label("Advanced", systemImage: SettingsTab.advanced.systemImageName) }
                 .tag(SettingsTab.advanced)

            // Example for Log tab
            // LogSettingsView() // TODO: LogSettingsView is in Diagnostics module, need to expose it
                // .tabItem { Label("Log", systemImage: SettingsTab.log.systemImageName) }
                // .tag(SettingsTab.log)
            AXInspectorLogView() // Use the renamed and clarified Log View
                .readHeight()
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
            .readHeight()
            .tabItem { Label("Developer", systemImage: SettingsTab.developer.systemImageName) }
            .tag(SettingsTab.developer)
            
            AboutSettingsView()
                .readHeight()
                .tabItem { Label("About", systemImage: SettingsTab.about.systemImageName) }
                .tag(SettingsTab.about)
            
        }
        .padding(20) // Padding around the TabView content
        .frame(idealHeight: idealContentHeight, maxHeight: idealContentHeight) // Apply dynamic height
        .onPreferenceChange(IdealHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 { // Ensure we have a valid height
                // Add a little extra padding for the TabView itself and main padding
                self.idealContentHeight = newHeight + 60 // Adjust this offset as needed
            }
        }
        .animation(.default, value: idealContentHeight) // Animate height changes
        // .fixedSize(horizontal: false, vertical: true) // This might conflict with dynamic height, test removal
        
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

// ViewModifier to read the height of a view using GeometryReader and PreferenceKey
extension View {
    func readHeight() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(key: IdealHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
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
        .frame(width: 500, height: 600) // Provide a preview frame
    }
}

// Placeholder for missing views to allow compilation - these should be actual views
struct RuleSetsSettingsView: View { var body: some View { Text("Rule Sets Settings\nLine2\nLine3\nLine4").padding().frame(height: 100) } } // Added frame for testing
struct ExternalMCPsSettingsView: View { var body: some View { Text("External MCPs Settings\nAnother Line").padding().frame(height: 150) } }
// LogSettingsView is already defined in Sources/Diagnostics/LogSettingsView.swift
