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

    let logger = Logger(label: "MenuManager", category: .statusBar)

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

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) // Use variableLength for icon + text
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
            
            // Set initial cursor count
            updateCursorInstanceCount()
            
            logger.info("Configured status item with template icon and initial tint color: \(String(describing: button.contentTintColor))")
        } else {
            logger.error("Failed to get status item button")
        }
        
        // Menu is only shown on right-click via togglePopover, not automatically set
        // For now, primary interaction is popover. Right-click for menu:
        if let button = statusItem?.button {
             button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // Ensure right click can also trigger actions
        }
        
        // Subscribe to cursor monitor updates to update the count
        CursorMonitor.shared.$monitoredInstances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCursorInstanceCount()
            }
            .store(in: &cancellables)
    }
    
    @objc private func togglePopover(_ sender: Any?) {
        // If the event is a right-click, show the context menu, otherwise toggle popover.
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            // Build and show the menu for right-click
            Task { 
                let menu = await buildApplicationMenu()
                // Set the menu temporarily for right-click and then remove it
                statusItem?.menu = menu
                // The menu will automatically show for the right-click
                // Remove the menu after a short delay to avoid interfering with left-clicks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.statusItem?.menu = nil
                }
            }
            return
        }
        
        guard let button = statusItem?.button else { 
            logger.error("No button available for popover toggle")
            return 
        }
        
        if popover.isShown {
            closePopover(sender: nil)
        } else {
            logger.info("Showing popover for left-click")
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
        // Menu is built dynamically on right-click via togglePopover
        // No need to set a permanent menu since it conflicts with the popover
        logger.info("Menu refresh requested - menu will be built on right-click")
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

    private func updateCursorInstanceCount() {
        guard let button = statusItem?.button else { return }
        
        let count = CursorMonitor.shared.monitoredInstances.count
        
        // Create attributed string with icon and count
        let attributedString = NSMutableAttributedString()
        
        // Add the icon as an attachment
        if let image = NSImage(named: "MenuBarTemplateIcon") {
            let attachment = NSTextAttachment()
            attachment.image = image
            // Scale the image to match text height
            let iconSize = NSSize(width: 16, height: 16)
            attachment.bounds = NSRect(x: 0, y: -2, width: iconSize.width, height: iconSize.height)
            attributedString.append(NSAttributedString(attachment: attachment))
        }
        
        // Add space and count text
        let countText = count > 0 ? " \(count)" : " 0"
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 14),
            .foregroundColor: NSColor.controlTextColor
        ]
        attributedString.append(NSAttributedString(string: countText, attributes: textAttributes))
        
        // Set the attributed string as the button title
        button.attributedTitle = attributedString
        button.image = nil // Clear the image since we're using it in the attributed string
        
        logger.debug("Updated menu bar cursor count to: \(count)")
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

