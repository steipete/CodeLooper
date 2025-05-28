import AppKit
import Defaults
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
        if let welcomeWindow = self.windowManager?.welcomeWindowController?.window {
            return welcomeWindow
        }

        // Otherwise look for settings window
        return NSApp.windows.first { $0.title.contains("Settings") || $0.title.contains("Preferences") }
    }

    /// AppleScript handler to show the welcome window
    @objc(showWelcomeWindowForScripting)
    func showWelcomeWindowForScripting() {
        logger.info("AppleScript called: show welcome window")
        // Use windowManager to show the welcome window
        self.windowManager?.showWelcomeWindow()
    }

    /// AppleScript handler to show the settings window
    @objc(showSettingsWindowForScripting)
    func showSettingsWindowForScripting() {
        logger.info("AppleScript called: show settings window")
        Task { @MainActor in
            MainSettingsCoordinator.shared.showSettings()
        }
    }

    /// AppleScript handler for basic app operations
    @objc(performBasicOperationForScripting)
    func performBasicOperationForScripting() {
        logger.info("AppleScript called: perform basic operation")
        // Basic operation placeholder - can be extended as needed
    }

    // Example: Bring the welcome window to the front if it exists
    func handleShowWelcomeCommand(_: NSScriptCommand) -> Any? {
        logger.info("AppleScript command: Show Welcome")
        // Ensure this is called on the main thread
        DispatchQueue.main.async {
            // Access welcomeWindowController through windowManager
            if let welcomeWindow = self.windowManager?.welcomeWindowController?.window {
                NSApp.activate(ignoringOtherApps: true)
                welcomeWindow.makeKeyAndOrderFront(nil)
            } else {
                // If window doesn't exist, create and show it
                self.windowManager?.showWelcomeWindow()
            }
        }
        return nil // Or an appropriate result
    }

    func handleGetMonitoringStatusCommand(_: NSScriptCommand) -> Any? {
        // Implementation of handleGetMonitoringStatusCommand
        logger.info("AppleScript command: Get Monitoring Status")
        return Defaults[.isGlobalMonitoringEnabled]
    }
}
