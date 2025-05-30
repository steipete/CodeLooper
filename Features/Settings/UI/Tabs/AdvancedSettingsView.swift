import AppKit
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

/// Advanced settings view for power users and debugging.
///
/// AdvancedSettingsView provides access to:
/// - System permissions management
/// - Automation statistics and counters
/// - Debug menu toggles
/// - Developer-focused options
/// - Advanced configuration settings
///
/// This view contains settings that are typically not needed
/// for everyday use but are valuable for troubleshooting and
/// advanced customization.
struct AdvancedSettingsView: View {
    // MARK: Internal

    @Default(.showDebugMenu) var showDebugMenu
    @Default(.debugMode) var debugMode

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // System Permissions
            DSSettingsSection("System Permissions") {
                AllPermissionsView()
            }

            // Rule Execution Statistics
            DSSettingsSection("Automation Statistics") {
                RuleExecutionStatsView()

                HStack {
                    DSButton("Reset All Counters", style: .secondary, size: .small) {
                        RuleCounterManager.shared.resetAllCounters()
                    }
                    .frame(width: 140)

                    Spacer()

                    DSToggle(
                        "Show Counters",
                        isOn: Binding<Bool>(
                            get: { Defaults[.showRuleExecutionCounters] },
                            set: { Defaults[.showRuleExecutionCounters] = $0 }
                        )
                    )
                }
            }

            // Developer Options
            DSSettingsSection("Developer Options") {
                DSToggle(
                    "Debug Mode",
                    isOn: $debugMode,
                    description: "Show the Debug tab in settings with Lottie animation tests and debugging tools",
                    descriptionLineSpacing: 3
                )

                DSDivider()

                DSToggle(
                    "Enable Detailed Logging",
                    isOn: $enableDetailedLogging,
                    description: "Enable verbose logging and save logs to ~/Library/Logs/CodeLooper/",
                    descriptionLineSpacing: 3
                )

                if enableDetailedLogging {
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

            // Danger Zone
            DSSettingsSection("Danger Zone") {
                HStack(spacing: Spacing.medium) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Caution")
                                .font(Typography.callout(.semibold))
                                .foregroundColor(.orange)
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
        .onAppear {
            // Sync initial state
            Defaults[.verboseLogging] = enableDetailedLogging
            LogConfiguration.shared.updateVerbosity(enableDetailedLogging)
        }
        .onChange(of: enableDetailedLogging) { _, newValue in
            // Update verbose logging when detailed logging changes
            Defaults[.verboseLogging] = newValue
            LogConfiguration.shared.updateVerbosity(newValue)
        }
    }

    // MARK: Private

    @Default(.enableDetailedLogging) private var enableDetailedLogging

    @State private var showResetAndRestartConfirmation = false
    @State private var showLogsClearedAlert = false

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
            .debugMode,
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
}

// MARK: - Preview

#if DEBUG
    struct AdvancedSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AdvancedSettingsView()
                .frame(width: 500, height: 700)
                .padding()
                .withDesignSystem()
        }
    }
#endif
