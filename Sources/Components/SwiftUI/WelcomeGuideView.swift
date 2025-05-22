import Defaults
import SwiftUI

struct WelcomeGuideView: View {
    @Binding var isPresented: Bool // To dismiss the view
    // Consider adding an action to open Accessibility settings
    // var openAccessibilitySettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to CodeLooper!")
                .font(.largeTitle)
                .padding(.top)

            Text(
                "CodeLooper helps supervise your Cursor application by automatically resolving " +
                "common interruptions and assisting with AI agent configurations."
            )
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 15) {
                FeatureHighlight(
                    imageName: "bolt.shield.fill",
                    text: "Automatic Recovery: Handles connection issues, stuck states, and force-stops in Cursor."
                )
                FeatureHighlight(
                    imageName: "gearshape.2.fill",
                    text: "MCP Assistance: Helps configure Model Context Protocol servers " +
                        "for enhanced AI agent capabilities."
                )
                FeatureHighlight(
                    imageName: "lock.shield.fill",
                    text: "Accessibility Powered: Uses macOS Accessibility to understand " +
                        "and interact with Cursor. Please grant permissions when prompted."
                )
            }
            .padding()
            
            Text(
                "To get started, CodeLooper needs Accessibility permissions. " +
                "You\'ll be guided to enable this after closing this window if permissions are not yet granted."
            )
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Let\'s Get Started!") {
                Defaults[.hasShownWelcomeGuide] = true
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 450, height: 480)
    }
}

struct FeatureHighlight: View {
    let imageName: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: imageName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            Text(text)
                .font(.body)
        }
    }
}

struct WelcomeGuideView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeGuideView(isPresented: .constant(true))
    }
} 
