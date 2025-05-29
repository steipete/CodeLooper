import AXorcist
import Diagnostics
import Foundation
@preconcurrency import ScreenCaptureKit
@preconcurrency import UserNotifications

/// Centralized manager for handling all app permissions
@MainActor
public final class PermissionsManager: ObservableObject {
    // MARK: Lifecycle

    public init() {
        checkAllPermissions()
        startMonitoring()
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: Public

    @Published public private(set) var hasAccessibilityPermissions: Bool = false
    @Published public private(set) var hasAutomationPermissions: Bool = false
    @Published public private(set) var hasScreenRecordingPermissions: Bool = false
    @Published public private(set) var hasNotificationPermissions: Bool = false

    /// Request accessibility permissions
    public func requestAccessibilityPermissions() async {
        logger.info("Requesting accessibility permissions")
        let granted = await AXPermissionHelpers.requestPermissions()
        self.hasAccessibilityPermissions = granted
        logger.info("Accessibility permissions request result: \(granted)")
    }

    /// Open System Settings for automation permissions
    public func openAutomationSettings() {
        logger.info("Opening System Settings for automation permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings for screen recording permissions
    public func openScreenRecordingSettings() {
        logger.info("Opening System Settings for screen recording permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Request notification permissions
    public func requestNotificationPermissions() async {
        logger.info("Requesting notification permissions")
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.hasNotificationPermissions = granted
            logger.info("Notification permissions request result: \(granted)")
        } catch {
            logger.error("Error requesting notification permissions: \(error)")
            self.hasNotificationPermissions = false
        }
    }

    /// Open System Settings for notification permissions
    public func openNotificationSettings() {
        logger.info("Opening System Settings for notification permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Manually refresh all permissions
    public func refreshPermissions() async {
        hasAccessibilityPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
        hasAutomationPermissions = await checkAutomationPermission()
        hasScreenRecordingPermissions = await checkScreenRecordingPermission()
        hasNotificationPermissions = await checkNotificationPermission()

        logger
            .info(
                "Permission status - Accessibility: \(hasAccessibilityPermissions), Automation: \(hasAutomationPermissions), Screen Recording: \(hasScreenRecordingPermissions), Notifications: \(hasNotificationPermissions)"
            )
    }

    // MARK: Private

    private var monitoringTask: Task<Void, Never>?
    private let logger = Logger(category: .permissions)
    private let cursorBundleID = "com.todesktop.230313mzl4w4u92"

    private func checkAllPermissions() {
        // Check accessibility synchronously
        hasAccessibilityPermissions = AXPermissionHelpers.hasAccessibilityPermissions()

        // Check other permissions asynchronously
        Task {
            hasAutomationPermissions = await checkAutomationPermission()
            hasScreenRecordingPermissions = await checkScreenRecordingPermission()
            hasNotificationPermissions = await checkNotificationPermission()

            logger
                .info(
                    "Initial permission status - Accessibility: \(hasAccessibilityPermissions), Automation: \(hasAutomationPermissions), Screen Recording: \(hasScreenRecordingPermissions), Notifications: \(hasNotificationPermissions)"
                )
        }
    }

    private func checkAutomationPermission() async -> Bool {
        // Execute AppleScript asynchronously to avoid blocking SwiftUI updates
        await withCheckedContinuation { continuation in
            Task.detached {
                let result = await MainActor.run {
                    self.performAutomationCheck()
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func performAutomationCheck() -> Bool {
        // Check if we have automation permission for System Events
        let systemEventsScript = NSAppleScript(source: """
            tell application "System Events"
                return name of first process whose frontmost is true
            end tell
        """)

        var errorDict: NSDictionary?
        let result = systemEventsScript?.executeAndReturnError(&errorDict)

        // If we can access System Events, we have automation permission
        if result != nil, errorDict == nil {
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

    private func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    private func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                // Re-check all permissions
                let newAccessibility = AXPermissionHelpers.hasAccessibilityPermissions()
                let newAutomation = await checkAutomationPermission()
                let newScreenRecording = await checkScreenRecordingPermission()
                let newNotifications = await checkNotificationPermission()

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

                if newNotifications != self.hasNotificationPermissions {
                    self.hasNotificationPermissions = newNotifications
                    self.logger.info("Notification permissions changed to: \(newNotifications)")
                }
            }
        }
    }
}

// MARK: - Shared Instance

public extension PermissionsManager {
    static let shared = PermissionsManager()
}
