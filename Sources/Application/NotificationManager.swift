import Diagnostics
import Foundation
import OSLog
import UserNotifications

/**
 Centralized manager for handling system notifications.
 This class encapsulates all notification-related functionality.
 */
@MainActor
class NotificationManager {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        setupNotificationCenter()
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Methods

    /// Shows a notification for upload completion
    func showUploadCompleteNotification(title: String, message: String, metadata: [String: Any]? = nil) {
        logger.info("Showing upload complete notification")
        showLocalNotification(title: title, message: message, identifier: "uploadComplete", metadata: metadata)
    }

    /// Shows a notification for sync completion
    func showSyncCompleteNotification(title: String, message: String, metadata: [String: Any]? = nil) {
        logger.info("Showing sync complete notification")
        showLocalNotification(title: title, message: message, identifier: "syncComplete", metadata: metadata)
    }

    // MARK: Private

    private let logger = Logger(category: .notifications)

    // MARK: - Setup

    private func setupNotificationCenter() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.logger.info("Notification permissions granted")
                } else {
                    if let error {
                        self.logger.error("Notification permission error: \(error.localizedDescription)")
                    } else {
                        self.logger.warning("Notification permissions denied by user")
                    }
                }
            }
        }
    }

    /// Shows a local notification
    private func showLocalNotification(
        title: String,
        message: String,
        identifier: String,
        metadata: [String: Any]? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        // Add user info if provided
        if let metadata {
            content.userInfo = metadata
        }

        // Create request with immediate trigger
        let request = UNNotificationRequest(
            identifier: identifier + "-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        // Add to notification center
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    self.logger.info("Notification scheduled successfully")
                }
            }
        }
    }
}
