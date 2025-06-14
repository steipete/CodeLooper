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
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header section
            VStack(alignment: .leading, spacing: Spacing.small) {
                // Header with logo and counters
                HStack(spacing: Spacing.small) {
                    // App icon
                    if let iconImage = NSImage(named: "loop-color") {
                        Image(nsImage: iconImage)
                            .resizable()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "link.circle.fill")
                            .font(.body)
                            .foregroundColor(ColorPalette.loopTint)
                    }

                    Text("CodeLooper")
                        .font(Typography.callout(.medium))
                        .foregroundColor(ColorPalette.text)

                    Spacer()
                    
                    // Elegant status indicators
                    StatusIndicators(runningCount: runningCount, notRunningCount: notRunningCount)
                        .help("Active: \(runningCount) instance\(runningCount == 1 ? "" : "s") generating\nIdle: \(notRunningCount) instance\(notRunningCount == 1 ? "" : "s") waiting")
                }

                // Permissions section (if needed)
                PermissionsView(showTitle: false, compact: true)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.medium)
            .padding(.bottom, Spacing.small)
            
            DSDivider()
                .padding(.horizontal, Spacing.medium)

            // Scrollable content section
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    // Show content only when monitoring is enabled
                    if isGlobalMonitoringEnabled {
                        // Cursor windows section
                        if !cursorMonitor.monitoredApps.isEmpty || !cursorWindowStates.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                HStack(spacing: Spacing.xSmall) {
                                    Text("Cursor Windows")
                                        .font(Typography.caption1(.semibold))
                                        .foregroundColor(ColorPalette.textSecondary)
                                    
                                    Text("(\(cursorWindowStates.count))")
                                        .font(Typography.caption1())
                                        .foregroundColor(ColorPalette.textTertiary)
                                }
                                .padding(.horizontal, Spacing.medium)
                                .padding(.top, Spacing.xSmall)
                                
                                CursorWindowsList(style: .popover)
                                    .padding(.horizontal, Spacing.small)
                            }
                        } else {
                            // Empty state for Cursor
                            DSCard(style: .filled) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.caption)
                                        .foregroundColor(ColorPalette.warning)

                                    Text("No Cursor windows detected.")
                                        .font(Typography.caption1())
                                        .foregroundColor(ColorPalette.textSecondary)
                                }
                            }
                            .padding(.horizontal, Spacing.medium)
                            .padding(.vertical, Spacing.xSmall)
                        }

                        // Claude instances section (if enabled)
                        if enableClaudeMonitoring {
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                HStack(spacing: Spacing.xSmall) {
                                    Text("Claude Instances")
                                        .font(Typography.caption1(.semibold))
                                        .foregroundColor(ColorPalette.textSecondary)
                                    
                                    Text("(\(claudeMonitor.instances.count))")
                                        .font(Typography.caption1())
                                        .foregroundColor(ColorPalette.textTertiary)
                                }
                                .padding(.horizontal, Spacing.medium)
                                .padding(.top, Spacing.small)
                                
                                ClaudeInstancesList()
                                    .padding(.horizontal, Spacing.small)
                            }
                        }
                    } else {
                        // Monitoring disabled state
                        VStack(spacing: Spacing.medium) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 40))
                                .foregroundColor(ColorPalette.textTertiary)
                            
                            Text("Supervision Disabled")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            Text("Click the eye icon below to enable monitoring")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xLarge)
                    }
                }
                .padding(.bottom, Spacing.small)
            }
            .frame(minHeight: 100) // Dynamic height that expands as needed

            // Fixed footer section
            VStack(spacing: 0) {
                DSDivider()
                    .padding(.horizontal, Spacing.medium)
                
                // Action buttons
                HStack {
                    Button(action: {
                        MainSettingsCoordinator.shared.showSettings()
                    }, label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(ColorPalette.textSecondary)
                    })
                    .buttonStyle(.plain)
                    .help("Open Settings")

                    Spacer()
                    
                    // Supervision toggle button (eye icon)
                    Button(action: {
                        isGlobalMonitoringEnabled.toggle()
                        Task { @MainActor in
                            if isGlobalMonitoringEnabled {
                                diagnosticsManager.enableLiveWatchingForAllWindows()
                            } else {
                                diagnosticsManager.disableLiveWatchingForAllWindows()
                            }
                        }
                    }, label: {
                        Image(systemName: isGlobalMonitoringEnabled ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isGlobalMonitoringEnabled ? ColorPalette.loopTint : ColorPalette.textSecondary)
                    })
                    .buttonStyle(.plain)
                    .help(isGlobalMonitoringEnabled ? "Disable Supervision" : "Enable Supervision")

                    Spacer()

                    Button(action: {
                        NSApp.terminate(nil)
                    }, label: {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorPalette.error)
                    })
                    .buttonStyle(.plain)
                    .help("Quit CodeLooper (⌘Q)")
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
            }
        }
        .frame(width: 380) // Reduced width for more compact appearance
        .background(Material.ultraThinMaterial)
        .animation(.default, value: isGlobalMonitoringEnabled)
        .animation(.default, value: cursorWindowStates.count)
        .animation(.default, value: claudeMonitor.instances.count)
        .animation(.default, value: runningCount)
        .animation(.default, value: notRunningCount)
    }

    // MARK: Private

    private static let logger = Logger(category: .statusBar)

    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @ObservedObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    @ObservedObject private var claudeMonitor = ClaudeMonitorService.shared
    @StateObject private var ruleCounter = RuleCounterManager.shared

    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.enableClaudeMonitoring) private var enableClaudeMonitoring
    
    // Computed properties for counters
    private var cursorWindowStates: [MonitoredWindowInfo] {
        diagnosticsManager.windowStates.values.sorted { $0.id < $1.id }
    }
    
    private var runningCount: Int {
        var count = 0
        
        // Count Cursor windows that are "working" (generating)
        for windowState in cursorWindowStates {
            if windowState.lastAIAnalysisStatus == .working {
                count += 1
            }
        }
        
        // Count Claude instances that are active (not idle)
        if enableClaudeMonitoring {
            for instance in claudeMonitor.instances {
                if instance.currentActivity.type != .idle {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    private var notRunningCount: Int {
        var count = 0
        
        // Count Cursor windows that are "not working" or in error state
        for windowState in cursorWindowStates {
            if windowState.lastAIAnalysisStatus == .notWorking || 
               windowState.lastAIAnalysisStatus == .error {
                count += 1
            }
        }
        
        // Count Claude instances that are idle
        if enableClaudeMonitoring {
            for instance in claudeMonitor.instances {
                if instance.currentActivity.type == .idle {
                    count += 1
                }
            }
        }
        
        return count
    }
}

// Status indicators are now handled by the shared StatusIndicators component

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
