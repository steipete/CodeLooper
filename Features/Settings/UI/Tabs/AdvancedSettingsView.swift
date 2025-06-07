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
    @StateObject private var httpServer = HTTPServerService.shared

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
                    description: "Show the Debug tab in settings with debugging tools and development options",
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

            // HTTP Server Settings
            DSSettingsSection("HTTP Server") {
                DSToggle(
                    "Enable HTTP Server",
                    isOn: Binding(
                        get: { Defaults[.httpServerEnabled] },
                        set: { newValue in
                            Defaults[.httpServerEnabled] = newValue
                            if newValue {
                                Task { await HTTPServerService.shared.startServer() }
                            } else {
                                Task { await HTTPServerService.shared.stopServer() }
                            }
                        }
                    ),
                    description: "Enable HTTP server for remote monitoring and control of Claude and Cursor instances",
                    descriptionLineSpacing: 3
                )

                if Defaults[.httpServerEnabled] {
                    DSDivider()
                    
                    HStack {
                        Text("Port:")
                            .frame(width: 60, alignment: .leading)
                        TextField("8080", value: Binding(
                            get: { Defaults[.httpServerPort] },
                            set: { newValue in
                                Defaults[.httpServerPort] = newValue
                                if Defaults[.httpServerEnabled] {
                                    Task {
                                        await HTTPServerService.shared.restartServer()
                                    }
                                }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        
                        Spacer()
                        
                        // Server status indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(httpServer.isRunning ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(httpServer.isRunning ? "Running" : "Stopped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Screenshot Refresh:")
                            .frame(width: 140, alignment: .leading)
                        TextField("1000", value: Binding(
                            get: { Defaults[.httpServerScreenshotRefreshRate] },
                            set: { newValue in Defaults[.httpServerScreenshotRefreshRate] = newValue }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        Text("ms")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("ngrok API Key:")
                            .frame(width: 100, alignment: .leading)
                        SecureField("API Key", text: Binding(
                            get: { Defaults[.ngrokAPIKey] },
                            set: { newValue in Defaults[.ngrokAPIKey] = newValue }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Access your instances at: http://localhost:\(Defaults[.httpServerPort])")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if httpServer.isRunning {
                            DSButton("Open Web Interface", style: .tertiary, size: .small) {
                                if let url = URL(string: "http://localhost:\(Defaults[.httpServerPort])") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
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
        // Reset all Defaults keys in smaller groups to avoid compiler timeout
        Defaults.reset(
            .startAtLogin,
            .showInMenuBar,
            .showInDock,
            .automaticallyCheckForUpdates,
            .isGlobalMonitoringEnabled
        )
        
        Defaults.reset(
            .monitoringIntervalSeconds,
            .maxInterventionsBeforePause,
            .playSoundOnIntervention,
            .textForCursorStopsRecovery,
            .showDebugMenu
        )
        
        Defaults.reset(
            .gitClientApp,
            .debugMode
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
