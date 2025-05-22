import Combine
import Defaults
@preconcurrency import Foundation
import LaunchAtLogin
import os.log

/// Manages the app's login item settings for starting at login
/// Uses the LaunchAtLogin library for simplified management
@MainActor
public final class LoginItemManager: ObservableObject {
    // MARK: - Shared instance

    public static let shared = LoginItemManager()

    // MARK: - Properties

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "LoginItemManager")
    private static let statusChangedNotification = Notification.Name("LaunchAtLoginStatusChanged")

    // Store notification observation token for proper cleanup
    private var notificationToken: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        // Restricted initializer for singleton

        // On initialization, sync the status to ensure UserDefaults matches system state
        syncWithSystemState()

        // Register for internal LaunchAtLogin status change notifications
        // Use block-based API for better safety with queue specification
        notificationToken = NotificationCenter.default.addObserver(
            forName: Self.statusChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Update preferences to match system state when status changes
            guard let self else { return }
            // Since we need to call a MainActor method in a notification handler,
            // we need to explicitly use Task to properly hop to the main actor
            Task { @MainActor in
                self.syncWithSystemState()
            }
        }
    }

    deinit {
        // Since deinit is not MainActor-isolated but notification removal requires main thread,
        // we use direct main thread dispatch to avoid concurrency issues
        // Make a strong copy of the token to avoid thread issues
        let tokenCopy = notificationToken
        DispatchQueue.main.async {
            if let token = tokenCopy {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    // MARK: - Public Methods

    /// Toggle the app's login item status
    /// - Returns: Current login item status after toggling
    @discardableResult
    @MainActor
    func toggleStartAtLogin() -> Bool {
        logger.info("Toggling login item from \(LaunchAtLogin.isEnabled) to \(!LaunchAtLogin.isEnabled)")

        // Toggle the LaunchAtLogin setting
        LaunchAtLogin.isEnabled.toggle()

        // Update our preference to match
        Defaults[.startAtLogin] = LaunchAtLogin.isEnabled

        logger.info("Login item toggled to: \(LaunchAtLogin.isEnabled)")
        return LaunchAtLogin.isEnabled
    }

    /// Set the login item status directly
    /// - Parameter enabled: Whether the app should start at login
    /// - Returns: Whether the operation was successful
    @discardableResult
    @MainActor
    func setStartAtLogin(enabled: Bool) -> Bool {
        logger.info("Setting login item to \(enabled)")

        // First read the current state to see if it needs updating
        let currentState = LaunchAtLogin.isEnabled
        if currentState != enabled {
            // Update LaunchAtLogin
            LaunchAtLogin.isEnabled = enabled

            // Verify the change took effect and only update UserDefaults if successful
            if LaunchAtLogin.isEnabled == enabled {
                // Update preference to match system state after confirming change was successful
                Defaults[.startAtLogin] = enabled
                logger.info("Login item set to: \(enabled) successfully, UserDefaults updated")
            } else {
                logger.error("Failed to set launch at login state to \(enabled)")
                // Call syncWithSystemState to make sure UserDefaults matches the actual system state
                syncWithSystemState()
            }
        } else {
            // System state already matches desired state, make sure UserDefaults is in sync
            Defaults[.startAtLogin] = enabled
            logger.info("Login item already set to: \(enabled), UserDefaults synced")
        }

        logger.info("Final state - Login item: \(LaunchAtLogin.isEnabled), UserDefaults: \(Defaults[.startAtLogin])")
        return LaunchAtLogin.isEnabled == enabled
    }

    /// Check if the app is currently set to start at login
    /// - Returns: Whether the app starts at login
    @MainActor
    func startsAtLogin() -> Bool {
        // First sync with system to ensure we have the latest state
        syncWithSystemState()
        return LaunchAtLogin.isEnabled
    }

    /// Sync UserDefaults with the actual system state
    /// This ensures the UI correctly reflects the actual system status
    @MainActor
    private func syncWithSystemState() {
        let systemState = LaunchAtLogin.isEnabled
        let userDefaultsState = Defaults[.startAtLogin]

        if systemState != userDefaultsState {
            logger.info("Syncing UserDefaults with system state: \(systemState)")
            Defaults[.startAtLogin] = systemState
        }
    }

    /// Ensure the login item status matches the preference
    /// - Returns: Whether the sync was successful
    @discardableResult
    @MainActor
    func syncLoginItemWithPreference() -> Bool {
        // First check if system matches our preference
        let shouldStartAtLogin = Defaults[.startAtLogin]
        let currentStatus = LaunchAtLogin.isEnabled

        logger.info("Synchronizing login item status - preference: \(shouldStartAtLogin), actual system state: \(currentStatus)")

        // If there's a mismatch, use the preference value and apply to system
        if shouldStartAtLogin != currentStatus {
            // Update LaunchAtLogin to match preference
            LaunchAtLogin.isEnabled = shouldStartAtLogin

            // Verify the change
            if LaunchAtLogin.isEnabled != shouldStartAtLogin {
                logger.error("Failed to set launch at login state to match preference: \(shouldStartAtLogin)")

                // If system state couldn't be updated, update the preference instead
                Defaults[.startAtLogin] = LaunchAtLogin.isEnabled
                logger.info("Updated preference to match system state: \(LaunchAtLogin.isEnabled)")
                return false
            }

            logger.info("Login item status synchronized to preference: \(shouldStartAtLogin)")
        } else {
            logger.info("Login item status already in sync")
        }

        return true
    }

    /// Observe changes to the login item status
    ///
    /// - Parameter handler: Closure to call when the status changes
    /// - Returns: A CustomObservation that can be used to cancel the observation
    @MainActor
    func observeLoginItemStatus(_ handler: @escaping @Sendable (Bool) -> Void) -> CustomObservation {
        // Use block-based notification API for better thread safety
        let token = NotificationCenter.default.addObserver(
            forName: Self.statusChangedNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Since we're on the main queue and this is a simple boolean callback,
            // it's safe to call the handler directly
            handler(LaunchAtLogin.isEnabled)
        }

        // Create an observation that removes the observer when cancelled
        return CallbackObservation {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
