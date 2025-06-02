import Combine
import Defaults
import Diagnostics
@preconcurrency import Foundation
import os.log
import ServiceManagement

/// Manages the app's login item settings for starting at login
/// Uses the native SMAppService API (requires macOS 13+)
@MainActor
public final class LoginItemManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        // Restricted initializer for singleton

        // Register for login item status change notifications
        notificationToken = NotificationCenter.default.addObserver(
            forName: Self.statusChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Update preferences to match system state when status changes
            guard let self else { return }
            Task { @MainActor in
                self.syncWithSystemState()
            }
        }
        
        // Defer initial sync to ensure object is fully initialized
        Task { @MainActor in
            // On initialization, sync the status to ensure UserDefaults matches system state
            self.syncWithSystemState()
        }
    }

    deinit {
        // Make a strong copy of the token to avoid thread issues
        let tokenCopy = notificationToken
        DispatchQueue.main.async {
            if let token = tokenCopy {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    // MARK: Public

    // MARK: - Shared instance

    public static let shared = LoginItemManager()

    // MARK: Internal

    // MARK: - Public Methods

    /// Toggle the app's login item status
    /// - Returns: Current login item status after toggling
    @discardableResult
    @MainActor
    func toggleStartAtLogin() -> Bool {
        let currentState = isEnabled()
        let newState = !currentState
        logger.info("Toggling login item from \(currentState) to \(!currentState)")

        // Toggle the login item setting
        setEnabled(newState)

        // Update our preference to match
        Defaults[.startAtLogin] = newState

        logger.info("Login item toggled to: \(newState)")
        return newState
    }

    /// Set the login item status directly
    /// - Parameter enabled: Whether the app should start at login
    /// - Returns: Whether the operation was successful
    @discardableResult
    @MainActor
    func setStartAtLogin(enabled: Bool) -> Bool {
        logger.info("Setting login item to \(enabled)")

        // First read the current state to see if it needs updating
        let currentState = isEnabled()
        if currentState != enabled {
            // Update login item
            setEnabled(enabled)

            // Verify the change took effect and only update UserDefaults if successful
            if isEnabled() == enabled {
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

        logger.info("Final state - Login item: \(isEnabled()), UserDefaults: \(Defaults[.startAtLogin])")
        return isEnabled() == enabled
    }

    /// Check if the app is currently set to start at login
    /// - Returns: Whether the app starts at login
    @MainActor
    func startsAtLogin() -> Bool {
        // First sync with system to ensure we have the latest state
        syncWithSystemState()
        return isEnabled()
    }

    /// Ensure the login item status matches the preference
    /// - Returns: Whether the sync was successful
    @discardableResult
    @MainActor
    func syncLoginItemWithPreference() -> Bool {
        // First check if system matches our preference
        let shouldStartAtLogin = Defaults[.startAtLogin]
        let currentStatus = isEnabled()

        logger
            .info(
                "Synchronizing login item status - preference: \(shouldStartAtLogin), actual system state: \(currentStatus)"
            )

        // If there's a mismatch, use the preference value and apply to system
        if shouldStartAtLogin != currentStatus {
            // Update login item to match preference
            setEnabled(shouldStartAtLogin)

            // Verify the change
            if isEnabled() != shouldStartAtLogin {
                logger.error("Failed to set launch at login state to match preference: \(shouldStartAtLogin)")

                // If system state couldn't be updated, update the preference instead
                Defaults[.startAtLogin] = isEnabled()
                logger.info("Updated preference to match system state: \(isEnabled())")
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
        ) { [weak self] _ in
            // Since we're on the main queue and this is a simple boolean callback,
            // it's safe to call the handler directly
            guard let self else { return }
            Task { @MainActor in
                handler(self.isEnabled())
            }
        }

        // Create an observation that removes the observer when cancelled
        return CallbackObservation {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: Private

    private static let statusChangedNotification = Notification.Name("LoginItemStatusChanged")

    private let logger = Logger(category: .utilities)

    // Store notification observation token for proper cleanup
    private var notificationToken: NSObjectProtocol?

    /// Check if login item is enabled
    @MainActor
    private func isEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Set login item enabled state
    @MainActor
    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    logger.debug("Login item already enabled")
                    return
                }
                try SMAppService.mainApp.register()
                logger.info("Successfully enabled login item")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    logger.debug("Login item already disabled")
                    return
                }
                try SMAppService.mainApp.unregister()
                logger.info("Successfully disabled login item")
            }
            
            // Post notification after successful change
            NotificationCenter.default.post(name: Self.statusChangedNotification, object: nil)
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
        }
    }

    /// Sync UserDefaults with the actual system state
    /// This ensures the UI correctly reflects the actual system status
    @MainActor
    private func syncWithSystemState() {
        let systemState = isEnabled()
        let userDefaultsState = Defaults[.startAtLogin]

        if systemState != userDefaultsState {
            logger.info("Syncing UserDefaults with system state: \(systemState)")
            Defaults[.startAtLogin] = systemState
        }
    }
}
