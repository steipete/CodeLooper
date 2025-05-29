import AppKit
import Combine
import Defaults
import Diagnostics
import Foundation
import OSLog
import SwiftUI

/**
 Coordinator to manage the welcome window.
 This component handles showing and hiding the welcome window,
 which may be triggered from various parts of the app.
 */
@MainActor
class WelcomeWindowCoordinator: NSObject {
    // MARK: Lifecycle

    override private init() {
        super.init()
        setupNotificationObservers()
    }

    // MARK: Internal

    static let shared = WelcomeWindowCoordinator()

    // Make welcomeWindow internal so it can be directly checked from MenuManager
    var welcomeWindow: NSWindow?

    // MARK: - Window Management

    func showWelcomeWindow() {
        // If window already exists, just bring it to front
        if let window = welcomeWindow {
            window.orderFrontRegardless()
            return
        }

        logger.info("Creating and showing welcome window")

        // Create the welcome window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        window.center()
        window.title = "Welcome to \(Constants.appName)"
        window.isReleasedWhenClosed = false

        // Create and configure the welcome view with required dependencies
        let loginItemManager = LoginItemManager.shared
        // Create the environment for the welcome view
        let appEnvironment = AppEnvironment()

        // Set up the hosting view with proper environment
        window.contentView = NSHostingView(rootView: WelcomeWindowView(
            loginItemManager: loginItemManager
        ).environmentObject(appEnvironment))

        // Add window close handler
        window.delegate = self

        // Store reference and show window
        welcomeWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissWelcomeWindow() {
        logger.info("Dismissing welcome window")
        welcomeWindow?.close()
        welcomeWindow = nil
    }

    // MARK: Private
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Notification Handling

    private func setupNotificationObservers() {
        // Listen for show notifications
        NotificationCenter.default.addObserver(
            forName: .showWelcomeWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.showWelcomeWindow()
            }
        }

        // Listen for dismiss notifications
        NotificationCenter.default.addObserver(
            forName: .dismissWelcomeWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.dismissWelcomeWindow()
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension WelcomeWindowCoordinator: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === welcomeWindow else { return }

        welcomeWindow = nil
        logger.info("Welcome window closed")
    }
}
