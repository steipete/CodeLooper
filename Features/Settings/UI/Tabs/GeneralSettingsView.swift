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

    @State private var appIcon: NSImage?
    @State private var isValidApp = false

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
                                .frame(width: 140, height: 32)
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
                            HStack(spacing: Spacing.small) {
                                // App icon (fixed size to prevent jumping)
                                Group {
                                    if let appIcon {
                                        Image(nsImage: appIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else {
                                        Image(systemName: "app.dashed")
                                            .foregroundColor(ColorPalette.textTertiary)
                                    }
                                }
                                .frame(width: 20, height: 20)

                                Text("Git Client App:")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.text)
                            }
                            .frame(width: 160, alignment: .leading)

                            DSTextField("", text: $gitClientApp)
                                .frame(maxWidth: .infinity)
                                .onChange(of: gitClientApp) { _, newValue in
                                    loadAppIcon(for: newValue)
                                }

                            DSButton("Browse...", style: .secondary, size: .small) {
                                selectGitClientApp()
                            }
                            .frame(width: 140, height: 32)
                            .fixedSize()
                        }

                        HStack {
                            Text("Path to your Git client application (e.g., Tower, SourceTree, GitKraken)")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                                .lineSpacing(3)

                            if !gitClientApp.isEmpty {
                                Spacer()
                                Image(systemName: isValidApp ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isValidApp ? ColorPalette.success : ColorPalette.error)
                                    .font(.system(size: 12))
                            }
                        }
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
        .onAppear {
            loadAppIcon(for: gitClientApp)
        }
    }

    private func loadAppIcon(for appPath: String) {
        Task { @MainActor in
            guard !appPath.isEmpty else {
                appIcon = nil
                isValidApp = false
                return
            }

            let url = URL(fileURLWithPath: appPath)

            // Check if the app exists and is a valid application
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: appPath, isDirectory: &isDirectory)

            guard exists else {
                appIcon = nil
                isValidApp = false
                return
            }

            // Check if it's an application bundle
            let isApp = url.pathExtension.lowercased() == "app" || isDirectory.boolValue

            guard isApp else {
                appIcon = nil
                isValidApp = false
                return
            }

            // Try to load the app icon
            let workspace = NSWorkspace.shared
            let icon = workspace.icon(forFile: appPath)

            // Resize icon to consistent size
            let resizedIcon = NSImage(size: NSSize(width: 20, height: 20))
            resizedIcon.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 20, height: 20))
            resizedIcon.unlockFocus()

            appIcon = resizedIcon
            isValidApp = true
        }
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
            loadAppIcon(for: url.path)
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
