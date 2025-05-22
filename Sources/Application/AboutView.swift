import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }
    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? "Copyright © 2024 Your Name. All rights reserved."
    }
    private let appName = "CodeLooper"
    private let websiteURL = URL(string: "https://codelooper.app/")!
    private let twitterURL = URL(string: "https://x.com/CodeLoopApp")!
    private let githubURL = URL(string: "https://github.com/steipete/CodeLooper")!

    var body: some View {
        VStack(spacing: 15) {
            Image("logo") // Assuming 'logo_large' exists in Assets
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .padding(.top)

            Text(appName)
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Version \\(appVersion) (Build \\(appBuild))")
                .font(.callout)
                .foregroundColor(.secondary)

            Text(copyright)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 10) {
                Link("CodeLooper Website", destination: websiteURL)
                Link("Follow @CodeLoopApp on X", destination: twitterURL)
                Link("View on GitHub", destination: githubURL)
            }
            .font(.callout)
            
            Spacer()
            
            Text("CodeLooper helps automate and enhance your Cursor experience.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .padding(EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40))
        .frame(width: 400, height: 400)
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif 