import AppKit
import Defaults
import Foundation
import OSLog

// MARK: - Menu Manager Delegate

@MainActor
protocol MenuManagerDelegate: AnyObject, Sendable {
    // Actions
    func showSettings()
    func toggleStartAtLogin()
    func toggleDebugMenu()
    func showAbout()
}

// MARK: - Menu Manager

@MainActor
final class MenuManager {
    // MARK: - Properties

    // Logger for this class, internal so extensions can access it
    let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "MenuManager")

    var statusItem: NSStatusItem?
    var progressIndicator: NSProgressIndicator?
    weak var delegate: MenuManagerDelegate?

    // Managers for specialized functionality
    var statusIconManager: StatusIconManager?
    var menuBarIconManager: MenuBarIconManager?

    // MARK: - Initialization

    init(delegate: MenuManagerDelegate) {
        self.delegate = delegate
        setupMenuBar()
    }

    // MARK: - MenuBar Setup

    func setupMenuBar() {
        logger.info("Creating status item in menu bar")

        // Add a small delay to ensure the graphics context is fully initialized
        // This avoids the CGContextGetBase_initialized assertion failure
        Task {
            try? await Task.sleep(for: .milliseconds(100))

            // Initialize the status item with variable length (system default)
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            // Initialize the menu bar icon manager (handles dark/light mode automatically)
            menuBarIconManager = MenuBarIconManager(statusItem: statusItem)

            // Configure the status item button
            if let button = statusItem?.button {
                // The icon will be set by the MenuBarIconManager
                button.imagePosition = .imageOnly

                // Set tooltip
                button.toolTip = Constants.appName

                // Create menu
                logger.info("Creating menu")
                refreshMenu()
            } else {
                logger.error("Failed to get status item button")
            }
        }
    }

    @MainActor
    func refreshMenu() {
        guard let statusBar = statusItem, delegate != nil else {
            logger.error("Status item or delegate is nil, can't refresh menu")
            return
        }

        // Use the menu builder to create the menu
        // Using explicit type to resolve ambiguity between Task { } and Task.init
        Task<Void, Never> {
            let menu = await buildApplicationMenu()

            // Set menu to status item
            statusBar.menu = menu
            logger.info("Menu refreshed with improved organization")
        }
    }

    /// Build the main application menu
    @MainActor
    private func buildApplicationMenu() async -> NSMenu {
        let menu = NSMenu()

        // App title
        let titleItem = NSMenuItem(title: Constants.appName, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Start at Login
        let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLoginClicked), keyEquivalent: "")
        startAtLoginItem.target = self
        startAtLoginItem.state = Defaults[.startAtLogin] ? .on : .off
        menu.addItem(startAtLoginItem)

        // Debug menu (if enabled)
        if Defaults[.showDebugMenu] {
            menu.addItem(NSMenuItem.separator())
            let debugItem = NSMenuItem(title: "Toggle Debug Menu", action: #selector(toggleDebugMenuClicked), keyEquivalent: "")
            debugItem.target = self
            menu.addItem(debugItem)
        }

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About \(Constants.appName)", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit \(Constants.appName)", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Menu Actions

    @objc private func settingsClicked() {
        delegate?.showSettings()
    }

    @objc private func toggleStartAtLoginClicked() {
        delegate?.toggleStartAtLogin()
        refreshMenu() // Refresh to update checkmark
    }

    @objc private func toggleDebugMenuClicked() {
        delegate?.toggleDebugMenu()
        refreshMenu() // Refresh to show/hide debug items
    }

    @objc private func aboutClicked() {
        delegate?.showAbout()
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    /// Cleanup resources when the menu manager is no longer needed
    @MainActor
    func cleanup() {
        // Clean up status item if it exists
        if let statusItem {
            logger.info("Cleaning up status item from menu bar")
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }

        // Clean up icon-related resources
        cleanupIconResources()

        logger.info("Menu manager resources cleaned up")
    }

    // MARK: - Icon Management

    /// Clean up icon-related resources
    @MainActor
    private func cleanupIconResources() {
        statusIconManager = nil
        menuBarIconManager = nil
        logger.debug("Icon resources cleaned up")
    }

    /// Highlight the menu bar item briefly
    @MainActor
    func highlightMenuBarItem() {
        guard let button = statusItem?.button else { return }

        // Flash the menu bar icon briefly
        let originalAlpha = button.alphaValue

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            button.animator().alphaValue = 0.3
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                button.animator().alphaValue = originalAlpha
            }
        }
    }

    /// Get the menu bar icon manager
    func getMenuBarIconManager() -> MenuBarIconManager? {
        return menuBarIconManager
    }
}
