import AXorcist
import AppKit
import Diagnostics
import SwiftUI

/// A view component that displays automation permission status for Cursor
/// and provides a button to grant permissions if needed
struct AutomationPermissionsView: View {
    // MARK: Lifecycle

    init(showTitle: Bool = true, compact: Bool = false) {
        self.showTitle = showTitle
        self.compact = compact
    }

    // MARK: Internal

    let showTitle: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if showTitle {
                Text("Automation Permissions")
                    .font(.headline)
            }

            if !(compact && viewModel.hasPermissions) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.hasPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.hasPermissions ? .green : .orange)
                        .font(.system(size: compact ? 16 : 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.hasPermissions ? "Automation Granted" : "Automation Required")
                            .font(compact ? .callout : .body)
                            .fontWeight(.medium)

                        if !compact {
                            Text(viewModel.hasPermissions
                                ? "CodeLooper can control Cursor via automation."
                                : "CodeLooper needs permission to control Cursor for advanced features like JS injection.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !viewModel.hasPermissions {
                        Button(action: viewModel.openSystemSettings) {
                            Text("Grant Permission")
                                .font(compact ? .caption : .callout)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(compact ? 8 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.hasPermissions
                            ? Color.green.opacity(0.1)
                            : Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.hasPermissions
                            ? Color.green.opacity(0.3)
                            : Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Private

    @StateObject private var viewModel = AutomationPermissionsViewModel()
}

@MainActor
class AutomationPermissionsViewModel: ObservableObject {
    // MARK: Lifecycle

    init() {
        checkPermissions()
        startMonitoring()
    }

    // MARK: Internal

    @Published var hasPermissions: Bool = false

    func openSystemSettings() {
        logger.info("Opening System Settings for automation permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Private

    private var monitoringTask: Task<Void, Never>?
    private let logger = Logger(category: .permissions)
    private let cursorBundleID = "com.todesktop.230313mzl4w4u92"

    private func checkPermissions() {
        // Check automation permission for Cursor
        hasPermissions = checkAutomationPermission()
        logger.info("Automation permissions status for Cursor: \(hasPermissions)")
    }
    
    private func checkAutomationPermission() -> Bool {
        // Simple check: try to count windows in Cursor via AppleScript
        let script = NSAppleScript(source: """
            tell application id "\(cursorBundleID)" to count windows
        """)
        
        var errorDict: NSDictionary?
        let result = script?.executeAndReturnError(&errorDict)
        
        // If no error and we got a result, we have permission
        return errorDict == nil && result != nil
    }

    private func startMonitoring() {
        monitoringTask = Task {
            var lastState = hasPermissions
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                let currentState = checkAutomationPermission()
                
                if currentState != lastState {
                    lastState = currentState
                    hasPermissions = currentState
                    logger.info("Automation permissions changed to: \(currentState)")
                    
                    // Post notification for other parts of the app
                    NotificationCenter.default.post(
                        name: .automationPermissionsChanged,
                        object: nil,
                        userInfo: ["granted": currentState]
                    )
                }
            }
        }
    }

    deinit {
        monitoringTask?.cancel()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let automationPermissionsChanged = Notification.Name("automationPermissionsChanged")
}

// MARK: - Preview

struct AutomationPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AutomationPermissionsView(showTitle: true, compact: false)
                .padding()

            AutomationPermissionsView(showTitle: false, compact: true)
                .padding()
        }
    }
}
