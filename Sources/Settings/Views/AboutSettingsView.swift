import SwiftUI
import Defaults

@MainActor
struct AboutSettingsView: View {
    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image("AppIcon") // Assumes AppIcon is in your asset catalog
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 5)

            Text(Constants.appName)
                .font(.largeTitle)
                .fontWeight(.bold)

            if !appVersion.isEmpty || !buildNumber.isEmpty {
                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Text("CodeLooper helps you automate and enhance your workflows.\n© \(Calendar.current.component(.year, from: Date())) \(Constants.appAuthor). All rights reserved.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Link("CodeLooper Website", destination: URL(string: "https://codelooper.com")!)
                Link("View Source on GitHub", destination: URL(string: Constants.githubRepositoryURL)!)
                Link("Follow @CodeLooperApp on X", destination: URL(string: "https://twitter.com/CodeLooperApp")!)
                Link("Contact Support", destination: URL(string: "mailto:support@codelooper.com")!)
            }
            .font(.body)
            
            Spacer() 
            
            Text("Powered by Swift & SwiftUI with AXorcist for accessibility automation.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .onAppear {
            self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
            self.buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        }
    }
}

struct AboutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSettingsView()
    }
} 