import SwiftUI

/// SwiftUI view for rendering the menu bar status display
/// Uses the shared StatusIndicators component in compact mode
struct MenuBarStatusView: View {
    let workingCount: Int
    let notWorkingCount: Int
    let unknownCount: Int
    let isMonitoringEnabled: Bool
    
    var body: some View {
        if isMonitoringEnabled {
            StatusIndicators(
                runningCount: workingCount,
                notRunningCount: notWorkingCount,
                isCompact: true
            )
            .frame(height: 18) // Standard menu bar height
            .padding(.horizontal, 2)
        } else {
            // Monitoring disabled - show gray dot
            Image(systemName: "circle.fill")
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
                .frame(height: 18)
                .padding(.horizontal, 2)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Active state with working and not working instances
        HStack {
            Text("7 Working, 4 Not Working:")
            MenuBarStatusView(
                workingCount: 7,
                notWorkingCount: 4,
                unknownCount: 0,
                isMonitoringEnabled: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        
        // Only working instances
        HStack {
            Text("3 Working:")
            MenuBarStatusView(
                workingCount: 3,
                notWorkingCount: 0,
                unknownCount: 0,
                isMonitoringEnabled: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        
        // Only not working instances
        HStack {
            Text("2 Not Working:")
            MenuBarStatusView(
                workingCount: 0,
                notWorkingCount: 2,
                unknownCount: 1,
                isMonitoringEnabled: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        
        // Idle state
        HStack {
            Text("Idle:")
            MenuBarStatusView(
                workingCount: 0,
                notWorkingCount: 0,
                unknownCount: 0,
                isMonitoringEnabled: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        
        // Monitoring disabled
        HStack {
            Text("Disabled:")
            MenuBarStatusView(
                workingCount: 0,
                notWorkingCount: 0,
                unknownCount: 0,
                isMonitoringEnabled: false
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    .padding()
    .scaleEffect(2) // Make larger for preview visibility
}