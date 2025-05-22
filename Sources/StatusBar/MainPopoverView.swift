import SwiftUI
import Defaults
import AppKit // For NSImage

// Ensure CursorInstanceInfo and CursorInstanceStatus are accessible
// If they are in a different module without proper import, this won't compile.
// Assuming they are part of the main app target or a correctly imported module.

struct MainPopoverView: View {
    @ObservedObject private var cursorMonitor = CursorMonitor.shared
    @ObservedObject private var sessionLogger = SessionLogger.shared // For total interventions
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled

    // Accessing AppDelegate to show settings. This might need a more robust solution
    // like a shared service or environment object for window management.
    private func openSettings() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSettingsWindow(nil)
        } else {
            print("Could not get AppDelegate to open settings.")
        }
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
        .frame(width: 420, height: 550) // Adjusted size for better fit
        .onAppear {
            // Potentially refresh instances if needed, though Workspace notifications should handle it.
            // cursorMonitor.refreshMonitoredInstances()
        }
    }

    private var headerView: some View {
        HStack {
            Image("logo") // Assuming a logo asset named 'logo_popover'
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
                .scaleEffect(0.8) // Smaller toggle
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
            if cursorMonitor.instanceInfo.isEmpty {
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
                List {
                    ForEach(cursorMonitor.instanceInfo.sorted(by: { $0.key < $1.key }), id: \.key) { pid, info in
                        instanceRow(pid: pid, info: info)
                            .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain) // Removes default List styling for a cleaner look
            }
        }
    }

    @ViewBuilder
    private func instanceRow(pid: pid_t, info: CursorInstanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                statusIndicator(for: info.status)
                
                if let nsImage = info.app.icon {
                     Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "questionmark.app")
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text("\\(info.app.localizedName ?? "Cursor") (PID: \\(pid))")
                    .fontWeight(.medium)
                Spacer()
            }
            
            Text(info.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)


            HStack(spacing: 10) {
                Spacer() // Push buttons to the right

                if shouldShowResumeButton(for: info.status) {
                    Button("Resume Interventions") {
                        Task {
                            await cursorMonitor.resumeInterventions(for: pid)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Nudge Now") {
                    Task {
                        await cursorMonitor.nudgeInstance(pid: pid, app: info.app)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private func statusIndicator(for status: CursorInstanceStatus) -> some View {
        let (iconName, color) = iconAndColor(for: status)
        Image(systemName: iconName)
            .foregroundColor(color)
            .font(.title3) // Slightly larger indicator
            .frame(width: 24, alignment: .center)
    }

    private func iconAndColor(for status: CursorInstanceStatus) -> (String, Color) {
        switch status {
        case .unknown:
            return ("questionmark.circle.fill", .gray)
        case .idle:
            return ("moon.zzz.fill", .gray)
        case .working(let detail):
            if detail.lowercased().contains("generating") || detail.lowercased().contains("typing") {
                 return ("paperplane.circle.fill", .green) // "Generating" or "Typing"
            } else if detail.lowercased().contains("activity") {
                return ("figure.walk.motion", .blue) // "Recent Activity"
            }
            return ("brain.head.profile", .purple) // Other "working"
        case .recovering(let type, let attempt):
            let baseIcon = "arrow.triangle.2.circlepath.circle.fill"
            // Could use type or attempt to modify icon/color if needed
            return (baseIcon, .orange)
        case .paused:
            return ("pause.circle.fill", .yellow)
        case .error(let reason):
             if reason.lowercased().contains("unrecoverable") || reason.lowercased().contains("persistent") {
                 return ("xmark.octagon.fill", .red)
             }
            return ("exclamationmark.triangle.fill", .red)
        case .unrecoverable:
            return ("xmark.shield.fill", .red) // Distinct unrecoverable
        }
    }

    private func shouldShowResumeButton(for status: CursorInstanceStatus) -> Bool {
        switch status {
        case .paused, .unrecoverable, .error:
            // Show resume for paused, unrecoverable, and any error state.
            return true
        default:
            return false
        }
    }

    private var footerView: some View {
        HStack {
            Text("Session Interventions: \\(cursorMonitor.totalAutomaticInterventionsThisSession)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
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
            .buttonStyle(.borderless) // Make it look like an icon button
            .controlSize(.small)
            .padding(.leading, 6)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct MainPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data for preview
        let mockMonitor = CursorMonitor.shared // Use shared for basic structure, override data for specific states
        
        // It's hard to mock NSRunningApplication directly in previews in a simple way.
        // So, the preview might show an empty state unless the monitor is populated.
        // For more complex previews, consider a mock CursorMonitor with predefined instanceInfo.

        MainPopoverView()
            .onAppear {
                // Example of how to add mock data if needed:
                /*
                let mockApp = NSRunningApplication() // This won't be a real Cursor app
                let mockInfo1 = CursorInstanceInfo(app: mockApp, status: .working(detail: "Generating code..."), statusMessage: "Generating a new function for you.")
                let mockInfo2 = CursorInstanceInfo(app: mockApp, status: .error(reason: "Connection timed out."), statusMessage: "Error: Could not connect to the server.")
                mockMonitor.instanceInfo = [123: mockInfo1, 456: mockInfo2]
                mockMonitor.totalAutomaticInterventionsThisSession = 5
                 */
            }
    }
}
#endif 