import AppKit
import Defaults
import os.log
import SwiftUI

// Extension to force show the welcome window once on app startup
/// Exposed C function to show the welcome window on startup for testing/debugging
@_cdecl("showWelcomeWindowOnStartup")
@MainActor
public func showWelcomeWindowOnStartup() {
    forceTriggerWelcomeScreen()
}

/// Function to trigger showing the welcome screen
/// This can be called from other parts of the app
/// Swift 6 safe with proper concurrency annotations
@MainActor
public func forceTriggerWelcomeScreen() {
    // Force reset the onboarding flags - we know we're on the main actor here
    // so we can safely access Defaults
    Defaults[.hasCompletedOnboarding] = false
    Defaults[.isFirstLaunch] = true

    // Log the action
    let logger = Logger(label: "WelcomeScreen", category: .ui)
    logger.info("Setting flags and posting notification to show welcome window")

    // Post notification to show welcome window from main actor
    NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)

    // Also post the standard settings notification which will pick up the first launch flag
    NotificationCenter.default.post(name: .showSettingsWindow, object: nil)

    // Also post the notification after a delay in case the first one is missed
    // We can use Task with sleep instead of DispatchQueue to stay on MainActor
    // Adding @MainActor to the closure to ensure Swift 6 concurrency safety
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500)) // 0.5 seconds
        logger.info("Posting delayed notification to show welcome window")

        // Post notification again
        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil)

        // Add a second delay for final attempt
        try? await Task.sleep(for: .milliseconds(500)) // Another 0.5 seconds
        logger.info("Forcing app to foreground and posting notification again")

        // Force app to foreground
        NSApp.activate(ignoringOtherApps: true)

        // Post notification again as a final attempt
        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
    }
}
