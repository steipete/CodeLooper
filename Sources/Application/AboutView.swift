import SwiftUI

struct AboutView: View {
    // MARK: Internal

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

            Text("Version \\(appVersion) (Build \\(buildNumber))")
                .font(.callout)
                .foregroundColor(.secondary)

            Text(copyrightInfo)
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

    // MARK: Private

    private let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CodeLooper"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    private let copyrightInfo = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© Your Name"
    private let githubURL = URL(string: Constants.githubRepositoryURL)!
    private let websiteURL = URL(string: "https://codelooper.app/")!
    private let twitterURL = URL(string: "https://x.com/CodeLoopApp")!
}

#if DEBUG
    struct AboutView_Previews: PreviewProvider {
        static var previews: some View {
            AboutView()
        }
    }
#endif
