import SwiftUI
import Defaults
import AppKit

struct MainPopoverView: View {
    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var mainSettingsViewModel: MainSettingsViewModel

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CodeLooper Supervision")
                .font(.headline)
                .padding(.bottom, 5)

            Toggle("Enable Cursor Supervision", isOn: $cursorMonitor.isMonitoringActive)
                .onChange(of: cursorMonitor.isMonitoringActive) { _, newValue in
                    if newValue {
                        cursorMonitor.startMonitoringLoop()
                    } else {
                        cursorMonitor.stopMonitoringLoop()
                    }
                }

            Divider()

            if cursorMonitor.monitoredInstances.isEmpty {
                Text("No Cursor instances detected.")
                    .foregroundColor(.secondary)
            } else {
                Text("Monitored Cursor Instances:")
                    .font(.subheadline)
                List {
                    ForEach(cursorMonitor.monitoredInstances) { instance in
                        InstanceRowView(instance: instance, cursorMonitor: cursorMonitor)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 200) // Limit height of the list
            }

            Divider()
            
            Text("Session Interventions: \(cursorMonitor.totalAutomaticInterventionsThisSessionDisplay)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Open Settings") {
                    appDelegate.mainSettingsCoordinator?.showSettings()
                    // Close popover after clicking
                    NSApp.deactivate()
                }
                Spacer()
                Button("Reset All Counters") {
                    Task {
                        await cursorMonitor.resetAllInstancesAndResume()
                    }
                    // Close popover after clicking
                    NSApp.deactivate()
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .frame(width: 350)
    }

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
}

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

// MARK: - Preview
#if DEBUG
struct MainPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        MainPopoverView()
            .frame(width: 450, height: 580)
    }
}
#endif 