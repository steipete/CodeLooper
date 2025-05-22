import Defaults
import Foundation
import Observation
import OSLog
import SwiftUI

/// ViewModel for the Settings view - simplified for CodeLooper
@MainActor
@Observable
public final class MainSettingsViewModel {
    // MARK: - Properties

    // Logger instance
    private let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "MainSettingsViewModel")

    // Dependencies
    private let loginItemManager: LoginItemManager

    // Using stored properties instead of computed properties to ensure SwiftUI observes changes
    private(set) var startAtLogin: Bool = Defaults[.startAtLogin]
    private(set) var showInMenuBar: Bool = Defaults[.showInMenuBar]
    private(set) var showWelcomeScreen: Bool = Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen]

    // Explicit setter methods that update both the stored property and UserDefaults
    func setStartAtLogin(_ newValue: Bool) {
        startAtLogin = newValue
        Defaults[.startAtLogin] = newValue
    }

    func setShowInMenuBar(_ newValue: Bool) {
        showInMenuBar = newValue
        Defaults[.showInMenuBar] = newValue
    }

    func setShowWelcomeScreen(_ newValue: Bool) {
        showWelcomeScreen = newValue
        if newValue {
            Defaults[.isFirstLaunch] = true
            Defaults[.showWelcomeScreen] = true
        } else {
            // When toggled off, only update showWelcomeScreen, keep isFirstLaunch
            Defaults[.showWelcomeScreen] = false
        }
    }

    var showDebugMenu: Bool {
        get { Defaults[.showDebugMenu] }
        set { Defaults[.showDebugMenu] = newValue }
    }

    // MARK: - Initialization

    /// Initialize with required services
    public init(loginItemManager: LoginItemManager) {
        self.loginItemManager = loginItemManager

        // Initialize our stored properties from UserDefaults
        startAtLogin = Defaults[.startAtLogin]
        showInMenuBar = Defaults[.showInMenuBar]
        showWelcomeScreen = Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen]

        logger.info("MainSettingsViewModel initialized for CodeLooper")
    }

    // MARK: - Settings Management

    /// Update start at login setting
    public func updateStartAtLogin(_ enabled: Bool) {
        // Log the current state before attempting to change
        logger.info("Updating startAtLogin setting from \(self.startAtLogin) to \(enabled)")

        // Update our stored property first for UI responsiveness
        self.startAtLogin = enabled

        // Update the login item status in the system
        let success = loginItemManager.setStartAtLogin(enabled: enabled)

        // Log the result
        if success {
            logger.info("Successfully updated startAtLogin system setting to: \(enabled)")
        } else {
            logger.warning("Failed to update startAtLogin system setting to: \(enabled)")

            // If the system update failed, update property and UserDefaults to reflect actual state
            let actualState = loginItemManager.startsAtLogin()
            self.startAtLogin = actualState
            logger.info("Corrected startAtLogin to match system: \(actualState)")
        }
    }

    /// Update show in menu bar setting
    public func updateShowInMenuBar(_ enabled: Bool) {
        // Log the current state for debugging
        logger.info("Updating showInMenuBar setting from \(self.showInMenuBar) to \(enabled)")

        // Update stored property for UI responsiveness
        self.showInMenuBar = enabled

        // Post a notification to inform that menu bar visibility changed
        logger.info("Menu bar visibility changed to: \(enabled)")

        // Use Task with sleep for consistency with Swift concurrency model
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            NotificationCenter.default.post(
                name: .menuBarVisibilityChanged,
                object: nil,
                userInfo: ["visible": enabled]
            )
        }
    }

    /// Update show welcome screen setting
    public func updateShowWelcomeScreen(_ enabled: Bool) {
        // Log the current state before attempting to change
        logger.info("Updating showWelcomeScreen setting from \(self.showWelcomeScreen) to \(enabled)")

        // Update stored property for UI responsiveness
        self.showWelcomeScreen = enabled

        if enabled {
            // If enabling welcome screen, also reset onboarding flag
            Defaults[.hasCompletedOnboarding] = false

            // Force sync these values to UserDefaults.standard as well for components that read directly
            UserDefaults.standard.set(true, forKey: Defaults.Keys.isFirstLaunch.name)
            UserDefaults.standard.set(false, forKey: Defaults.Keys.hasCompletedOnboarding.name)
            UserDefaults.standard.set(true, forKey: Defaults.Keys.showWelcomeScreen.name)

            logger.info("Set to show welcome screen on next launch (all defaults updated)")

            // Post notification to inform app of this significant change
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        } else {
            // Even when disabling, make sure UserDefaults.standard is in sync
            UserDefaults.standard.set(false, forKey: Defaults.Keys.showWelcomeScreen.name)
            logger.info("Disabled welcome screen for next launch")
        }
    }

    /// Toggle debug menu
    public func toggleDebugMenu() {
        // No need to explicitly set Defaults since showDebugMenu is a computed property
        // that will handle the UserDefaults update
        showDebugMenu.toggle()
        NotificationCenter.default.post(name: .highlightMenuBarIcon, object: nil)
    }

    /// Reset settings to defaults
    public func resetToDefaults() async {
        // DefaultsManager.shared is MainActor-isolated
        if DefaultsManager.shared.resetToDefaults() {
            await refreshSettings()
        }
    }

    /// Method to refresh all settings
    public func refreshSettings() async {
        // Update our stored properties from UserDefaults
        setStartAtLogin(Defaults[.startAtLogin])
        setShowInMenuBar(Defaults[.showInMenuBar])
        setShowWelcomeScreen(Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen])

        logger.info("Settings refreshed")
    }
}