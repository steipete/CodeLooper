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

                if cursorApp.windows.isEmpty {
                    Text("  No windows detected for this app.")
                        .foregroundColor(.secondary)
                        .padding(.leading)
                } else {
                    List(cursorApp.windows) { window in
                        HStack {
                            Text("    \(window.windowTitle ?? "Untitled Window")")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)
                            Spacer()
                            Button {
                                if window.isPaused {
                                    cursorMonitor.resumeMonitoring(for: window.id, in: cursorApp.pid)
                                } else {
                                    cursorMonitor.pauseMonitoring(for: window.id, in: cursorApp.pid)
                                }
                            } label: {
                                Image(systemName: window.isPaused ? "play.circle" : "pause.circle")
                                    .foregroundColor(window.isPaused ? .green : .yellow)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isGlobalMonitoringEnabled)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 50, maxHeight: 150)
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
        .frame(width: 350) // Fixed width for the popover view
    }

    // MARK: Private

    @StateObject private var cursorMonitor = CursorMonitor.shared

    @Default(.isGlobalMonitoringEnabled)
    private var isGlobalMonitoringEnabled
}

// MARK: - Preview

#if DEBUG
    struct MainPopoverView_Previews: PreviewProvider {
        static var previews: some View {
            let mockMonitor = CursorMonitor.sharedForPreview
            let appPID = pid_t(12345)
            let mockApp = MonitoredAppInfo(
                id: appPID,
                pid: appPID,
                displayName: "Cursor (PID: 12345)",
                status: .active,
                isActivelyMonitored: true,
                interventionCount: 2,
                windows: [
                    MonitoredWindowInfo(id: "w1", windowTitle: "Document 1.txt", isPaused: false),
                    MonitoredWindowInfo(id: "w2", windowTitle: "Project Settings", isPaused: true),
                    MonitoredWindowInfo(id: "w3", windowTitle: nil, isPaused: false),
                ]
            )

            return MainPopoverView()
                .environmentObject(mockMonitor)
                .onAppear {
                    mockMonitor.monitoredApps = [mockApp]
                }
        }
    }
#endif
