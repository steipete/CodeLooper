import AppKit
@preconcurrency import Combine
@preconcurrency import Defaults
@preconcurrency import Foundation
@preconcurrency import OSLog
import SwiftUI

// MARK: - DefaultsManager

@MainActor
final class DefaultsManager: @unchecked Sendable {
    // MARK: - Singleton

    @MainActor static let shared = DefaultsManager()

    // MARK: - Properties

    private let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "DefaultsManager")
    private var observers: [AnyCancellable] = []

    // MARK: - Initialization

    private init() {
        // Set up observers for key preferences
        setupObservers()

        // Debug info to help diagnose issues
        logger.info("DefaultsManager initialized. First launch: \(Defaults[.isFirstLaunch])")
    }

    deinit {}

    // MARK: - Observers Setup

    private func setupObservers() {
        // Watch for general preferences changes
        observers.append(
            Defaults.publisher(.startAtLogin).sink { _ in
                NotificationCenter.default.post(name: .preferencesChanged, object: nil)
            }
        )

        observers.append(
            Defaults.publisher(.showInMenuBar).sink { _ in
                NotificationCenter.default.post(name: .preferencesChanged, object: nil)
            }
        )

        observers.append(
            Defaults.publisher(.showDebugMenu).sink { _ in
                NotificationCenter.default.post(name: .preferencesChanged, object: nil)
            }
        )
    }

    // MARK: - Utility Methods

    /// Get or set debug mode status
    var debugModeEnabled: Bool {
        get { Defaults[.debugModeEnabled] }
        set {
            Defaults[.debugModeEnabled] = newValue
            // Notify about the change
            NotificationCenter.default.post(name: .debugModeChanged, object: nil)
        }
    }

    /// Returns a binding for a specific key
    /// - Parameter key: The defaults key to bind to
    /// - Returns: A binding that can be used in SwiftUI views
    func binding<T>(_ key: Defaults.Key<T>) -> Binding<T> {
        Binding(
            get: { Defaults[key] },
            set: { Defaults[key] = $0 }
        )
    }

    /// Helper method to reset first launch flag - useful for forcing welcome screen to appear
    func resetFirstLaunchFlag() {
        logger.info("Resetting first launch flag to show welcome screen")
        Defaults[.isFirstLaunch] = true

        // Post notification for app to show welcome screen
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil, userInfo: nil)
    }

    /// Request reset of defaults with proper user confirmation
    /// This method posts a notification that should be observed by a UI component
    /// that will then show a confirmation dialog to the user
    func requestResetWithConfirmation() {
        #if DEBUG
            logger.info("Requesting user confirmation for reset to defaults")

            // Post a notification that will be observed by a UI component (typically AppDelegate or MainSettingsCoordinator)
            // which can then show a confirmation dialog to the user
            NotificationCenter.default.post(
                name: .requestResetConfirmation,
                object: self,
                userInfo: nil
            )
        #else
            // In production builds, don't allow resets
            logger.warning("Reset to defaults attempted in production - ignored")
        #endif
    }

    /// Reset to default preferences
    /// This method should only be called after user confirmation or in testing/debugging scenarios
    /// - Parameter skipConfirmation: Set to true to bypass confirmation (for testing only)
    /// - Returns: True if the reset was performed, false if it was cancelled or not allowed
    @discardableResult
    func resetToDefaults(skipConfirmation: Bool = false) -> Bool {
        #if DEBUG
            // Only allow resets in debug mode
            if !skipConfirmation {
                // Log a warning for audit purposes
                logger.warning("CAUTION: Resetting all preferences to defaults")
            }

            // Reset settings that have meaningful default values
            Defaults[.startAtLogin] = false
            Defaults[.showInMenuBar] = true
            Defaults[.hasCompletedOnboarding] = false

            // Reset debug options
            Defaults[.showDebugMenu] = false
            Defaults[.debugModeEnabled] = false

            // Notify observers about all the changes
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)

            logger.info("Reset all preferences to defaults")
            return true
        #else
            // In production builds, don't allow resets
            logger.warning("Reset to defaults attempted in production - ignoring")
            return false
        #endif
    }
}
