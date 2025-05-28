import AppKit
import Combine
import Defaults
import SwiftUI

struct MainPopoverView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CodeLooper Supervision")
                .font(.title2)
                .padding(.bottom, 5)

            PermissionsView(showTitle: false, compact: true)
                .padding(.bottom, 5)

            Defaults.Toggle("Enable Cursor Supervision", key: .isGlobalMonitoringEnabled)

            Divider()

            if let cursorApp = cursorMonitor.monitoredApps.first {
                Text("Monitored: \(cursorApp.displayName)")
                    .font(.subheadline)
                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)

                if !isGlobalMonitoringEnabled {
                    Text("  (Supervision Paused)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading)
                }

                // Use windowStates from diagnosticsManager, which includes AI analysis status
                let windowStatesArray = diagnosticsManager.windowStates.values.filter { ws in
                    // Ensure we only show windows belonging to the currently monitored cursorApp PID
                    cursorApp.windows.contains(where: { $0.id == ws.id })
                }.sorted(by: { ($0.windowTitle ?? "Z") < ($1.windowTitle ?? "Z") })

                if windowStatesArray.isEmpty {
                    Text("  No windows detected or ready for AI diagnostics.")
                        .foregroundColor(.secondary)
                        .padding(.leading)
                } else {
                    List(windowStatesArray) { windowState in // Iterate over windowStates
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                aiStatusIndicator(status: windowState.lastAIAnalysisStatus)
                                Text(windowState.windowTitle ?? "Untitled Window")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)
                                Spacer()
                                jsHookStatusView(for: windowState.id)
                            }
                            if let docPath = windowState.documentPath, !docPath.isEmpty {
                                Text("    \(docPath)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            if windowState.lastAIAnalysisStatus != .off {
                                if let message = windowState.lastAIAnalysisResponseMessage, !message.isEmpty {
                                    Text("    AI: \(message)")
                                        .font(.caption)
                                        .foregroundColor(windowState.lastAIAnalysisStatus == .error ? .red : .orange)
                                }
                                if let timestamp = windowState.lastAIAnalysisTimestamp {
                                    Text("    Last check: \(timestamp, style: .time)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Toggle("Live Analysis", isOn: Binding(
                                    get: { diagnosticsManager.windowStates[windowState.id]?.isLiveWatchingEnabled ?? false },
                                    set: { _ in diagnosticsManager.toggleLiveWatching(for: windowState.id) }
                                ))
                                .disabled(!isGlobalMonitoringEnabled)
                                .scaleEffect(0.9)
                                .frame(maxWidth: 140)
                                
                                if diagnosticsManager.windowStates[windowState.id]?.isLiveWatchingEnabled ?? false {
                                    Stepper("Interval: \(diagnosticsManager.windowStates[windowState.id]?.aiAnalysisIntervalSeconds ?? 10)s",
                                            value: Binding(
                                                get: { diagnosticsManager.windowStates[windowState.id]?.aiAnalysisIntervalSeconds ?? 10 },
                                                set: { newInterval in diagnosticsManager.setAnalysisInterval(for: windowState.id, interval: newInterval) }
                                            ),
                                            in: 5...60, step: 5)
                                        .font(.caption)
                                        .disabled(!isGlobalMonitoringEnabled)
                                        .scaleEffect(0.9)
                                }
                            }
                            .padding(.leading, 20)
                            
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 100, maxHeight: 250) // Adjusted height
                }
            } else {
                if isGlobalMonitoringEnabled {
                    Text("No Cursor app detected.")
                        .foregroundColor(.secondary)
                } else {
                    Text("Cursor supervision is paused.")
                        .foregroundColor(.secondary)
                }
            }

            Divider()
            Text("Session Interventions: \(cursorMonitor.totalAutomaticInterventionsThisSessionDisplay)")
                .font(.caption)

            HStack {
                SettingsLink {
                    Text("Open Settings")
                }
                .tint(.accentColor)
                .simultaneousGesture(TapGesture().onEnded {})

                Button("Reset All Counters") {
                    Task { await CursorMonitor.shared.resetAllInstancesAndResume() }
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .frame(width: 480, height: 550) // Increased popover size
    }

    // MARK: Private

    @StateObject private var cursorMonitor = CursorMonitor.shared
    @StateObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    @StateObject private var inputWatcherViewModel = CursorInputWatcherViewModel()
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled

    private func aiStatusColor(_ status: AIAnalysisStatus) -> Color {
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

    @ViewBuilder
    private func aiStatusIndicator(status: AIAnalysisStatus) -> some View {
        Image(systemName: "circle.fill")
            .font(.caption)
            .foregroundColor(aiStatusColor(status))
            .help(status.displayName)
    }

    @ViewBuilder
    private func jsHookStatusView(for windowId: String) -> some View {
        let heartbeatStatus = inputWatcherViewModel.getHeartbeatStatus(for: windowId)
        let port = inputWatcherViewModel.getPort(for: windowId)
        let isHookActive = heartbeatStatus?.isAlive == true || port != nil

        if isHookActive {
            HStack(spacing: 3) {
                if let port = port {
                    Text(":\(port)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Image(systemName: heartbeatStatus?.isAlive == true ? "heart.fill" : "heart.slash.fill")
                    .font(.caption)
                    .foregroundColor(heartbeatStatus?.isAlive == true ? .green : .orange)
                    .help(heartbeatStatus?.isAlive == true ? "JS Hook Active (Port: \(port ?? 0))" : "JS Hook Inactive/No Heartbeat (Port: \(port ?? 0))")
            }
        } else {
            EmptyView()
        }
    }
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

            var windowInfo1 = MonitoredWindowInfo(id: window1Id, windowTitle: "Document 1.txt", documentPath: "/path/to/doc1.txt")
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
