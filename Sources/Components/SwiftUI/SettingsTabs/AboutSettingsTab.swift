import AppKit
import Defaults
import SwiftUI

/// About tab view
struct AboutSettingsTab: View {
    // Use @Bindable for consistency, though this view doesn't directly bind to properties
    @Bindable var viewModel: MainSettingsViewModel

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
                    Text(Constants.appName)
                        .font(.title)
                        .bold()

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)

                // App Description
                Text("""
                CodeLooper is your coding companion for macOS, helping you be more productive \
                with your development workflow.
                """)
                    .multilineTextAlignment(.center)
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
                Button("Visit GitHub") {
                    if let url = URL(string: "https://github.com/codelooper/codelooper") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .frame(width: 140)
                .padding(.top, 2)

                // Copyright
                let year = Calendar.current.component(.year, from: Date())
                Text("© \(year) CodeLooper Contributors. All rights reserved.")
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

#Preview {
    // Create dummy UpdaterViewModel for the preview
    let dummySparkleUpdaterManager = SparkleUpdaterManager()
    let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

    AboutSettingsTab(viewModel: MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: dummyUpdaterViewModel
    ))
}
