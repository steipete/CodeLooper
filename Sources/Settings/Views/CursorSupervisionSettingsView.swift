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

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Active Cursor Windows")
                    .font(Typography.callout(.semibold))
                    .foregroundColor(ColorPalette.text)

                ForEach(inputWatcherViewModel.cursorWindows) { window in
                    windowItemView(window: window)
                }
            }
        }
    }
    
    @ViewBuilder
    private func windowItemView(window: MonitoredWindowInfo) -> some View {
        let windowAIState = diagnosticsManager.windowStates[window.id]
        
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                Image(systemName: "window.ceiling")
                    .foregroundColor(ColorPalette.textSecondary)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading) {
                    Text(window.windowTitle ?? "Untitled Window")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    if let docPath = window.documentPath, !docPath.isEmpty {
                        Text(docPath)
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                jsHookStatusView(for: window)
            }
            
            aiDiagnosticsRow(windowAIState: windowAIState, window: window)
            
            if windowAIState?.isLiveWatchingEnabled ?? false {
                aiAnalysisDetails(windowAIState: windowAIState)
            }
        }
        .padding(Spacing.small)
        .background(ColorPalette.backgroundSecondary)
        .cornerRadiusDS(Layout.CornerRadius.small)
        .opacity(isGlobalMonitoringEnabled ? 1.0 : 0.5)
        .disabled(!isGlobalMonitoringEnabled)
        .contentShape(Rectangle())
        .onTapGesture {
            let logger = Logger(category: .settings)
            logger.info("Tapped on settings window item: \(window.windowTitle ?? window.id). Attempting to raise.")
            if let axElement = window.windowAXElement {
                if axElement.performAction(.raise) {
                    logger.info("Successfully performed raise action for settings window: \(window.windowTitle ?? window.id)")
                } else {
                    logger.warning("Failed to perform raise action for settings window: \(window.windowTitle ?? window.id)")
                }
            } else {
                logger.warning("Cannot raise settings window: AXElement is nil for \(window.windowTitle ?? window.id)")
            }
        }
    }
    
    @ViewBuilder
    private func aiDiagnosticsRow(windowAIState: MonitoredWindowInfo?, window: MonitoredWindowInfo) -> some View {
        HStack {
            Spacer().frame(width: 20)
            aiStatusIndicator(status: windowAIState?.lastAIAnalysisStatus ?? .off)
            
            Toggle("", isOn: Binding(
                get: { windowAIState?.isLiveWatchingEnabled ?? false },
                set: { _ in diagnosticsManager.toggleLiveWatching(for: window.id) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: ColorPalette.primary))
            .scaleEffect(0.8)
            
            Text("Live AI Analysis")
                .font(Typography.caption1())
            
            Spacer()
        }
        .disabled(!isGlobalMonitoringEnabled || !inputWatcherViewModel.isWatchingEnabled)
    }
    
    @ViewBuilder
    private func aiAnalysisDetails(windowAIState: MonitoredWindowInfo?) -> some View {
        if let analysisMessage = windowAIState?.lastAIAnalysisResponseMessage, !analysisMessage.isEmpty {
            Text("    AI: \(analysisMessage)")
                .font(Typography.caption2())
                .foregroundColor(windowAIState?.lastAIAnalysisStatus == .error ? ColorPalette.error : ColorPalette.warning)
                .padding(.leading, 20)
        }
        if let timestamp = windowAIState?.lastAIAnalysisTimestamp {
            Text("    Last check: \(timestamp, style: .time)")
                .font(.caption2)
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.leading, 20)
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
    
    // Extracted ViewBuilder for JS Hook Status
    @ViewBuilder
    private func jsHookStatusView(for window: MonitoredWindowInfo) -> some View {
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
                if heartbeatStatus?.isAlive == true {
                    Image(systemName: "heart.fill")
                        .foregroundColor(ColorPalette.success)
                        .font(.system(size: 10))
                }
            }
            .help("JS Hook \(heartbeatStatus?.isAlive == true ? "active" : "installed") on port \(inputWatcherViewModel.getPort(for: window.id) ?? 0)")
        }

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
    }
    
    // Helper function to get color for status
    private func colorForStatus(_ status: AIAnalysisStatus) -> Color {
        switch status {
        case .working: 
            return ColorPalette.success
        case .notWorking: 
            return ColorPalette.error
        case .pending: 
            return ColorPalette.info
        case .error: 
            return ColorPalette.error
        case .off: 
            return ColorPalette.textTertiary
        case .unknown:
            return ColorPalette.warning
        }
    }
    
    // Extracted ViewBuilder for AI Status Indicator (similar to MainPopoverView)
    @ViewBuilder
    private func aiStatusIndicator(status: AIAnalysisStatus) -> some View {
        Image(systemName: "circle.fill")
            .font(.caption)
            .foregroundColor(colorForStatus(status))
            .help(status.displayName)
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
