import AppKit
import Defaults
import DesignSystem
import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var mainSettingsViewModel: MainSettingsViewModel
    @Default(.automaticallyCheckForUpdates)
    var automaticallyCheckForUpdates
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled
    @Default(.showInDock)
    var showInDock
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
    var sendNotificationOnPersistentError
    @Default(.textForCursorStopsRecovery)
    var textForCursorStopsRecovery
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.postInterventionObservationWindowSeconds)
    var postInterventionObservationWindowSeconds
    @Default(.stuckDetectionTimeoutSeconds)
    var stuckDetectionTimeoutSeconds
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                // Accessibility Permissions
                DSSettingsSection("Permissions") {
                    PermissionsView(showTitle: false, compact: false)
                }

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
                            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                                Text("Toggle Monitoring")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.text)

                                Text("Define a global keyboard shortcut to quickly toggle monitoring")
                                    .font(Typography.caption1())
                                    .foregroundColor(ColorPalette.textSecondary)
                            }

                            Spacer()

                            KeyboardShortcuts.Recorder(for: .toggleMonitoring)
                                .fixedSize()
                        }

                        Text("Use standard symbols: ⌘ (Command), ⌥ (Option/Alt), ⇧ (Shift), ⌃ (Control)")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textTertiary)
                    }
                }

                // Supervision Core Settings
                DSSettingsSection("Monitoring") {
                    DSToggle(
                        "Enable Global Monitoring",
                        isOn: $isGlobalMonitoringEnabled,
                        description: "Monitor Cursor instances across all applications"
                    )

                    DSDivider()

                    DSSlider(
                        value: $monitoringIntervalSeconds,
                        in: 0.5 ... 5.0,
                        step: 0.5,
                        label: "Monitoring Interval",
                        showValue: true
                    ) { String(format: "%.1fs", $0) }

                    DSDivider()

                    HStack {
                        Text("Max Auto-Interventions Per Instance")
                            .font(Typography.body())
                        Spacer()
                        Stepper(
                            "\(maxInterventionsBeforePause)",
                            value: $maxInterventionsBeforePause,
                            in: 1 ... 25
                        )
                        .labelsHidden()
                        .fixedSize()
                    }

                    DSDivider()

                    DSToggle(
                        "Play Sound on Intervention",
                        isOn: $playSoundOnIntervention
                    )

                    DSDivider()

                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("Recovery Text")
                            .font(Typography.body(.medium))
                        Text("Text sent when CodeLooper nudges Cursor to recover")
                            .textStyle(TextStyles.captionLarge)

                        TextEditor(text: $textForCursorStopsRecovery)
                            .font(Typography.monospaced(.small))
                            .frame(height: 80)
                            .cornerRadiusDS(Layout.CornerRadius.medium)
                            .borderDS(ColorPalette.border)
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

                // Troubleshooting & Reset
                DSSettingsSection("Troubleshooting") {
                    DSButton("Reset Welcome Guide", style: .tertiary) {
                        Defaults[.hasShownWelcomeGuide] = false
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.windowManager?.showWelcomeWindow()
                        }
                    }

                    DSDivider()

                    DSButton("Reset All Settings to Default", style: .destructive) {
                        resetAllSettings()
                    }
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
            .padding(Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    private func resetAllSettings() {
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
