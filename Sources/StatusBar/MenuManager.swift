import AppKit
import SwiftUI // Added for NSHostingController and MainPopoverView
import Combine // Added for Combine framework elements
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

    let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "MenuManager")

    var statusItem: NSStatusItem?
    // var progressIndicator: NSProgressIndicator? // Not used in current spec for popover
    weak var delegate: MenuManagerDelegate?

    private var popover: NSPopover
    private var eventMonitor: EventMonitor? // For closing popover on outside click
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(delegate: MenuManagerDelegate) {
        self.delegate = delegate
        
        // Initialize NSPopover BEFORE setupMenuBar, as button action will need it.
        self.popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 550) // Match MainPopoverView frame
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MainPopoverView())

        setupMenuBar()

        // Event monitor for popover dismissal - Initialized here as popover exists
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover(sender: event)
            }
        }
        
        // Visibility observation for statusItem
        Defaults.publisher(.showInMenuBar)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.statusItem?.isVisible = change.newValue
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .menuBarVisibilityChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let visible = notification.userInfo?["visible"] as? Bool {
                    self?.statusItem?.isVisible = visible
                }
            }
            .store(in: &cancellables)
        
        // Observe tint color changes from AppIconStateController
        AppIconStateController.shared.$currentTintColor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTintColor in
                self?.statusItem?.button?.contentTintColor = newTintColor
                self?.logger.info("Applied tint color to status item: \(String(describing: newTintColor))")
            }
            .store(in: &cancellables)
    }

    // MARK: - MenuBar Setup & Popover Management

    func setupMenuBar() {
        logger.info("Creating status item in menu bar")

        Task {
            try? await Task.sleep(for: .milliseconds(100))

            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) // Use squareLength for icon-only
            statusItem?.isVisible = Defaults[.showInMenuBar] // Set initial visibility

            if let button = statusItem?.button {
                // Set the template icon
                button.image = NSImage(named: "MenuBarTemplateIcon")
                button.image?.isTemplate = true
                
                // Set initial tint color from AppIconStateController
                button.contentTintColor = AppIconStateController.shared.currentTintColor
                
                // Configure button properties
                button.action = #selector(togglePopover) // Action is to toggle popover
                button.target = self
                button.toolTip = Constants.appName
                
                logger.info("Configured status item with template icon and initial tint color: \(String(describing: button.contentTintColor))")
            } else {
                logger.error("Failed to get status item button")
            }
            
            // Menu is now secondary, can be set up to be shown on right-click or via a popover button if needed.
            // For now, primary interaction is popover. Right-click for menu:
            if let button = statusItem?.button {
                 button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // Ensure right click can also trigger actions
            }
            refreshMenu() // Keep menu for right-click or alternative access
        }
    }
    
    @objc private func togglePopover(_ sender: Any?) {
        // If the event is a right-click, show the context menu, otherwise toggle popover.
        // This makes the menu accessible again.
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem?.menu = nil // Temporarily remove menu to allow button to show its own menu
            statusItem?.menu = statusItem?.menu ?? NSMenu() // Use menu property instead of deprecated popUpMenu
            // Re-assign the menu if it was programmatically built, or ensure it's always set for future right-clicks.
            // For simplicity, we assume refreshMenu() keeps it updated if needed.
            // Or, more robustly, store the built menu and re-assign it.
            Task { await self.statusItem?.menu = buildApplicationMenu() }
            return
        }
        
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover(sender: nil)
        } else {
            // Ensure any context menu is dismissed before showing popover
            statusItem?.menu?.cancelTracking()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
            button.isHighlighted = true
        }
    }

    private func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
        if let button = statusItem?.button {
            button.isHighlighted = false
        }
    }

    @MainActor
    func refreshMenu() {
        guard let statusBar = statusItem else {
            logger.error("Status item is nil, can't refresh menu")
            return
        }

        Task<Void, Never> {
            let menu = await buildApplicationMenu()
            statusBar.menu = menu // Set the menu for right-click
            logger.info("Menu refreshed for right-click access")
        }
    }

    @MainActor
    private func buildApplicationMenu() async -> NSMenu {
        let menu = NSMenu()

        // App title is not conventional for status bar item menus
        // menu.addItem(NSMenuItem(title: Constants.appName, action: nil, keyEquivalent: ""))
        // menu.addItem(NSMenuItem.separator())

        // Popover Item - Or rely on left-click only
        // let showAppItem = NSMenuItem(title: "Show CodeLooper", action: #selector(togglePopover(_:)), keyEquivalent: "")
        // showAppItem.target = self
        // menu.addItem(showAppItem)
        // menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let startAtLoginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLoginClicked),
            keyEquivalent: ""
        )
        startAtLoginItem.target = self
        startAtLoginItem.state = Defaults[.startAtLogin] ? .on : .off
        menu.addItem(startAtLoginItem)

        if Defaults[.showDebugMenu] {
            menu.addItem(NSMenuItem.separator())
            let debugItem = NSMenuItem(
                title: "Toggle Debug Menu",
                action: #selector(toggleDebugMenuClicked),
                keyEquivalent: ""
            )
            debugItem.target = self
            menu.addItem(debugItem)
            
            // Add Show Log Window to debug menu
            let showLogWindowItem = NSMenuItem(
                title: "Show Session Log Window",
                action: #selector(showLogWindowClicked),
                keyEquivalent: ""
            )
            showLogWindowItem.target = self
            menu.addItem(showLogWindowItem)
        }

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About \(Constants.appName)",
            action: #selector(aboutClicked),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit \(Constants.appName)",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Menu Actions

    @objc
    private func settingsClicked() {
        delegate?.showSettings()
    }

    @objc
    private func toggleStartAtLoginClicked() {
        delegate?.toggleStartAtLogin()
        refreshMenu() 
    }

    @objc
    private func toggleDebugMenuClicked() {
        delegate?.toggleDebugMenu()
        refreshMenu() 
    }

    @objc
    private func aboutClicked() {
        delegate?.showAbout()
    }

    @MainActor
    func cleanup() {
        if let statusItem {
            logger.info("Cleaning up status item from menu bar")
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        eventMonitor?.stop()
        logger.info("Menu manager resources cleaned up")
    }
    
    
    @objc
    private func showLogWindowClicked() {
        logger.info("Debug menu: Show Log Window clicked. Opening settings as Log view is a tab there.")
        delegate?.showSettings()
    }

    @objc
    private func quitClicked() {
        logger.info("Quit menu item clicked. Terminating application.")
        NSApp.terminate(nil)
    }
}

// Helper for monitoring outside clicks to close popover
public class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}

