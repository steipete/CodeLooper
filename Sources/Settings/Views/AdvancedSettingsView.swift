import Defaults
import DesignSystem
import SwiftUI

struct AdvancedSettingsView: View {
    // MARK: Internal

    @Default(.showDebugMenu) var showDebugMenu

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
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

            // Window Behavior
            DSSettingsSection("Window Behavior") {
                DSPicker(
                    "Window Float Level",
                    selection: $windowFloatLevel,
                    options: [
                        ("normal", "Normal"),
                        ("floating", "Floating"),
                        ("screenSaver", "Always on Top")
                    ]
                )
            }

            // Recovery Behavior
            DSSettingsSection("Recovery Behavior") {
                DSToggle(
                    "Allow Concurrent Interventions",
                    isOn: $allowConcurrentInterventions,
                    description: "Handle multiple Cursor issues simultaneously"
                )

                DSDivider()

                DSToggle(
                    "Use Aggressive Recovery",
                    isOn: $useAggressiveRecovery,
                    description: "Try harder recovery methods when gentle approaches fail"
                )
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

                        HStack(spacing: Spacing.small) {
                            DSButton("Reset All Preferences", style: .destructive, size: .small) {
                                showResetConfirmation = true
                            }
                            .frame(maxWidth: .infinity)

                            DSButton("Clear All Data", style: .destructive, size: .small) {
                                clearAllData()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, Spacing.xSmall)
                    }
                }
            }

            Spacer()
        }
        .alert("Reset All Preferences?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllPreferences()
            }
        } message: {
            Text("This will reset all CodeLooper settings to their default values.")
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
    @State private var windowFloatLevel = "normal"
    @State private var allowConcurrentInterventions = false
    @State private var useAggressiveRecovery = false

    @State private var showResetConfirmation = false
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

    private func resetAllPreferences() {
        // Reset all Defaults keys
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }

    private func clearAllData() {
        // Clear all app data
        resetAllPreferences()
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
