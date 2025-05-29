import SwiftUI

struct AboutView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 20) {
            // App Icon with pulsating animation
            if let appIcon = NSApplication.shared.applicationIconImage {
                Link(destination: websiteURL) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 128, height: 128)
                        .cornerRadius(24)
                        .shadow(radius: 10)
                        .scaleEffect(pulsateScale)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: pulsateScale
                        )
                        .onAppear {
                            pulsateScale = 1.05
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }

            Text("CodeLooper")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("The Cursor Connection Guardian")
                .font(.callout)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text("Version \(appVersion)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)

                Text("Build \(buildNumber)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(
                "CodeLooper keeps your Cursor AI sessions running smoothly by automatically detecting and resolving connection issues, stuck states, and other common problems."
            )
            .font(.footnote)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 50)

            // Resources section with simple hyperlinks
            VStack(spacing: 8) {
                Text("RESOURCES")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Link("Website", destination: websiteURL)
                        .font(.system(size: 13))
                }

                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Link("Documentation", destination: documentationURL)
                        .font(.system(size: 13))
                }

                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Link("Report an Issue", destination: issuesURL)
                        .font(.system(size: 13))
                }

                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Link("Star on GitHub", destination: githubURL)
                        .font(.system(size: 13))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
        .frame(width: 400, height: 500)
    }

    // MARK: Private

    @State private var pulsateScale: CGFloat = 1.0

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    private let githubURL = URL(string: "https://github.com/steipete/codelooper")!
    private let websiteURL = URL(string: "https://codelooper.app")!
    private let documentationURL = URL(string: "https://github.com/steipete/codelooper/wiki")!
    private let issuesURL = URL(string: "https://github.com/steipete/codelooper/issues")!
}

#if DEBUG
    struct AboutView_Previews: PreviewProvider {
        static var previews: some View {
            AboutView()
        }
    }
#endif
