import SwiftUI
import AXorcist
import Diagnostics

/// A reusable view component that displays accessibility permission status
/// and provides a button to request permissions if needed
struct PermissionsView: View {
    @StateObject private var viewModel = PermissionsViewModel()
    let showTitle: Bool
    let compact: Bool
    
    init(showTitle: Bool = true, compact: Bool = false) {
        self.showTitle = showTitle
        self.compact = compact
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if showTitle {
                Text("Accessibility Permissions")
                    .font(.headline)
            }
            
            if !(compact && viewModel.hasPermissions) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.hasPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(viewModel.hasPermissions ? .green : .orange)
                    .font(.system(size: compact ? 16 : 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.hasPermissions ? "Permissions Granted" : "Permissions Required")
                        .font(compact ? .callout : .body)
                        .fontWeight(.medium)
                    
                    if !compact {
                        Text(viewModel.hasPermissions 
                            ? "CodeLooper has the necessary accessibility permissions."
                            : "CodeLooper needs accessibility permissions to monitor and assist with Cursor.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !viewModel.hasPermissions {
                    Button(action: viewModel.requestPermissions) {
                        Text("Grant Permissions")
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
}

@MainActor
class PermissionsViewModel: ObservableObject {
    @Published var hasPermissions: Bool = false
    private var permissionTimer: Timer?
    private let logger = Logger(category: .permissions)
    
    init() {
        checkPermissions()
        startMonitoring()
    }
    
    // Timer will be invalidated when the view model is deallocated
    // due to weak self reference in the timer closure
    
    private func checkPermissions() {
        hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
        logger.info("Accessibility permissions status: \(hasPermissions)")
    }
    
    private func startMonitoring() {
        var lastState = hasPermissions
        
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let currentState = AXPermissionHelpers.hasAccessibilityPermissions()
                if currentState != lastState {
                    lastState = currentState
                    self.hasPermissions = currentState
                    self.logger.info("Accessibility permissions changed to: \(currentState)")
                    
                    // Post notification for other parts of the app
                    NotificationCenter.default.post(
                        name: .accessibilityPermissionsChanged,
                        object: nil,
                        userInfo: ["granted": currentState]
                    )
                }
            }
        }
    }
    
    private func stopMonitoring() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
    
    func requestPermissions() {
        logger.info("Requesting accessibility permissions")
        AXPermissionHelpers.requestPermissions { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.hasPermissions = granted
                self?.logger.info("Accessibility permissions request result: \(granted)")
            }
        }
    }
}

// MARK: - Preview

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PermissionsView(showTitle: true, compact: false)
                .padding()
            
            PermissionsView(showTitle: false, compact: true)
                .padding()
        }
    }
}