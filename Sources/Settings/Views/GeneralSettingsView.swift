import SwiftUI
import Defaults
import KeyboardShortcuts // For KeyboardShortcuts.Recorder
import AppKit // Required for NSApp to access AppDelegate

// Note: Ensure Notification.Name.menuBarVisibilityChanged is defined globally or accessible.
// If not, it should be defined here or in a shared constants file.
// For example:
/*
 extension Notification.Name {
 static let menuBarVisibilityChanged = Notification.Name("menuBarVisibilityChanged")
 }
 */

struct GeneralSettingsView: View {
    @Default(.startAtLogin)
    var startAtLogin
    @Default(.showInMenuBar)
    var showInMenuBar
    @Default(.automaticallyCheckForUpdates)
    var automaticallyCheckForUpdates
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled
    @Default(.monitoringIntervalSeconds)
    var monitoringIntervalSeconds
    @Default(.maxInterventionsBeforePause)
    var maxInterventionsBeforePause
    @Default(.maxConnectionIssueRetries)
    var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures)
    var maxConsecutiveRecoveryFailures
    @Default(.playSoundOnIntervention)
    var playSoundOnIntervention
    @Default(.sendNotificationOnPersistentError)
    var sendNotificationOnPersistentError: Bool
    @Default(.textForCursorStopsRecovery)
    var textForCursorStopsRecovery
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.postInterventionObservationWindowSeconds)
    var postInterventionObservationWindowSeconds
    @Default(.stuckDetectionTimeoutSeconds)
    var stuckDetectionTimeoutSeconds: TimeInterval
    @Default(.showDebugMenu)
    var showDebugMenu

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    var body: some View {
        Form {
            Section(header: Text("General Application Behavior")) {
                Toggle("Launch CodeLooper at Login", isOn: $startAtLogin)
                Toggle("Show Icon in Menu Bar", isOn: $showInMenuBar)
                    .onChange(of: showInMenuBar) { oldValue, newValue in
                        NotificationCenter.default.post(
                            name: .menuBarVisibilityChanged, // Assuming this is defined
                            object: nil,
                            userInfo: ["visible": newValue]
                        )
                    }
            }

            Section(header: Text("Global Shortcut Configuration")) {
                Text("Define a global keyboard shortcut to quickly toggle monitoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                KeyboardShortcuts.Recorder("Toggle Monitoring Shortcut:", name: .toggleMonitoring)
                Text("Use standard symbols: ⌘ (Command), ⌥ (Option/Alt), ⇧ (Shift), ⌃ (Control). Example: ⌘⇧M")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Section(header: Text("Supervision Core Settings")) {
                Toggle("Enable Global Monitoring", isOn: $isGlobalMonitoringEnabled)
                HStack {
                    Text("Monitoring Interval (seconds):")
                    TextField(
                        "", // Label is now separate
                        value: $monitoringIntervalSeconds,
                        formatter: NumberFormatter.timeIntervalFormatter
                    )
                }
                Stepper(
                    "Max Auto-Interventions Per Instance: \\(maxInterventionsBeforePause)",
                    value: $maxInterventionsBeforePause,
                    in: 1...25
                )
                Toggle("Play Sound on Intervention", isOn: $playSoundOnIntervention)

                VStack(alignment: .leading) {
                    Text("Text for \'Cursor Stops\' Recovery (when CodeLooper nudges Cursor):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $textForCursorStopsRecovery)
                        .frame(height: 60)
                }
            }

            Section(header: Text("Updates (Powered by Sparkle)")) {
                Toggle("Automatically Check for Updates", isOn: $automaticallyCheckForUpdates)
                Button("Check for Updates Now") {
                    // This relies on AppDelegate being accessible and having a checkForUpdates method.
                    // Consider a more decoupled way to trigger this if AppDelegate isn't directly available.
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.checkForUpdates()
                    } else {
                        // Log error or handle missing delegate
                        print("Error: Could not get AppDelegate to check for updates.")
                    }
                }
                Text("CodeLooper Version: \\(appVersion) (Build \\(appBuild))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Troubleshooting & Reset")) {
                Button("Reset Welcome Guide") {
                    Defaults[.hasShownWelcomeGuide] = false
                    // Similar to above, this relies on AppDelegate.
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showWelcomeWindow()
                    } else {
                         print("Error: Could not get AppDelegate to reset welcome guide.")
                    }
                }
                .foregroundColor(.orange)

                Button("Reset All User Settings to Default") {
                    Defaults.reset(
                        .startAtLogin,
                        .showInMenuBar,
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
                        // Add any other relevant keys here that are part of "General Settings"
                    )
                    NotificationCenter.default.post(
                        name: .menuBarVisibilityChanged, // Assuming this is defined
                        object: nil,
                        userInfo: ["visible": Defaults[.showInMenuBar]]
                    )
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Adjust frame as needed for settings pane
    }
}

extension NumberFormatter {
    static var timeIntervalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0.5
        formatter.maximum = 5.0 // Or a more appropriate max based on your app's needs
        formatter.maximumFractionDigits = 1
        return formatter
    }
}

// Optional: Add a PreviewProvider if desired
#if DEBUG
struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
            // .environmentObject(your_mock_dependencies_if_any)
            .frame(width: 600, height: 700) // Example frame for preview
    }
}
#endif 