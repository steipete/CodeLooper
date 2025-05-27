import Defaults
import Diagnostics
import SwiftUI

// PreferenceKey to communicate ideal height from child views
struct IdealHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue() // Use the latest reported height
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

// Ensure these are globally accessible or defined if not already
// extension Notification.Name {
//    static let menuBarVisibilityChanged = Notification.Name(\"menuBarVisibilityChanged\")
// }
// extension KeyboardShortcuts.Name {
//    static let toggleMonitoring = Self(\"toggleMonitoring\")
// }

struct SettingsPanesContainerView: View {
    // MARK: Internal

    @EnvironmentObject var mainSettingsViewModel: MainSettingsViewModel
    @EnvironmentObject var sessionLogger: SessionLogger // Assuming SessionLogger is provided higher up

    var body: some View {
        VStack(spacing: 0) { // Use VStack to manage TabView and Footer
            TabView(selection: $mainSettingsViewModel.selectedTab) { // Bind selection to ViewModel
                GeneralSettingsView(updaterViewModel: mainSettingsViewModel.updaterViewModel)
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(SettingsTab.general)
                    .focusable()
                    .focused($focusedTab, equals: .general)

                CursorSupervisionSettingsView()
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("Supervision", systemImage: "eye.fill")
                    }
                    .tag(SettingsTab.supervision)
                    .focusable()
                    .focused($focusedTab, equals: .supervision)

                CursorRuleSetsSettingsView()
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("Rule Sets", systemImage: "list.star")
                    }
                    .tag(SettingsTab.ruleSets)
                    .focusable()
                    .focused($focusedTab, equals: .ruleSets)

                ExternalMCPsSettingsView()
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("External MCPs", systemImage: "server.rack")
                    }
                    .tag(SettingsTab.externalMCPs)
                    .focusable()
                    .focused($focusedTab, equals: .externalMCPs)

                AdvancedSettingsView()
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                    .tag(SettingsTab.advanced)
                    .focusable()
                    .focused($focusedTab, equals: .advanced)

                AXInspectorLogView() // Renamed from Text(...)
                    .readHeight() // Apply readHeight
                    .tabItem {
                        Label("Log", systemImage: "doc.text.fill")
                    }
                    .tag(SettingsTab.log)
                    .focusable()
                    .focused($focusedTab, equals: .log)
            }
            .environmentObject(mainSettingsViewModel) // Provide to tabs that need it
            // .frame(maxWidth: .infinity, maxHeight: .infinity) // Remove fixed max height
            .frame(idealHeight: idealContentHeight, maxHeight: idealContentHeight) // Apply dynamic height
            .onPreferenceChange(IdealHeightPreferenceKey.self) { newHeight in
                if newHeight > 0 { // Ensure we have a valid height
                    // Adjust this offset as needed for TabView chrome and padding
                    self.idealContentHeight = newHeight + 20
                }
            }
            .animation(.default, value: idealContentHeight) // Animate height changes
            .onChange(of: mainSettingsViewModel.selectedTab) { _, newValue in
                // Changed to observe ViewModel's selectedTab
                focusedTab = newValue // Update focus state when tab changes
            }
            .onAppear { // Set initial focus
                focusedTab = mainSettingsViewModel.selectedTab
            }
            // Potentially add .fixedSize(horizontal: false, vertical: true) to TabView if needed

            // Common Footer (Spec 3.3)
            Divider()
            HStack(spacing: 20) {
                if let codeLooperURL = URL(string: "https://codelooper.app/") {
                    Link("CodeLooper.app", destination: codeLooperURL)
                }
                if let twitterURL = URL(string: "https://x.com/CodeLoopApp") {
                    Link("Follow @CodeLoopApp on X", destination: twitterURL)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .font(.caption)
        }
    }

    // MARK: Private

    @State private var idealContentHeight: CGFloat = 450 // Default/initial height, adjusted slightly
    @FocusState private var focusedTab: SettingsTab?
}

#if DEBUG
    struct SettingsPanesContainerView_Previews: PreviewProvider {
        static var previews: some View {
            // Create dummy UpdaterViewModel for the preview
            let dummySparkleUpdaterManager = SparkleUpdaterManager()
            let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

            SettingsPanesContainerView()
                .environmentObject(MainSettingsViewModel(
                    loginItemManager: LoginItemManager.shared,
                    updaterViewModel: dummyUpdaterViewModel
                ))
                .environmentObject(SessionLogger.shared) // Provide a SessionLogger for the preview
        }
    }
#endif
