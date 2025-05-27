import AXorcist
import Diagnostics
import SwiftUI
import DesignSystem
@preconcurrency import ScreenCaptureKit

/// A comprehensive view that displays all permission statuses
struct AllPermissionsView: View {
    // MARK: Internal
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Accessibility Permission
            PermissionRowView(
                title: "Accessibility",
                description: "Required to monitor and interact with Cursor",
                hasPermission: viewModel.hasAccessibilityPermissions,
                onGrantPermission: viewModel.requestAccessibilityPermissions
            )
            
            DSDivider()
            
            // Automation Permission
            PermissionRowView(
                title: "Automation",
                description: "Required to control Cursor for advanced features",
                hasPermission: viewModel.hasAutomationPermissions,
                onGrantPermission: viewModel.openAutomationSettings
            )
            
            DSDivider()
            
            // Screen Recording Permission
            PermissionRowView(
                title: "Screen Recording",
                description: "Required to capture Cursor windows for AI analysis",
                hasPermission: viewModel.hasScreenRecordingPermissions,
                onGrantPermission: viewModel.openScreenRecordingSettings
            )
        }
    }
    
    // MARK: Private
    
    @StateObject private var viewModel = AllPermissionsViewModel()
}

// MARK: - Permission Row View

private struct PermissionRowView: View {
    let title: String
    let description: String
    let hasPermission: Bool
    let onGrantPermission: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            // Status icon
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(hasPermission ? ColorPalette.success : ColorPalette.warning)
                .font(.system(size: 20))
            
            // Text content
            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text(title)
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.text)
                
                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
            
            // Status or grant button
            if hasPermission {
                Text("Granted")
                    .font(Typography.caption1(.medium))
                    .foregroundColor(ColorPalette.success)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.xxSmall)
                    .background(ColorPalette.success.opacity(0.1))
                    .cornerRadiusDS(Layout.CornerRadius.small)
            } else {
                DSButton("Grant", style: .secondary, size: .small) {
                    onGrantPermission()
                }
            }
        }
        .padding(.vertical, Spacing.xxSmall)
    }
}

// MARK: - View Model

@MainActor
class AllPermissionsViewModel: ObservableObject {
    // MARK: Lifecycle
    
    init() {
        checkAllPermissions()
        startMonitoring()
    }
    
    deinit {
        monitoringTask?.cancel()
    }
    
    // MARK: Internal
    
    @Published var hasAccessibilityPermissions: Bool = false
    @Published var hasAutomationPermissions: Bool = false
    @Published var hasScreenRecordingPermissions: Bool = false
    
    func requestAccessibilityPermissions() {
        logger.info("Requesting accessibility permissions")
        Task {
            let granted = await AXPermissionHelpers.requestPermissions()
            await MainActor.run {
                self.hasAccessibilityPermissions = granted
                self.logger.info("Accessibility permissions request result: \(granted)")
            }
        }
    }
    
    func openAutomationSettings() {
        logger.info("Opening System Settings for automation permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openScreenRecordingSettings() {
        logger.info("Opening System Settings for screen recording permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: Private
    
    private var monitoringTask: Task<Void, Never>?
    private let logger = Logger(category: .permissions)
    private let cursorBundleID = "com.todesktop.230313mzl4w4u92"
    
    private func checkAllPermissions() {
        // Check accessibility
        hasAccessibilityPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
        
        // Check automation
        hasAutomationPermissions = checkAutomationPermission()
        
        // Check screen recording
        Task {
            hasScreenRecordingPermissions = await checkScreenRecordingPermission()
        }
        
        logger.info("Permission status - Accessibility: \(hasAccessibilityPermissions), Automation: \(hasAutomationPermissions), Screen Recording: \(hasScreenRecordingPermissions)")
    }
    
    private func checkAutomationPermission() -> Bool {
        // Check if we have automation permission for System Events
        let systemEventsScript = NSAppleScript(source: """
            tell application "System Events"
                return name of first process whose frontmost is true
            end tell
        """)
        
        var errorDict: NSDictionary?
        let result = systemEventsScript?.executeAndReturnError(&errorDict)
        
        // If we can access System Events, we have automation permission
        if result != nil && errorDict == nil {
            return true
        }
        
        // Fallback: try to check Cursor directly
        let cursorScript = NSAppleScript(source: """
            tell application id "\(cursorBundleID)"
                return exists
            end tell
        """)
        
        let cursorResult = cursorScript?.executeAndReturnError(&errorDict)
        return cursorResult != nil && errorDict == nil
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Try to get shareable content - this will fail if we don't have permission
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            // If we get an error, we likely don't have permission
            return false
        }
    }
    
    private func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Re-check all permissions
                let newAccessibility = AXPermissionHelpers.hasAccessibilityPermissions()
                let newAutomation = checkAutomationPermission()
                let newScreenRecording = await checkScreenRecordingPermission()
                
                await MainActor.run {
                    if newAccessibility != self.hasAccessibilityPermissions {
                        self.hasAccessibilityPermissions = newAccessibility
                        self.logger.info("Accessibility permissions changed to: \(newAccessibility)")
                    }
                    
                    if newAutomation != self.hasAutomationPermissions {
                        self.hasAutomationPermissions = newAutomation
                        self.logger.info("Automation permissions changed to: \(newAutomation)")
                    }
                    
                    if newScreenRecording != self.hasScreenRecordingPermissions {
                        self.hasScreenRecordingPermissions = newScreenRecording
                        self.logger.info("Screen recording permissions changed to: \(newScreenRecording)")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AllPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        AllPermissionsView()
            .padding()
            .frame(width: 500)
            .background(ColorPalette.background)
            .withDesignSystem()
    }
}
#endif