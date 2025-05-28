import DesignSystem
import SwiftUI

struct AboutSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Main content with padding
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    // App Info Card
                    DSCard(style: .elevated) {
                        VStack(spacing: Spacing.large) {
                            // App Icon and Name
                            VStack(spacing: Spacing.medium) {
                                if let appIcon = NSApplication.shared.applicationIconImage {
                                    Image(nsImage: appIcon)
                                        .resizable()
                                        .frame(width: 128, height: 128)
                                        .cornerRadiusDS(Layout.CornerRadius.xLarge)
                                        .shadowStyle(Layout.Shadow.large)
                                }

                                Text("CodeLooper")
                                    .font(Typography.largeTitle())
                                    .foregroundColor(ColorPalette.text)

                                Text("The Cursor Connection Guardian")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.textSecondary)

                                HStack(spacing: Spacing.small) {
                                    DSBadge("Version \(appVersion)", style: .primary)
                                    DSBadge("Build \(buildNumber)", style: .default)
                                }
                            }

                            DSDivider()

                            // Description
                            Text(
                                """
                                CodeLooper keeps your Cursor AI sessions running smoothly by automatically \
                                detecting and resolving connection issues, stuck states, and other common problems.
                                """
                            )
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.text)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                        }
                    }


                    // Links Section
                    DSSettingsSection("Resources") {
                        LinkRow(
                            icon: "globe",
                            title: "Website",
                            subtitle: "Visit our homepage",
                            url: "https://codelooper.app"
                        )

                        DSDivider()

                        LinkRow(
                            icon: "doc.text",
                            title: "Documentation",
                            subtitle: "Learn how to use CodeLooper",
                            url: "https://github.com/steipete/codelooper/wiki"
                        )

                        DSDivider()

                        LinkRow(
                            icon: "exclamationmark.bubble",
                            title: "Report an Issue",
                            subtitle: "Help us improve CodeLooper",
                            url: "https://github.com/steipete/codelooper/issues"
                        )

                        DSDivider()

                        LinkRow(
                            icon: "star",
                            title: "Star on GitHub",
                            subtitle: "Show your support",
                            url: "https://github.com/steipete/codelooper"
                        )
                    }
                }
                .padding(Spacing.xLarge)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Private

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}


// MARK: - Link Row Component

private struct LinkRow: View {
    // MARK: Internal

    let icon: String
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        Button(
            action: { openURL() },
            label: {
                HStack(spacing: Spacing.small) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(ColorPalette.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                        Text(title)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)

                        Text(subtitle)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.textSecondary)
                        .opacity(isHovered ? 1 : 0.5)
                }
                .padding(.vertical, Spacing.xxSmall)
                .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
    }

    // MARK: Private

    @State private var isHovered = false

    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}


// MARK: - Preview

#if DEBUG
    struct AboutSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AboutSettingsView()
                .frame(width: 500, height: 700)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
