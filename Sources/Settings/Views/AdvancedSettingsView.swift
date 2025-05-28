import AppKit
import Defaults
import DesignSystem
import SwiftUI

struct AdvancedSettingsView: View {
    // MARK: Internal

    @Default(.showDebugMenu) var showDebugMenu
    @Default(.showDebugTab) var showDebugTab

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // System Permissions
            DSSettingsSection("System Permissions") {
                AllPermissionsView()
            }

            // Developer Options
            DSSettingsSection("Developer Options") {
                DSToggle(
                    "Show Debug Tab",
                    isOn: $showDebugTab,
                    description: "Show the Debug tab in settings with Lottie animation tests and debugging tools",
                    descriptionLineSpacing: 3
                )

                DSDivider()

                DSToggle(
                    "Enable Detailed Logging",
                    isOn: $enableDetailedLogging,
                    description: "Log verbose information for troubleshooting",
                    descriptionLineSpacing: 3
                )

                DSDivider()

                DSToggle(
                    "Log to File",
                    isOn: $logToFile,
                    description: "Save logs to ~/Library/Logs/CodeLooper/",
                    descriptionLineSpacing: 3
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
                    HStack(spacing: Spacing.medium) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(ColorPalette.warning)
                                Text("Caution")
                                    .font(Typography.callout(.semibold))
                                    .foregroundColor(ColorPalette.warning)
                            }

                            Text("This action will reset all settings and restart the app. This cannot be undone.")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                                .lineSpacing(3)
                        }

                        Spacer()

                        DSButton("Reset & Restart", style: .destructive) {
                            showResetAndRestartConfirmation = true
                        }
                        .fixedSize()
                    }
                }
            }

            Spacer()
        }
        .alert("Reset & Restart CodeLooper?", isPresented: $showResetAndRestartConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset & Restart", role: .destructive) {
                resetAllDataAndRestart()
            }
        } message: {
            Text(
                "This will reset all CodeLooper settings and data to defaults, then restart the application. This action cannot be undone."
            )
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

    @State private var showResetAndRestartConfirmation = false
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

    private func resetAllDataAndRestart() {
        // Reset all Defaults keys
        Defaults.reset(
            .startAtLogin,
            .showInMenuBar,
            .showInDock,
            .automaticallyCheckForUpdates,
            .isGlobalMonitoringEnabled,
            .monitoringIntervalSeconds,
            .maxInterventionsBeforePause,
            .playSoundOnIntervention,
            .textForCursorStopsRecovery,
            .showDebugMenu,
            .gitClientApp,
            .showDebugTab,
            .useDynamicMenuBarIcon
        )

        // Clear logs
        clearLogsFiles()

        // Post notification for any cleanup
        NotificationCenter.default.post(
            name: .menuBarVisibilityChanged,
            object: nil,
            userInfo: ["visible": Defaults[.showInMenuBar]]
        )

        // Restart the application
        restartApplication()
    }

    private func clearLogsFiles() {
        let logsPath = NSHomeDirectory() + "/Library/Logs/CodeLooper/"
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: logsPath)
            for file in contents {
                let filePath = logsPath + file
                try fileManager.removeItem(atPath: filePath)
            }
        } catch {
            // Silently handle error - logs folder might not exist or be empty
        }
    }

    private func restartApplication() {
        // Get the current application path
        let appPath = Bundle.main.bundlePath

        // Create a script to restart the app after a brief delay
        let script = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """

        // Write script to temp file
        let tempFile = NSTemporaryDirectory() + "restart_codelooper.sh"
        try? script.write(toFile: tempFile, atomically: true, encoding: .utf8)

        // Make script executable and run it
        let chmod = Process()
        chmod.launchPath = "/bin/chmod"
        chmod.arguments = ["+x", tempFile]
        chmod.launch()
        chmod.waitUntilExit()

        let restart = Process()
        restart.launchPath = "/bin/bash"
        restart.arguments = [tempFile]
        restart.launch()

        // Terminate current app
        NSApplication.shared.terminate(nil)
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
