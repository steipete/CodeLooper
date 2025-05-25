import AppKit
import Defaults
import SwiftUI
import Combine // Added for PassthroughSubject

// Ensure SettingsService is accessible, you might need to ensure its module is imported
// if it's in a different one and not globally available via @testable or similar.
// For CodeLooper, SettingsService is in the Application module, which should be accessible.

struct MainPopoverView: View {
    @StateObject private var cursorMonitor = CursorMonitor.shared
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CodeLooper Supervision")
                .font(.title2)
                .padding(.bottom, 5)
            
            // Permissions section
            PermissionsView(showTitle: false, compact: true)
                .padding(.bottom, 5)

            Defaults.Toggle("Enable Cursor Supervision", key: .isGlobalMonitoringEnabled)

            Divider()

            // Display the single monitored Cursor app and its windows
            // Assuming only one Cursor app instance is primarily monitored or relevant for this popover.
            if let cursorApp = cursorMonitor.monitoredApps.first { // Get the first (and likely only) monitored Cursor app
                Text("Monitored: \(cursorApp.displayName)")
                    .font(.subheadline)
                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary) // Dim if not enabled
                
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
                                .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary) // Dim if not enabled
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
                            .disabled(!isGlobalMonitoringEnabled) // Disable if global supervision is off
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 50, maxHeight: 150) // Adjust size as needed
                }
            } else {
                if isGlobalMonitoringEnabled { // Only show "No Cursor app detected" if monitoring is actually on
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
                .simultaneousGesture(TapGesture().onEnded {
                })

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

}


// MARK: - Preview
#if DEBUG
struct MainPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data for preview
        let mockMonitor = CursorMonitor.sharedForPreview // Use shared preview instance
        
        // Example with a monitored app and windows
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
                MonitoredWindowInfo(id: "w3", windowTitle: nil, isPaused: false)
            ]
        )
        // mockMonitor.monitoredApps = [mockApp] // This can be uncommented if needed for preview state
        // mockMonitor.isMonitoringActivePublic = true // Ensure this line is commented or removed
        // mockMonitor.totalAutomaticInterventionsThisSessionDisplay = 5 // This can be uncommented

        // Example with no windows - This variable is unused, so it can be removed.
        // var mockAppNoWindows = MonitoredAppInfo(
        //     id: pid_t(54321),
        //     pid: pid_t(54321),
        //     displayName: "OtherApp (PID: 54321)",
        //     status: .active, 
        //     isActivelyMonitored: false, 
        //     interventionCount: 0,
        //     windows: []
        // )

        return MainPopoverView()
            .environmentObject(mockMonitor) // Inject the mock monitor
            .onAppear {
                // Further simulate state for preview if needed
                 mockMonitor.monitoredApps = [mockApp]
                 // mockMonitor.isMonitoringActivePublic = true // Ensure this line is commented or removed
                 // mockMonitor.totalAutomaticInterventionsThisSessionDisplay = 5 // This can be uncommented
            }
    }
}
#endif 
