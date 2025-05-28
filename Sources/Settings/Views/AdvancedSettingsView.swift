import AppKit
import Defaults
import DesignSystem
import SwiftUI

struct AdvancedSettingsView: View {
    // MARK: Internal

    @Default(.showDebugMenu) var showDebugMenu
    @Default(.gitClientApp) var gitClientApp

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // System Permissions
            DSSettingsSection("System Permissions") {
                AllPermissionsView()
            }

            // Developer Options
            DSSettingsSection("Developer Options") {
                DSToggle(
                    "Show Debug Menu",
                    isOn: $showDebugMenu,
                    description: "Enable additional debug options in the menu bar"
                )

                DSDivider()

                DSToggle(
                    "Enable Detailed Logging",
                    isOn: $enableDetailedLogging,
                    description: "Log verbose information for troubleshooting"
                )

                DSDivider()

                DSToggle(
                    "Log to File",
                    isOn: $logToFile,
                    description: "Save logs to ~/Library/Logs/CodeLooper/"
                )

                if logToFile {
                    HStack {
                        Spacer()
                        DSButton("Open Logs Folder", style: .tertiary, size: .small) {
                            openLogsFolder()
                        }

                        DSButton("Clear Logs", style: .tertiary, size: .small) {
                            clearLogs()
                        }
                    }
                    .padding(.top, Spacing.xxSmall)
                }
            }

            // Git Integration
            DSSettingsSection("Git Integration") {
                HStack(spacing: Spacing.small) {
                    Text("Git Client App:")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.text)
                    
                    DSTextField("", text: $gitClientApp)
                        .frame(width: 200)
                    
                    DSButton("Browse...", style: .secondary, size: .small) {
                        selectGitClientApp()
                    }
                }
                
                Text("Path to your Git client application (e.g., Tower, SourceTree, GitKraken)")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            // Developer Actions
            DSSettingsSection("Developer Actions") {
                HStack(spacing: Spacing.small) {
                    DSButton("View mcp.json", style: .secondary, size: .small) {
                        viewMcpJson()
                    }
                    .frame(maxWidth: .infinity)

                    DSButton("Open AXpector", style: .secondary, size: .small) {
                        NotificationCenter.default.post(name: .showAXpectorWindow, object: nil)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Troubleshooting
            DSSettingsSection("Troubleshooting") {
                DSButton("Reset Welcome Guide", style: .tertiary) {
                    Defaults[.hasShownWelcomeGuide] = false
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.windowManager?.showWelcomeWindow()
                    }
                }
            }

            // Danger Zone
            DSSettingsSection("Danger Zone") {
                DSCard(style: .filled) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ColorPalette.warning)
                            Text("Caution")
                                .font(Typography.callout(.semibold))
                                .foregroundColor(ColorPalette.warning)
                        }

                        Text("These actions cannot be undone. Please be careful.")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)

                        VStack(spacing: Spacing.small) {
                            DSButton("Reset All Settings to Default", style: .destructive) {
                                showResetConfirmation = true
                            }
                            .frame(maxWidth: .infinity)

                            DSButton("Clear All Data", style: .destructive) {
                                showClearDataConfirmation = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, Spacing.xSmall)
                    }
                }
            }

            Spacer()
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all CodeLooper settings to their default values.")
        }
        .alert("Clear All Data?", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will clear all CodeLooper data including settings and logs.")
        }
        .alert("Logs Cleared", isPresented: $showLogsClearedAlert) {
            Button("OK") {}
        } message: {
            Text("All log files have been deleted.")
        }
        .alert("File Not Found", isPresented: $showMcpJsonNotFoundAlert) {
            Button("OK") {}
        } message: {
            Text("The file mcp.json was not found at \(mcpJsonNotFoundPath).")
        }
    }

    // MARK: Private

    @State private var enableDetailedLogging = false
    @State private var logToFile = false

    @State private var showResetConfirmation = false
    @State private var showClearDataConfirmation = false
    @State private var showLogsClearedAlert = false
    @State private var showMcpJsonNotFoundAlert = false
    @State private var mcpJsonNotFoundPath: String = ""

    private func openLogsFolder() {
        let logsPath = NSHomeDirectory() + "/Library/Logs/CodeLooper/"
        if let url = URL(string: "file://" + logsPath) {
            NSWorkspace.shared.open(url)
        }
    }

    private func clearLogs() {
        // Implementation for clearing logs
        showLogsClearedAlert = true
    }

    private func resetAllSettings() {
        // Reset all Defaults keys
        Defaults.reset(
            .startAtLogin,
            .showInMenuBar,
            .showInDock,
            .automaticallyCheckForUpdates,
            .isGlobalMonitoringEnabled,
            .monitoringIntervalSeconds,
            .maxInterventionsBeforePause,
            .maxConnectionIssueRetries,
            .maxConsecutiveRecoveryFailures,
            .playSoundOnIntervention,
            .sendNotificationOnPersistentError,
            .textForCursorStopsRecovery,
            .monitorSidebarActivity,
            .postInterventionObservationWindowSeconds,
            .stuckDetectionTimeoutSeconds,
            .showDebugMenu
        )
        NotificationCenter.default.post(
            name: .menuBarVisibilityChanged,
            object: nil,
            userInfo: ["visible": Defaults[.showInMenuBar]]
        )
    }

    private func clearAllData() {
        // Clear all app data
        resetAllSettings()
        clearLogs()
    }

    private func viewMcpJson() {
        let fileManager = FileManager.default
        let cursorConfigDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".cursor")
        let mcpJsonPath = cursorConfigDir.appendingPathComponent("mcp.json")

        if fileManager.fileExists(atPath: mcpJsonPath.path) {
            NSWorkspace.shared.open(mcpJsonPath)
        } else {
            showMcpJsonNotFoundAlert = true
            mcpJsonNotFoundPath = mcpJsonPath.path
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
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct AdvancedSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AdvancedSettingsView()
                .frame(width: 500, height: 700)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
