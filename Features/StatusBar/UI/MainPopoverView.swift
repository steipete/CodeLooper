import AppKit
import AXorcist
import Combine
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

/// The main popover view displayed when clicking the menu bar icon.
///
/// MainPopoverView provides:
/// - Quick status overview of monitoring state
/// - Toggle controls for supervision
/// - Monitored instance list with details
/// - Quick access to settings and actions
/// - Compact presentation optimized for popover
///
/// This view serves as the primary interface for quick interactions
/// without opening the full settings window.
struct MainPopoverView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Header with logo
            HStack(spacing: Spacing.small) {
                // App icon
                if let iconImage = NSImage(named: "loop-color") {
                    Image(nsImage: iconImage)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "link.circle.fill")
                        .font(.title2)
                        .foregroundColor(ColorPalette.loopTint)
                }

                Text("CodeLooper")
                    .font(Typography.title3(.medium))
                    .foregroundColor(ColorPalette.text)

                Spacer()
            }

            // Permissions section
            PermissionsView(showTitle: false, compact: true)

            // Enable supervision toggle
            DSToggle(
                "Enable Cursor Supervision",
                isOn: $isGlobalMonitoringEnabled
            )
            .onChange(of: isGlobalMonitoringEnabled) { _, newValue in
                Task { @MainActor in
                    if newValue {
                        diagnosticsManager.enableLiveWatchingForAllWindows()
                    } else {
                        diagnosticsManager.disableLiveWatchingForAllWindows()
                    }
                }
            }

            DSDivider()

            // Monitoring status section
            if !cursorMonitor.monitoredApps.isEmpty {
                // Windows list without "Monitored:" label
                CursorWindowsList(style: .popover)
            } else {
                // Empty state
                DSCard(style: .filled) {
                    HStack {
                        Image(systemName: isGlobalMonitoringEnabled ? "exclamationmark.circle" : "pause.circle")
                            .font(.title3)
                            .foregroundColor(isGlobalMonitoringEnabled ? ColorPalette.warning : ColorPalette
                                .textSecondary)

                        Text(isGlobalMonitoringEnabled ? "No Cursor app detected." : "Cursor supervision is paused.")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }

            // Claude instances section (if enabled)
            if enableClaudeMonitoring {
                DSDivider()
                ClaudeInstancesList()
            }

            DSDivider()

            // Rule execution stats
            RuleExecutionStatsView()

            // Rule execution stats
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textTertiary)
                Text("Rule Executions: \(ruleCounter.totalRuleExecutions)")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            // Action buttons
            HStack {
                Button(action: {
                    MainSettingsCoordinator.shared.showSettings()
                }, label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(ColorPalette.textSecondary)
                })
                .buttonStyle(.plain)
                .help("Open Settings")

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorPalette.text)
            }
            .padding(.top, Spacing.xSmall)
        }
        .padding(Spacing.large)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.default, value: isGlobalMonitoringEnabled)
        .animation(.default, value: diagnosticsManager.windowStates.count)
    }

    // MARK: Private

    private static let logger = Logger(category: .statusBar)

    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @ObservedObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    @ObservedObject private var claudeMonitor = ClaudeMonitorService.shared
    @StateObject private var ruleCounter = RuleCounterManager.shared

    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.enableClaudeMonitoring) private var enableClaudeMonitoring
}

// MARK: - Preview

#if DEBUG
    struct MainPopoverView_Previews: PreviewProvider {
        static var previews: some View {
            let mockMonitor = CursorMonitor.shared
            let mockDiagnostics = WindowAIDiagnosticsManager.shared
            let mockInputWatcher = CursorInputWatcherViewModel()
            let appPID = pid_t(12345)

            let window1Id = "\(appPID)-window-Doc1-0"
            let window2Id = "\(appPID)-window-Settings-1"

            let windowInfo1 = MonitoredWindowInfo(
                id: window1Id,
                windowTitle: "Document 1.txt",
                documentPath: "/path/to/doc1.txt"
            )
            var windowInfo2 = MonitoredWindowInfo(
                id: window2Id,
                windowTitle: "Project Settings",
                documentPath: "/path/to/proj/"
            )
            windowInfo2.isLiveWatchingEnabled = true
            windowInfo2.lastAIAnalysisStatus = .working
            windowInfo2.aiAnalysisIntervalSeconds = 15
            windowInfo2.lastAIAnalysisTimestamp = Date().addingTimeInterval(-30)

            let mockApp = MonitoredAppInfo(
                id: appPID,
                pid: appPID,
                displayName: "Cursor (PID: 12345)",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 2,
                windows: [windowInfo1, windowInfo2]
            )

            mockDiagnostics.windowStates = [
                windowInfo1.id: windowInfo1,
                windowInfo2.id: windowInfo2,
            ]

            // Simulate some JS Hook state for preview
            mockInputWatcher.cursorWindows = [windowInfo1, windowInfo2]
            // Cannot directly access private jsHookManager in preview
            var hbStatus1 = HeartbeatStatus()
            hbStatus1.isAlive = true
            mockInputWatcher.windowHeartbeatStatus[window1Id] = hbStatus1

            return MainPopoverView()
                .environmentObject(mockMonitor)
                .environmentObject(mockDiagnostics)
                .environmentObject(mockInputWatcher)
                .onAppear {
                    mockMonitor.monitoredApps = [mockApp]
                }
        }
    }
#endif
