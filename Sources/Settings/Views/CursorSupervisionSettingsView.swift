import Defaults
import SwiftUI

struct CursorSupervisionSettingsView: View {
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.enableConnectionIssuesRecovery)
    var enableConnectionIssuesRecovery
    @Default(.enableCursorForceStoppedRecovery)
    var enableCursorForceStoppedRecovery
    @Default(.enableCursorStopsRecovery)
    var enableCursorStopsRecovery

    var body: some View {
        Form {
            Section(header: Text("Automated Recovery Behaviors")) {
                Text(
                    "Enable specific automatic recovery mechanisms CodeLooper should attempt when " +
                    "Cursor appears to be stuck or encounters issues."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Toggle("Enable \"Connection Issues\" Recovery", isOn: $enableConnectionIssuesRecovery)
                Toggle(
                    "Enable \"Cursor Force-Stopped (Loop Limit)\" Recovery",
                    isOn: $enableCursorForceStoppedRecovery
                )
                Toggle("Enable \"Cursor Stops\" (Nudge with Custom Text) Recovery", isOn: $enableCursorStopsRecovery)
            }
            
            Section(header: Text("Activity Monitoring")) {
                Toggle(
                    "Monitor Sidebar Activity as Positive Work Indicator",
                    isOn: $monitorSidebarActivity
                )
                Text(
                    "If enabled, changes detected in Cursor's sidebar will be considered a sign of " +
                    "active use, resetting intervention counters."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Adjust frame as needed
    }
}

#if DEBUG
struct CursorSupervisionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CursorSupervisionSettingsView()
            .frame(width: 600, height: 400) // Example frame for preview
    }
}
#endif 
