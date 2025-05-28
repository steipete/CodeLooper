import Diagnostics
import Foundation
import OSLog
@preconcurrency import UserNotifications

/// UserNotificationManager handles user notifications on macOS with full Swift 6 concurrency compliance.
/// This actor safely manages notification authorization and delivery while properly handling
/// the interaction with UNUserNotificationCenter's @MainActor isolation.
public actor UserNotificationManager {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                if granted {
                    Self.logger.info("User notification permissions granted.")
                } else {
                    Self.logger.warning("User notification permissions not granted.")
                }
            } catch {
                Self.logger.error("Error requesting user notification permissions: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Public

    // MARK: - Singleton

    public static let shared = UserNotificationManager()

    // MARK: - Public Methods

    /// Sends a user notification with the specified parameters
    /// - Parameters:
    ///   - identifier: Unique identifier for the notification
    ///   - title: The notification title
    ///   - body: The notification body text
    ///   - subtitle: Optional subtitle for the notification
    ///   - soundName: Optional name of the sound file to play (e.g., "Blow.aiff"). "default" for default sound, nil for
    /// no sound.
    ///   - categoryIdentifier: Optional category identifier for the notification
    ///   - userInfo: Optional user information for the notification
    public func sendNotification(
        identifier: String = UUID().uuidString,
        title: String,
        body: String,
        subtitle: String? = nil,
        soundName: String? = "default",
        categoryIdentifier _: String? = nil,
        userInfo _: [AnyHashable: Any]? = nil
    ) async {
        let authorizationStatus = await UNUserNotificationCenter.getSafeAuthorizationStatus()

        guard authorizationStatus == .authorized else {
            Self.logger.debug("Cannot send notification, authorization denied or not determined.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        if let subtitle {
            content.subtitle = subtitle
        }

        // Construct UNNotificationSound from soundName
        if let name = soundName {
            if name.lowercased() == "default" {
                content.sound = UNNotificationSound.default
            } else if !name.isEmpty {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
            } else {
                // Explicitly empty name might mean no sound, or treat as an error/default.
                // For now, treating empty string as no sound (same as nil soundName if not for "default" special case)
                content.sound = nil
            }
        } else {
            content.sound = nil // No sound if soundName is nil
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            Self.logger.info("Notification \"\(identifier)\" scheduled successfully.")
        } catch {
            Self.logger.error("Error sending notification \"\(identifier)\": \(error.localizedDescription)")
        }
    }

    /// Removes a pending notification with the specified identifier
    /// - Parameter identifier: The identifier of the notification to remove
    public func removePendingNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        Self.logger.info("Removed pending notification request for identifier: \(identifier)")
    }

    /// Removes all pending notifications
    public func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Self.logger.info("Removed all pending notification requests.")
    }

    // MARK: Private

    private static let logger = Logger(category: .notifications)

    private var isAuthorizationRequested = false

    // MARK: - Authorization

    /// Checks current authorization status
    private func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}

// MARK: - Sendable Conformance

extension UserNotificationManager: Sendable {}

// MARK: - UNAuthorizationStatus Extension

extension UNAuthorizationStatus {
    /// String representation for logging purposes
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}

// Extend UNUserNotificationCenter to provide a Sendable way to get status
extension UNUserNotificationCenter {
    static func getSafeAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
