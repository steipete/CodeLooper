import SwiftUI
import Defaults
import AppKit

struct MainPopoverView: View {
    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            headerView
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            Divider()

            // MARK: - Cursor Instances List
            instanceListView
            
            Divider()

            // MARK: - Footer
            footerView
                .padding()
        }
        .frame(width: 450, height: 580)
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
    
    private var footerView: some View {
        HStack {
            Text("Session Interventions: \(cursorMonitor.totalAutomaticInterventionsThisSession)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                // Resume any manually paused instances
                for instance in cursorMonitor.monitoredInstances {
                    if instance.status == .pausedManually {
                        cursorMonitor.resumeMonitoring(for: instance.pid)
                    }
                }
                // Reset all instances
                Task {
                    await cursorMonitor.resetAllInstancesAndResume()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                Text("Reset All")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.leading, 6)
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