import AppKit
import Defaults
import SwiftUI

/// About tab view
struct AboutSettingsTab: View {
    // Use @Bindable for consistency, though this view doesn't directly bind to properties
    @Bindable var viewModel: MainSettingsViewModel
    
    /// App display name that includes pre-release indicator if applicable
    private var appDisplayName: String {
        let baseName = Constants.appName
        
        // Check if this is a pre-release build
        if let prereleaseFlag = Bundle.main.object(forInfoDictionaryKey: "IS_PRERELEASE_BUILD") as? String,
           prereleaseFlag.lowercased() == "yes" || prereleaseFlag == "1" {
            return "\(baseName) (Pre-release)"
        }
        
        return baseName
    }

    var body: some View {
        ScrollView {
            // For this vertically centered layout, Grid doesn't add as much value
            // But we can use it for the links section
            VStack(spacing: 12) {
                // App Icon and Version
                VStack(spacing: 10) {
                    // App Icon
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)

                    // App Name and Version
                    Text(appDisplayName)
                        .font(.title)
                        .bold()

                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
                    Text("Version \(version) (Build \(build))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)

                // App Description
                Text("""
                CodeLooper is your coding companion for macOS, helping you be more productive \
                with your development workflow.
                """)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 400)
                .padding(.horizontal)
                .padding(.vertical, 2)

                // Developer Info
                VStack(spacing: 5) {
                    Text("Open Source Project")
                        .font(.headline)

                    Text("Community Driven")
                        .font(.body)
                }
                .padding(.top, 2)

                // Single website link button
                Link("View on GitHub", destination: URL(string: Constants.githubRepositoryURL)!)
                    .padding(.top)

                // Copyright
                let year = Calendar.current.component(.year, from: Date())
                Text("© \(year) \(Constants.appAuthor). All rights reserved.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 5)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

#if hasFeature(PreviewsMacros)
    #Preview {
        // Create dummy/shared instances for preview
        let loginItemManager = LoginItemManager.shared
        let sparkleUpdaterManager = SparkleUpdaterManager() // Assuming it can be init'd simply
        let updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: sparkleUpdaterManager)
        let mainSettingsViewModel = MainSettingsViewModel(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        AboutSettingsTab(viewModel: mainSettingsViewModel)
            // .environmentObject(mainSettingsViewModel) // viewModel is passed directly, no need for environmentObject here
            .frame(width: 350, height: 400)
    }
#endif

#if hasFeature(PreviewsMacros)
struct AboutSettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        // Create dummy/shared instances for preview
        let loginItemManager = LoginItemManager.shared
        let sparkleUpdaterManager = SparkleUpdaterManager() // Assuming it can be init'd simply
        let updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: sparkleUpdaterManager)
        let mainSettingsViewModel = MainSettingsViewModel(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        AboutSettingsTab(viewModel: mainSettingsViewModel)
            // .environmentObject(mainSettingsViewModel) // viewModel is passed directly, no need for environmentObject
            // here
            .frame(width: 350, height: 400)
    }
}
#endif
