import AXorcist
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct CursorSupervisionSettingsView: View {
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.postInterventionObservationWindowSeconds)
    var postInterventionObservationWindowSeconds
    @Default(.stuckDetectionTimeoutSeconds)
    var stuckDetectionTimeoutSeconds
    @Default(.sendNotificationOnPersistentError)
    var sendNotificationOnPersistentError
    @Default(.maxConnectionIssueRetries)
    var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures)
    var maxConsecutiveRecoveryFailures
    @Default(.aiGlobalAnalysisIntervalSeconds)
    var aiGlobalAnalysisIntervalSeconds
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled

    @StateObject private var inputWatcherViewModel = CursorInputWatcherViewModel()
    @StateObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared

    @ViewBuilder
    private var cursorWindowsView: some View {
        if !inputWatcherViewModel.cursorWindows.isEmpty {
            DSDivider()
                .padding(.vertical, Spacing.small)

            CursorWindowsList(style: .settings)
        }
    }
    

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // Input Watcher Section
            DSSettingsSection("Input Monitoring & AI Diagnostics") {
                DSToggle(
                    "Enable Cursor Supervision",
                    isOn: $isGlobalMonitoringEnabled,
                    description: "Master switch to enable/disable all CodeLooper supervision features for Cursor, including JS hooks and AI diagnostics."
                )
                .onChange(of: isGlobalMonitoringEnabled) { oldValue, newValue in
                    if newValue {
                        diagnosticsManager.enableLiveWatchingForAllWindows()
                    } else {
                        diagnosticsManager.disableLiveWatchingForAllWindows()
                    }
                }

                if !inputWatcherViewModel.statusMessage.isEmpty && isGlobalMonitoringEnabled {
                    Text(inputWatcherViewModel.statusMessage)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.top, Spacing.xxSmall)
                }

                cursorWindowsView
                
                // Manual AI Analysis Section (CursorAnalysisView)
                // This can remain as is for now, or be re-evaluated later.
                if inputWatcherViewModel.isWatchingEnabled && !inputWatcherViewModel.cursorWindows.isEmpty {
                    DSDivider()
                        .padding(.vertical, Spacing.small)
                    Text("Global AI Analysis Interval")
                        .font(Typography.callout(.semibold))
                    DSSlider(
                        value: Binding(
                            get: { Double(aiGlobalAnalysisIntervalSeconds) },
                            set: { aiGlobalAnalysisIntervalSeconds = Int($0) }
                        ),
                        in: 5...60, 
                        step: 5,
                        label: "Interval",
                        showValue: true
                    ) { "\(Int($0))s" }
                    .padding(.top, Spacing.xxSmall)
                    
                    DSDivider()
                        .padding(.vertical, Spacing.small)
                    Text("Manual AI Window Analysis")
                        .font(Typography.callout(.semibold))
                    CursorAnalysisView()
                        .padding(.top, Spacing.small)
                }
            }
            // Detection Settings
            DSSettingsSection("Detection") {
                DSToggle(
                    "Monitor Sidebar Activity",
                    isOn: $monitorSidebarActivity,
                    description: "Track activity in Cursor's sidebar to detect stuck states"
                )

                DSDivider()

                DSSlider(
                    value: $stuckDetectionTimeoutSeconds,
                    in: 5 ... 60,
                    step: 5,
                    label: "Stuck Detection Timeout",
                    showValue: true
                ) { "\(Int($0))s" }

                DSDivider()

                DSSlider(
                    value: $postInterventionObservationWindowSeconds,
                    in: 1 ... 10,
                    step: 1,
                    label: "Post-Intervention Observation",
                    showValue: true
                ) { "\(Int($0))s" }
            }

            // Recovery Settings
            DSSettingsSection("Recovery") {
                HStack {
                    Text("Max Connection Retries")
                        .font(Typography.body())
                    Spacer()
                    Stepper(
                        "\(maxConnectionIssueRetries)",
                        value: $maxConnectionIssueRetries,
                        in: 1 ... 10
                    )
                    .labelsHidden()
                    .fixedSize()
                }

                DSDivider()

                HStack {
                    Text("Max Consecutive Recovery Failures")
                        .font(Typography.body())
                    Spacer()
                    Stepper(
                        "\(maxConsecutiveRecoveryFailures)",
                        value: $maxConsecutiveRecoveryFailures,
                        in: 1 ... 10
                    )
                    .labelsHidden()
                    .fixedSize()
                }
            }

            // Notifications
            DSSettingsSection("Notifications") {
                DSToggle(
                    "Send Notification on Persistent Errors",
                    isOn: $sendNotificationOnPersistentError,
                    description: "Get notified when Cursor encounters repeated connection issues"
                )
            }


            Spacer()
        }
    }
    
}

// MARK: - Preview

#if DEBUG
    struct CursorSupervisionSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            CursorSupervisionSettingsView()
                .frame(width: 550, height: 700)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
