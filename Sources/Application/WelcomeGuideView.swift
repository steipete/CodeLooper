import Defaults
import SwiftUI

struct WelcomeGuideView: View {
    @Default(.hasShownWelcomeGuide) var hasShownWelcomeGuide
    // This action will be provided by the presenting context (e.g., AppDelegate)
    // to dismiss the window and potentially trigger permission checks.
    var onGetStarted: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image("logo") // Assuming a larger logo for the welcome guide
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 20)

            Text("Welcome to CodeLooper!")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 15) {
                Text(
                    "CodeLooper helps you keep your Cursor application running smoothly and enhances your AI-assisted development workflow."
                )
                .fixedSize(horizontal: false, vertical: true)

                FeatureHighlightView(
                    systemImage: "arrow.triangle.2.circlepath.icloud.fill",
                    title: "Automatic Recovery",
                    description: "CodeLooper monitors Cursor for common interruptions (like connection issues or " +
                        "unexpected stops) and attempts to resolve them automatically, minimizing disruptions."
                )

                FeatureHighlightView(
                    systemImage: "server.rack",
                    title: "MCP Server Assistance",
                    description: "Easily configure and manage External Model Context Protocol (MCP) servers " +
                        "(like Claude Code, macOS Automator, XcodeBuild) to extend Cursor's capabilities."
                )

                FeatureHighlightView(
                    systemImage: "lock.shield.fill",
                    title: "Accessibility Permissions Required",
                    description: "To monitor and interact with Cursor's UI elements, CodeLooper needs Accessibility " +
                        "permissions. You'll be guided to grant these if needed."
                )
            }
            .padding(.horizontal, 30)

            Spacer()

            Button(action: {
                hasShownWelcomeGuide = true
                onGetStarted() // Call the closure to dismiss and proceed
            }) {
                Text("Let\'s Get Started!")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain) // Use plain to allow full custom background and foreground
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 500, height: 650) // Adjusted size for more content
    }
}

struct FeatureHighlightView: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 30, alignment: .center) // Align icons

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
    struct WelcomeGuideView_Previews: PreviewProvider {
        static var previews: some View {
            WelcomeGuideView {
                print("Get Started Clicked!")
            }
        }
    }
#endif
