import AppKit // Required for NSApp to access AppDelegate
import Defaults
import KeyboardShortcuts // For KeyboardShortcuts.Recorder
import SwiftUI

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
    @ObservedObject var updaterViewModel: UpdaterViewModel

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch CodeLooper at Login", isOn: $startAtLogin)
                Toggle("Show Icon in Menu Bar", isOn: $showInMenuBar)
                    .onChange(of: showInMenuBar) { _, newValue in
                        NotificationCenter.default.post(
                            name: .menuBarVisibilityChanged, // Assuming this is defined
                            object: nil,
                            userInfo: ["visible": newValue]
                        )
                    }
            } header: { 
                Text("General Application Behavior").padding(.top)
            }
            .padding(.bottom)

            Section {
                Text("Define a global keyboard shortcut to quickly toggle monitoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                KeyboardShortcuts.Recorder("Toggle Monitoring Shortcut:", name: .toggleMonitoring)
                Text("Use standard symbols: ⌘ (Command), ⌥ (Option/Alt), ⇧ (Shift), ⌃ (Control). Example: ⌘⇧M")
                    .font(.caption2)
                    .foregroundColor(.gray)
            } header: { 
                Text("Global Shortcut Configuration").padding(.top)
            }
            .padding(.bottom)

            Section {
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
                    "Max Auto-Interventions Per Instance: \(maxInterventionsBeforePause)",
                    value: $maxInterventionsBeforePause,
                    in: 1...25
                )
                Toggle("Play Sound on Intervention", isOn: $playSoundOnIntervention)

                VStack(alignment: .leading) {
                    Text("Text for 'Cursor Stops' Recovery (when CodeLooper nudges Cursor):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $textForCursorStopsRecovery)
                        .frame(height: 60)
                }
            } header: { 
                Text("Supervision Core Settings").padding(.top)
            }
            .padding(.bottom)

            Section {
                VStack(alignment: .leading) {
                    Toggle("Automatically Check for Updates", isOn: $automaticallyCheckForUpdates)
                    Button("Check for Updates Now") {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.checkForUpdates(nil)
                        } else {
                            print("Error: Could not get AppDelegate to check for updates.")
                        }
                    }
                    .disabled(updaterViewModel.isUpdateInProgress)
                }
            } header: { 
                Text("Updates").padding(.top)
            }
            .padding(.bottom)

            Section {
                Button("Reset Welcome Guide") {
                    Defaults[.hasShownWelcomeGuide] = false
                    // Similar to above, this relies on AppDelegate.
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.windowManager?.showWelcomeWindow()
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
            } header: { Text("Troubleshooting & Reset") 
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
        // Create a dummy LoginItemManager for the preview
        let dummyLoginItemManager = LoginItemManager.shared // Or a mock if available
        // Create a dummy SparkleUpdaterManager for the preview
        let dummySparkleUpdaterManager = SparkleUpdaterManager()
        // Create a dummy UpdaterViewModel for the preview
        let dummyUpdaterViewModel = UpdaterViewModel(sparkleUpdaterManager: dummySparkleUpdaterManager)

        GeneralSettingsView(updaterViewModel: dummyUpdaterViewModel) // Pass the dummy view model
            .environmentObject(dummyLoginItemManager) // If LoginItemManager is used as an EnvironmentObject elsewhere
            .frame(width: 450, height: 400)
    }
}
#endif 
