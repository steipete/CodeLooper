import AppKit
import Defaults
import SwiftUI

struct MainPopoverView: View {
    @StateObject private var cursorMonitor = CursorMonitor.shared
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CodeLooper Supervision")
                .font(.title2)
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
                // Replaced SettingsLink with Button
                Button("Open Settings") {
                    // Close popover first
                    AppDelegate.shared?.menuManager?.closePopover(sender: nil)
                    // Then open settings
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

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
        // Removed .listRowBackground(Color.clear) from VStack as it's not a List row
    }

    // InstanceRowView and related helper methods (statusIndicator, iconAndColor, friendlyStatusDescription)
    // are now OBSOLETE in this file if we are simplifying to just show window titles of a single app.
    // They can be removed or refactored if a more detailed per-window view is desired later.
    // For now, I will comment them out to avoid build errors and to indicate they need revisiting.
    /*
    private var headerView: some View {
        HStack {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .padding(.trailing, 4)

            Text("CodeLooper")
                .font(.title2)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("Monitor", isOn: $isGlobalMonitoringEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .onChange(of: isGlobalMonitoringEnabled) { _, newValue in
                    if newValue {
                        cursorMonitor.startMonitoringLoop()
                    } else {
                        cursorMonitor.stopMonitoringLoop()
                    }
                }
        }
    }

    private var instanceListView: some View {
        Group {
            if cursorMonitor.monitoredInstances.isEmpty {
                VStack {
                    Spacer()
                    Text("No running Cursor instances detected.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Launch Cursor to begin monitoring.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(cursorMonitor.monitoredInstances) { info in
                            instanceRow(info: info)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func instanceRow(info: MonitoredInstanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIndicator(for: info.status, isActive: info.isActivelyMonitored)
                
                Image(systemName: "app.badge")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)

                Text(info.displayName)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                Text(friendlyStatusDescription(for: info.status))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if info.interventionCount > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(info.interventionCount) intervention\(info.interventionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                Spacer()

                Button {
                    if info.status == .pausedManually {
                        cursorMonitor.resumeMonitoring(for: info.pid)
                    } else {
                        cursorMonitor.pauseMonitoring(for: info.pid)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: info.status == .pausedManually ? "play.fill" : "pause.fill")
                            .font(.caption)
                        Text(info.status == .pausedManually ? "Resume" : "Pause")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(info.status == .notRunning)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func statusIndicator(for status: DisplayStatus, isActive: Bool) -> some View {
        let (iconName, color) = iconAndColor(for: status, isActive: isActive)
        Image(systemName: iconName)
            .foregroundColor(color)
            .font(.title3)
            .frame(width: 24, alignment: .center)
    }

    private func iconAndColor(for status: DisplayStatus, isActive: Bool) -> (String, Color) {
        switch status {
        case .unknown:
            return ("questionmark.circle.fill", .gray)
        case .active:
            return isActive ? ("circle.fill", .blue) : ("circle", .gray)
        case .positiveWork:
            return ("checkmark.circle.fill", .green)
        case .intervening:
            return ("hand.raised.circle.fill", .orange)
        case .observation:
            return ("eye.circle.fill", .orange)
        case .pausedManually:
            return ("pause.circle.fill", .yellow)
        case .pausedInterventionLimit:
            return ("exclamationmark.circle.fill", .yellow)
        case .pausedUnrecoverable:
            return ("xmark.circle.fill", .red)
        case .idle:
            return ("moon.zzz.fill", .gray)
        case .notRunning:
            return ("xmark.octagon.fill", .red)
        }
    }

    private func friendlyStatusDescription(for status: DisplayStatus) -> String {
        switch status {
        case .positiveWork:
            return "Working ✅"
        case .intervening:
            return "Recovering (Intervention) 🛠️"
        case .observation:
            return "Observing Post-Intervention 👀"
        case .pausedManually:
            return "Paused (Manual) ⏸️"
        case .pausedInterventionLimit:
            return "Paused (Limit Reached) 🚫"
        case .pausedUnrecoverable:
            return "Error (Unrecoverable) 🆘"
        case .idle:
            return "Idle (Monitoring) ☕"
        case .active:
            return "Active (Monitoring) 🔍"
        case .unknown:
            return "Status Unknown 🤔"
        case .notRunning:
            return "Not Running ⏹️"
        }
    }
    */
}

// InstanceRowView struct is also likely obsolete or needs major refactor for windows.
// Commenting out for now.
/*
struct InstanceRowView: View {
    let instance: MonitoredInstanceInfo
    let cursorMonitor: CursorMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIndicator(for: instance.status, isActive: instance.isActivelyMonitored)
                
                Image(systemName: "app.badge")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)

                Text(instance.displayName)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                Text(friendlyStatusDescription(for: instance.status))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if instance.interventionCount > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(instance.interventionCount) intervention\(instance.interventionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                Spacer()

                Button {
                    if instance.status == .pausedManually {
                        cursorMonitor.resumeMonitoring(for: instance.pid)
                    } else {
                        cursorMonitor.pauseMonitoring(for: instance.pid)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: instance.status == .pausedManually ? "play.fill" : "pause.fill")
                            .font(.caption)
                        Text(instance.status == .pausedManually ? "Resume" : "Pause")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(instance.status == .notRunning)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func statusIndicator(for status: DisplayStatus, isActive: Bool) -> some View {
        let (iconName, color) = iconAndColor(for: status, isActive: isActive)
        Image(systemName: iconName)
            .foregroundColor(color)
            .font(.title3)
            .frame(width: 24, alignment: .center)
    }

    private func iconAndColor(for status: DisplayStatus, isActive: Bool) -> (String, Color) {
        switch status {
        case .unknown:
            return ("questionmark.circle.fill", .gray)
        case .active:
            return isActive ? ("circle.fill", .blue) : ("circle", .gray)
        case .positiveWork:
            return ("checkmark.circle.fill", .green)
        case .intervening:
            return ("hand.raised.circle.fill", .orange)
        case .observation:
            return ("eye.circle.fill", .orange)
        case .pausedManually:
            return ("pause.circle.fill", .yellow)
        case .pausedInterventionLimit:
            return ("exclamationmark.circle.fill", .yellow)
        case .pausedUnrecoverable:
            return ("xmark.circle.fill", .red)
        case .idle:
            return ("moon.zzz.fill", .gray)
        case .notRunning:
            return ("xmark.octagon.fill", .red)
        }
    }

    private func friendlyStatusDescription(for status: DisplayStatus) -> String {
        switch status {
        case .positiveWork:
            return "Working ✅"
        case .intervening:
            return "Recovering (Intervention) 🛠️"
        case .observation:
            return "Observing Post-Intervention 👀"
        case .pausedManually:
            return "Paused (Manual) ⏸️"
        case .pausedInterventionLimit:
            return "Paused (Limit Reached) 🚫"
        case .pausedUnrecoverable:
            return "Error (Unrecoverable) 🆘"
        case .idle:
            return "Idle (Monitoring) ☕"
        case .active:
            return "Active (Monitoring) 🔍"
        case .unknown:
            return "Status Unknown 🤔"
        case .notRunning:
            return "Not Running ⏹️"
        }
    }
}
*/

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
