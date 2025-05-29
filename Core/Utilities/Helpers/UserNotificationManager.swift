import AppKit
import Diagnostics
import Foundation
@preconcurrency import UserNotifications

/// Manager for handling user notifications
@MainActor
public final class UserNotificationManager: ObservableObject {
    // MARK: Lifecycle

    private init() {
        logger.info("UserNotificationManager initialized")
        // Don't request permissions automatically - let PermissionsManager handle it
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: Public

    public static let shared = UserNotificationManager()

    @Published public private(set) var hasPermission = false
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Request notification permissions
    public func requestNotificationPermissions() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                )

                await MainActor.run {
                    self.hasPermission = granted
                    logger.info("Notification permission \(granted ? "granted" : "denied")")
                }

                await checkAuthorizationStatus()
            } catch {
                logger.error("Failed to request notification permissions: \(error)")
            }
        }
    }

    /// Check current authorization status
    public func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.hasPermission = settings.authorizationStatus == .authorized
        }
    }

    /// Send a notification
    public func sendNotification(
        title: String,
        body: String,
        identifier: String? = nil,
        sound: UNNotificationSound? = .default,
        badge: NSNumber? = nil
    ) async throws {
        guard hasPermission else {
            logger.warning("Cannot send notification: permission not granted")
            throw NotificationError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        if let sound {
            content.sound = sound
        }

        if let badge {
            content.badge = badge
        }

        let notificationId = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Sent notification: \(title)")
        } catch {
            logger.error("Failed to send notification: \(error)")
            throw NotificationError.deliveryFailed(error)
        }
    }

    /// Send rule execution notification
    public func sendRuleExecutionNotification(
        ruleName: String,
        displayName: String,
        executionCount: Int,
        isWarning: Bool = false
    ) async {
        guard hasPermission else { return }

        let title: String
        let body: String

        if isWarning {
            title = "Rule Execution Warning"
            body = "\(displayName) has executed \(executionCount) times. Will stop at 25 executions."
        } else if executionCount >= 25 {
            title = "Rule Execution Stopped"
            body = "\(displayName) has reached the maximum of 25 executions and has been stopped."
        } else {
            title = "Rule Executed"
            body = "\(displayName) executed successfully (execution #\(executionCount))"
        }

        do {
            try await sendNotification(
                title: title,
                body: body,
                identifier: "rule-\(ruleName)-\(Date().timeIntervalSince1970)"
            )
        } catch {
            logger.error("Failed to send rule execution notification: \(error)")
        }
    }

    /// Open notification settings
    public func openNotificationSettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            logger.error("Failed to create notification settings URL")
            return
        }

        NSWorkspace.shared.open(settingsURL)
    }

    // MARK: Private

    private let logger = Logger(category: .utilities)
}

// MARK: - Error Types

public enum NotificationError: LocalizedError {
    case permissionDenied
    case deliveryFailed(Error)

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Notification permission was denied"
        case let .deliveryFailed(error):
            "Failed to deliver notification: \(error.localizedDescription)"
        }
    }
}
