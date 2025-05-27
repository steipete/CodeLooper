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

    @StateObject private var inputWatcherViewModel = CursorInputWatcherViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // Input Watcher Section
            DSSettingsSection("Input Monitoring") {
                DSToggle(
                    "Enable Live Watching",
                    isOn: $inputWatcherViewModel.isWatchingEnabled,
                    description: "Monitor and inject JavaScript hooks into Cursor windows"
                )

                if !inputWatcherViewModel.statusMessage.isEmpty {
                    Text(inputWatcherViewModel.statusMessage)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.top, Spacing.xxSmall)
                }

                // Display Cursor Windows
                if !inputWatcherViewModel.cursorWindows.isEmpty {
                    DSDivider()
                        .padding(.vertical, Spacing.small)

                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Active Cursor Windows")
                            .font(Typography.callout(.semibold))
                            .foregroundColor(ColorPalette.text)

                        ForEach(inputWatcherViewModel.cursorWindows) { window in
                            HStack {
                                Image(systemName: "window.ceiling")
                                    .foregroundColor(ColorPalette.textSecondary)
                                    .font(.system(size: 14))
                                
                                Text(window.windowTitle ?? "Untitled Window")
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                
                                Spacer()

                                // JS Hook status indicator
                                let heartbeatStatus = inputWatcherViewModel.getHeartbeatStatus(for: window.id)
                                let hasActiveHook = heartbeatStatus?.isAlive == true || inputWatcherViewModel.getPort(for: window.id) != nil
                                
                                if hasActiveHook {
                                    HStack(spacing: 4) {
                                        Image(systemName: heartbeatStatus?.isAlive == true ? "checkmark.seal.fill" : "checkmark.seal")
                                            .foregroundColor(heartbeatStatus?.isAlive == true ? ColorPalette.success : ColorPalette.warning)
                                            .font(.system(size: 12))
                                        if let port = inputWatcherViewModel.getPort(for: window.id) {
                                            Text(":\(port)")
                                                .font(Typography.caption2())
                                                .foregroundColor(ColorPalette.textSecondary)
                                        }
                                        
                                        // Show heartbeat indicator
                                        if heartbeatStatus?.isAlive == true {
                                            Image(systemName: "heart.fill")
                                                .foregroundColor(ColorPalette.success)
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .help("JS Hook \(heartbeatStatus?.isAlive == true ? "active" : "installed") on port \(inputWatcherViewModel.getPort(for: window.id) ?? 0)")
                                }

                                // Inject/Reinject button
                                DSButton(
                                    hasActiveHook ? "Reinject" : "Inject JS",
                                    style: .secondary,
                                    size: .small
                                ) {
                                    Task {
                                        await inputWatcherViewModel.injectJSHook(into: window)
                                    }
                                }
                                .disabled(inputWatcherViewModel.isInjectingHook)

                                if window.isPaused {
                                    Image(systemName: "pause.circle.fill")
                                        .foregroundColor(ColorPalette.warning)
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, Spacing.small)
                            .padding(.vertical, Spacing.xSmall)
                            .background(ColorPalette.backgroundSecondary)
                            .cornerRadiusDS(Layout.CornerRadius.small)
                        }
                    }
                }
                
                // AI Analysis Section
                if inputWatcherViewModel.isWatchingEnabled && !inputWatcherViewModel.cursorWindows.isEmpty {
                    DSDivider()
                        .padding(.vertical, Spacing.small)
                    
                    Text("AI Window Analysis")
                        .font(Typography.callout(.semibold))
                        .foregroundColor(ColorPalette.text)
                    
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
                .frame(width: 500, height: 600)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
