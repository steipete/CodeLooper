import AppKit
import AXorcist
import Combine
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct MainPopoverView: View {
    // MARK: Internal
    
    private static let logger = Logger(category: .statusBar)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Header
            Text("CodeLooper Supervision")
                .font(Typography.title3())
                .foregroundColor(ColorPalette.text)

            // Permissions section
            PermissionsView(showTitle: false, compact: true)

            // Enable supervision toggle
            DSToggle(
                "Enable Cursor Supervision",
                isOn: $isGlobalMonitoringEnabled
            )
            .onChange(of: isGlobalMonitoringEnabled) { oldValue, newValue in
                if newValue {
                    diagnosticsManager.enableLiveWatchingForAllWindows()
                } else {
                    diagnosticsManager.disableLiveWatchingForAllWindows()
                }
            }

            DSDivider()

            // Monitoring status section
            if let cursorApp = cursorMonitor.monitoredApps.first {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack {
                        Text("Monitored:")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                        Text(cursorApp.displayName)
                            .font(Typography.body(.medium))
                            .foregroundColor(isGlobalMonitoringEnabled ? ColorPalette.text : ColorPalette.textSecondary)
                    }

                }

                // Windows list
                CursorWindowsList(style: .popover)
                    .padding(.top, Spacing.small)
            } else {
                // Empty state
                DSCard(style: .filled) {
                    HStack {
                        Image(systemName: isGlobalMonitoringEnabled ? "exclamationmark.circle" : "pause.circle")
                            .font(.title3)
                            .foregroundColor(isGlobalMonitoringEnabled ? ColorPalette.warning : ColorPalette.textSecondary)
                        
                        Text(isGlobalMonitoringEnabled ? "No Cursor app detected." : "Cursor supervision is paused.")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }

            DSDivider()
            
            // Session stats
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textTertiary)
                Text("Session Interventions: \(cursorMonitor.totalAutomaticInterventionsThisSessionDisplay)")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            // Action buttons
            HStack {
                DSButton(
                    "",
                    icon: Image(systemName: "gearshape.fill"),
                    style: .secondary
                ) {
                    NSApplication.shared.openSettings()
                }
                .help("Open Settings")
                
                Spacer()
                
                DSButton(
                    "Quit",
                    style: .tertiary
                ) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.top, Spacing.xSmall)
        }
        .padding(Spacing.large)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(ColorPalette.background)
        .animation(.default, value: isGlobalMonitoringEnabled)
        .animation(.default, value: diagnosticsManager.windowStates.count)
    }

    // MARK: Private

    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @ObservedObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
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

            let windowInfo1 = MonitoredWindowInfo(id: window1Id, windowTitle: "Document 1.txt", documentPath: "/path/to/doc1.txt")
            var windowInfo2 = MonitoredWindowInfo(id: window2Id, windowTitle: "Project Settings", documentPath: "/path/to/proj/")
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
                windowInfo2.id: windowInfo2
            ]
            
            // Simulate some JS Hook state for preview
            mockInputWatcher.cursorWindows = [windowInfo1, windowInfo2]
            mockInputWatcher.jsHookManager.windowPorts[window1Id] = 9001
            var hbStatus1 = CursorInputWatcherViewModel.HeartbeatStatus()
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
