import AppKit
import Defaults
import DesignSystem
import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var mainSettingsViewModel: MainSettingsViewModel
    @Default(.automaticallyCheckForUpdates)
    var automaticallyCheckForUpdates
    @Default(.showInDock)
    var showInDock
    @Default(.gitClientApp) var gitClientApp
    @ObservedObject var updaterViewModel: UpdaterViewModel

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                // General Application Behavior
                DSSettingsSection("General") {
                    DSToggle(
                        "Launch CodeLooper at Login",
                        isOn: Binding(
                            get: { mainSettingsViewModel.startAtLogin },
                            set: { mainSettingsViewModel.updateStartAtLogin($0) }
                        ),
                        description: "Automatically start CodeLooper when you log in to your Mac"
                    )

                    DSDivider()

                    DSToggle(
                        "Show CodeLooper in Dock",
                        isOn: $showInDock,
                        description: "Display CodeLooper icon in the dock"
                    )
                }

                // Global Shortcut Configuration
                DSSettingsSection("Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                Text("Toggle Monitoring")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.text)

                                Text("Define a global keyboard shortcut to quickly toggle monitoring")
                                    .font(Typography.caption1())
                                    .foregroundColor(ColorPalette.textSecondary)
                                    .lineSpacing(3)
                            }

                            Spacer()

                            KeyboardShortcuts.Recorder(for: .toggleMonitoring)
                                .frame(width: 120, height: 32)
                                .fixedSize()
                        }

                        Text("Use standard symbols: ⌘ (Command), ⌥ (Option/Alt), ⇧ (Shift), ⌃ (Control)")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textTertiary)
                    }
                }

                // Git Integration
                DSSettingsSection("Git Integration") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack(spacing: Spacing.small) {
                            Text("Git Client App:")
                                .font(Typography.body())
                                .foregroundColor(ColorPalette.text)
                                .frame(width: 120, alignment: .leading)

                            DSTextField("", text: $gitClientApp)
                                .frame(maxWidth: .infinity)

                            DSButton("Browse...", style: .secondary, size: .small) {
                                selectGitClientApp()
                            }
                            .frame(width: 120, height: 32)
                            .fixedSize()
                        }

                        Text("Path to your Git client application (e.g., Tower, SourceTree, GitKraken)")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineSpacing(3)
                    }
                }

                // Updates
                DSSettingsSection("Updates") {
                    DSToggle(
                        "Automatically Check for Updates",
                        isOn: $automaticallyCheckForUpdates
                    )

                    DSButton("Check for Updates Now", style: .secondary) {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.checkForUpdates(nil)
                        }
                    }
                    .disabled(updaterViewModel.isUpdateInProgress)
                }

                // Version info
                HStack {
                    Spacer()
                    Text("Version \(appVersion) (\(appBuild))")
                        .textStyle(TextStyles.captionMedium)
                    Spacer()
                }
                .padding(.top, Spacing.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    private func selectGitClientApp() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Git Client Application"
        openPanel.message = "Choose your preferred Git client application"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.application]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            gitClientApp = url.path
        }
    }
}

// Preview
#if DEBUG
    struct GeneralSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            GeneralSettingsView(
                updaterViewModel: UpdaterViewModel(
                    sparkleUpdaterManager: SparkleUpdaterManager()
                )
            )
            .frame(width: 500, height: 700)
        }
    }
#endif
