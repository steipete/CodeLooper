import AppKit
import Foundation

/// AppDelegate extension for AppleScript support
@MainActor
extension AppDelegate {
    /// Setup AppleScript event handling
    func setupAppleScriptSupport() {
        logger.info("Setting up AppleScript support")

        // Register for Apple events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )

        // Initialize the window position manager
        _ = WindowPositionManager.shared

        logger.info("AppleScript support initialized")
    }

    /// Handle Apple events
    @objc
    func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        logger.info("Received Apple event: \(event.eventClass) / \(event.eventID)")

        // Handle specific event types as needed
        switch (event.eventClass, event.eventID) {
        case (AEEventClass(kCoreEventClass), AEEventID(kAEOpenApplication)):
            logger.info("Handling open application event")
            // Nothing special needed for open application

        default:
            logger.info("Unhandled Apple event: \(event.eventClass) / \(event.eventID)")
        }
    }

    /// Clean up AppleScript support
    func cleanupAppleScriptSupport() {
        logger.info("Cleaning up AppleScript support")

        // Unregister for Apple events
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }
}

// MARK: - Scripting Support

@MainActor
extension AppDelegate {
    /// Get the main application window for scripting
    @objc
    func scriptableMainWindow() -> NSWindow? {
        // Try to get the welcome window first
        if let welcomeWindow = welcomeWindowController?.window {
            return welcomeWindow
        }

        // Otherwise look for settings window
        return NSApp.windows.first { $0.title.contains("Settings") || $0.title.contains("Preferences") }
    }

    /// AppleScript handler to show the welcome window
    @objc(showWelcomeWindowForScripting)
    func showWelcomeWindowForScripting() {
        logger.info("AppleScript called: show welcome window")
        // Post notification to show welcome window
        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
    }

    /// AppleScript handler to show the settings window
    @objc(showSettingsWindowForScripting)
    func showSettingsWindowForScripting() {
        logger.info("AppleScript called: show settings window")
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    /// AppleScript handler for basic app operations
    @objc(performBasicOperationForScripting)
    func performBasicOperationForScripting() {
        logger.info("AppleScript called: perform basic operation")
        // Basic operation placeholder - can be extended as needed
    }
}
