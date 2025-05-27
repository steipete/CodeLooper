import Defaults
import DesignSystem
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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
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

            // Info Card
            DSCard(style: .filled) {
                HStack(spacing: Spacing.small) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorPalette.info)

                    VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                        Text("Supervision Strategy")
                            .font(Typography.callout(.semibold))
                        Text(
                            """
                            CodeLooper monitors Cursor instances and automatically recovers from \
                            common issues like connection drops and stuck states.
                            """
                        )
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    }

                    Spacer()
                }
            }
            .padding(.top, Spacing.medium)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct CursorSupervisionSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            CursorSupervisionSettingsView()
                .frame(width: 500, height: 600)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
