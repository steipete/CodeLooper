import Defaults
import SwiftUI

struct MainPopoverView: View {
    @ObservedObject var cursorMonitor = CursorMonitor.shared // Assuming shared instance is available
    @ObservedObject var sessionLogger = SessionLogger.shared // Assuming shared instance is available
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header (Spec 3.2)
            HStack {
                // Logo placeholder - add app icon if available
                Text("CodeLooper").font(.headline)
                Spacer()
                Toggle("Monitor Cursor", isOn: $isGlobalMonitoringEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8) // Smaller toggle
            }
            .padding(.horizontal)

            Divider()

            // Cursor Instances Section (Spec 3.2)
            if cursorMonitor.instanceInfo.isEmpty {
                Text("No Cursor instances running or monitored.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(
                        cursorMonitor.instanceInfo.values.sorted { $0.processIdentifier < $1.processIdentifier }
                    ) { info in
                        instanceRow(for: info)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Global Actions/Status Footer (Spec 3.2)
            HStack {
                Text("Session Interventions: \(cursorMonitor.totalAutomaticInterventionsThisSession)")
                    .font(.footnote)
                Spacer()
                Button("Reset All & Resume") {
                    cursorMonitor.resetAllInstancesAndResume()
                }
                .font(.footnote)
            }
            .padding([.horizontal, .bottom])
            
            // Settings Cogwheel (placeholder, actual navigation handled by AppDelegate/MenuManager)
            // Button(action: { /* Open Settings */ }) {
            //     Image(systemName: "gearshape.fill")
            // }
            // .padding(.trailing)

        }
        .padding(.top, 10)
        .frame(width: 380, height: 450) // Default size, can be dynamic
    }

    @ViewBuilder
    private func instanceRow(for info: CursorInstanceInfo) -> some View {
        VStack(alignment: .leading) {
            HStack {
                // Status Icon (Spec 3.2)
                Image(systemName: statusIconName(for: info.status))
                    .foregroundColor(statusIconColor(for: info.status))
                Text("Cursor (PID: \(String(info.processIdentifier)))")
                    .font(.body)
                Spacer()
            }
            Text(info.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if case .paused = info.status {
                    Button("Resume Interventions") {
                        Task {
                            await cursorMonitor.resumeInterventions(for: info.pid)
                        }
                    }
                } else if case .unrecoverable = info.status {
                    Button("Resume Interventions") {
                        Task {
                            await cursorMonitor.resumeInterventions(for: info.pid)
                        }
                    }
                } else if case .error = info.status, info.statusMessage.contains("Persistent Error") {
                    Button("Resume Interventions") {
                        Task {
                            await cursorMonitor.resumeInterventions(for: info.pid)
                        }
                    }
                }
                
                Spacer() // Pushes Nudge Now to the right if other buttons are present

                Button("Nudge Now") {
                    Task {
                        await cursorMonitor.nudgeInstance(pid: info.pid)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func statusIconName(for status: CursorInstanceStatus) -> String {
        switch status {
        case .working:
            return "bolt.fill"
        case .idle:
            return "moon.fill"
        case .recovering:
            return "wrench.and.screwdriver.fill"
        case .error, .unrecoverable:
            return "exclamationmark.octagon.fill"
        case .paused:
            return "pause.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private func statusIconColor(for status: CursorInstanceStatus) -> Color {
        switch status {
        case .working:
            return .green
        case .idle:
            return .blue // Or gray, depending on preference
        case .recovering:
            return .orange
        case .error, .unrecoverable:
            return .red
        case .paused:
            return .gray
        case .unknown:
            return .purple
        }
    }
}

struct MainPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        // Need to mock CursorMonitor and SessionLogger for previews
        // For now, just return the view. It might crash or show empty state.
        MainPopoverView()
    }
} 
