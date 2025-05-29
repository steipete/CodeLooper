import AppKit
import AXorcist
import Diagnostics
import Foundation
@preconcurrency import ScreenCaptureKit
@preconcurrency import UserNotifications

/// Centralized manager for handling all app permissions
@MainActor
public final class PermissionsManager: ObservableObject, Loggable {
    // MARK: Lifecycle

    public init() {
        loadCachedPermissions()
        scheduleInitialPermissionCheck()
        startMonitoring()
    }

    deinit {
        monitoringTask?.cancel()
        initialCheckTask?.cancel()
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
        cachePermissionStates()
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

        // First check current authorization status
        let center = UNUserNotificationCenter.current()
        let currentSettings = await center.notificationSettings()

        switch currentSettings.authorizationStatus {
        case .notDetermined:
            // Only request if not determined yet
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                self.hasNotificationPermissions = granted
                cachePermissionStates()
                logger.info("Notification permissions request result: \(granted)")

                if !granted {
                    showPermissionDeniedAlert()
                }
            } catch {
                logger.error("Error requesting notification permissions: \(error)")
                self.hasNotificationPermissions = false
                cachePermissionStates()
                showPermissionErrorAlert(error: error)
            }

        case .denied:
            logger.info("Notification permissions were previously denied")
            self.hasNotificationPermissions = false
            cachePermissionStates()
            showPermissionSettingsAlert()

        case .authorized:
            logger.info("Notification permissions already granted")
            self.hasNotificationPermissions = true
            cachePermissionStates()

        case .provisional:
            logger.info("Notification permissions are provisional")
            self.hasNotificationPermissions = true
            cachePermissionStates()

        case .ephemeral:
            logger.info("Notification permissions are ephemeral")
            self.hasNotificationPermissions = true
            cachePermissionStates()

        @unknown default:
            logger.warning("Unknown notification permission status")
            self.hasNotificationPermissions = false
            cachePermissionStates()
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
        await checkAndUpdateAllPermissions()
    }

    // MARK: Private

    // UserDefaults keys for caching permissions
    private enum CacheKeys {
        static let accessibilityPermissions = "cached_accessibility_permissions"
        static let automationPermissions = "cached_automation_permissions"
        static let screenRecordingPermissions = "cached_screen_recording_permissions"
        static let notificationPermissions = "cached_notification_permissions"
        static let lastPermissionCheck = "last_permission_check_timestamp"
    }

    private var monitoringTask: Task<Void, Never>?
    private var initialCheckTask: Task<Void, Never>?
    private let cursorBundleID = "com.todesktop.230313mzl4w4u92"

    private func loadCachedPermissions() {
        let defaults = UserDefaults.standard

        // Load cached permission states for immediate UI display
        hasAccessibilityPermissions = defaults.bool(forKey: CacheKeys.accessibilityPermissions)
        hasAutomationPermissions = defaults.bool(forKey: CacheKeys.automationPermissions)
        hasScreenRecordingPermissions = defaults.bool(forKey: CacheKeys.screenRecordingPermissions)
        hasNotificationPermissions = defaults.bool(forKey: CacheKeys.notificationPermissions)

        logger.info("""
        Loaded cached permissions - Accessibility: \(hasAccessibilityPermissions), \
        Automation: \(hasAutomationPermissions), Screen Recording: \(hasScreenRecordingPermissions), \
        Notifications: \(hasNotificationPermissions)
        """)
    }

    private func scheduleInitialPermissionCheck() {
        // Schedule initial permission check to run after a short delay to avoid blocking app startup
        initialCheckTask = Task {
            // Small delay to allow UI to load with cached values first
            try? await Task.sleep(for: .seconds(TimingConfiguration.shortDelay))
            await checkAndUpdateAllPermissions()
        }
    }

    private func checkAndUpdateAllPermissions() async {
        // Check all permissions and update both UI state and cache
        let newAccessibility = AXPermissionHelpers.hasAccessibilityPermissions()
        let newAutomation = await checkAutomationPermission()
        let newScreenRecording = await checkScreenRecordingPermission()
        let newNotifications = await checkNotificationPermission()

        // Update UI state
        hasAccessibilityPermissions = newAccessibility
        hasAutomationPermissions = newAutomation
        hasScreenRecordingPermissions = newScreenRecording
        hasNotificationPermissions = newNotifications

        // Cache the results
        cachePermissionStates()

        logger.info("""
        Updated permission status - Accessibility: \(hasAccessibilityPermissions), \
        Automation: \(hasAutomationPermissions), Screen Recording: \(hasScreenRecordingPermissions), \
        Notifications: \(hasNotificationPermissions)
        """)
    }

    private func cachePermissionStates() {
        let defaults = UserDefaults.standard
        defaults.set(hasAccessibilityPermissions, forKey: CacheKeys.accessibilityPermissions)
        defaults.set(hasAutomationPermissions, forKey: CacheKeys.automationPermissions)
        defaults.set(hasScreenRecordingPermissions, forKey: CacheKeys.screenRecordingPermissions)
        defaults.set(hasNotificationPermissions, forKey: CacheKeys.notificationPermissions)
        defaults.set(Date().timeIntervalSince1970, forKey: CacheKeys.lastPermissionCheck)
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
                // Check permissions every 10 seconds instead of 2 to reduce overhead
                try? await Task.sleep(for: .seconds(TimingConfiguration.permissionCheckInterval))

                // Re-check all permissions
                let newAccessibility = AXPermissionHelpers.hasAccessibilityPermissions()
                let newAutomation = await checkAutomationPermission()
                let newScreenRecording = await checkScreenRecordingPermission()
                let newNotifications = await checkNotificationPermission()

                var permissionsChanged = false

                if newAccessibility != self.hasAccessibilityPermissions {
                    self.hasAccessibilityPermissions = newAccessibility
                    self.logger.info("Accessibility permissions changed to: \(newAccessibility)")
                    permissionsChanged = true
                }

                if newAutomation != self.hasAutomationPermissions {
                    self.hasAutomationPermissions = newAutomation
                    self.logger.info("Automation permissions changed to: \(newAutomation)")
                    permissionsChanged = true
                }

                if newScreenRecording != self.hasScreenRecordingPermissions {
                    self.hasScreenRecordingPermissions = newScreenRecording
                    self.logger.info("Screen recording permissions changed to: \(newScreenRecording)")
                    permissionsChanged = true
                }

                if newNotifications != self.hasNotificationPermissions {
                    self.hasNotificationPermissions = newNotifications
                    self.logger.info("Notification permissions changed to: \(newNotifications)")
                    permissionsChanged = true
                }

                // Only update cache if permissions actually changed
                if permissionsChanged {
                    self.cachePermissionStates()
                }
            }
        }
    }

    // MARK: - Alert Helpers

    @MainActor
    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Notification Permission Denied"
        alert.informativeText =
            "You denied notification permissions. CodeLooper uses notifications to inform you about " +
            "automation events and important updates."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showPermissionErrorAlert(error _: Error) {
        let alert = NSAlert()
        alert.messageText = "Notification Permission Request Failed"
        alert
            .informativeText =
            "Notifications are not allowed for this application. You can enable them in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }

    @MainActor
    private func showPermissionSettingsAlert() {
        let alert = NSAlert()
        alert.messageText = "Notification Permission Required"
        alert
            .informativeText =
            "Notification permissions were previously denied. Please enable them in System Settings > Privacy & Security > Notifications."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }
}

// MARK: - Shared Instance

public extension PermissionsManager {
    static let shared = PermissionsManager()
}
