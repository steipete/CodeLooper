import AppKit
import Combine
import Defaults
import SwiftUI

// MARK: - Toolbar Item Identifiers

extension NSToolbarItem.Identifier {
    static let smallSpace = NSToolbarItem.Identifier("smallSpace")
    static let separator = NSToolbarItem.Identifier("separator")
}

// MARK: - Toolbar Delegate

@MainActor
class SettingsToolbarDelegate: NSObject, NSToolbarDelegate {
    // MARK: Lifecycle

    init(selectedTab: CurrentValueSubject<SettingsTab, Never>) {
        self.selectedTab = selectedTab
        super.init()

        updateTabItems()

        // Observe debug tab changes
        Defaults.publisher(.debugMode)
            .sink { [weak self] change in
                self?.debugMode = change.newValue
                self?.updateTabItems()
                // Force toolbar to reload
                self?.reloadToolbar()
            }
            .store(in: &cancellables)
    }

    // MARK: Internal

    let selectedTab: CurrentValueSubject<SettingsTab, Never>

    func setToolbar(_ toolbar: NSToolbar) {
        self.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = [NSToolbarItem.Identifier("windowTitle"), .flexibleSpace]
        identifiers += tabItems.map { NSToolbarItem.Identifier($0.rawValue) }
        identifiers.append(.flexibleSpace)
        return identifiers
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = []
        // Add a custom title item first
        identifiers.append(NSToolbarItem.Identifier("windowTitle"))
        identifiers.append(.flexibleSpace) // Push tabs to center
        identifiers += tabItems.map { NSToolbarItem.Identifier($0.rawValue) }
        identifiers.append(.flexibleSpace) // Balance the centering
        return identifiers
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        // Handle custom window title item
        if itemIdentifier.rawValue == "windowTitle" {
            let titleItem = NSToolbarItem(itemIdentifier: itemIdentifier)

            // Create a container view for icon and title
            let containerView = DraggableView()
            containerView.translatesAutoresizingMaskIntoConstraints = false

            // App icon - load from Assets.xcassets
            let iconView = PassThroughImageView()
            if let iconImage = NSImage(named: "loop-color") {
                iconView.image = iconImage
            } else {
                // Fallback to application icon
                iconView.image = NSApp.applicationIconImage
            }
            iconView.isEditable = false
            iconView.imageScaling = .scaleProportionallyDown
            iconView.unregisterDraggedTypes()

            // Make icon clickable to open CodeLooper website
            iconView.onClick = {
                if let url = URL(string: "https://codelooper.app") {
                    NSWorkspace.shared.open(url)
                }
            }

            // Title label
            let titleLabel = PassThroughTextField(labelWithString: "CodeLooper")
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .labelColor
            titleLabel.alignment = .left
            titleLabel.isEditable = false
            titleLabel.isSelectable = false
            titleLabel.isBezeled = false
            titleLabel.drawsBackground = false
            titleLabel.refusesFirstResponder = true

            // Create horizontal stack view using PassThroughStackView
            let stackView = PassThroughStackView(views: [iconView, titleLabel])
            stackView.orientation = .horizontal
            stackView.alignment = .centerY
            stackView.spacing = 8
            stackView.distribution = .fill
            stackView.translatesAutoresizingMaskIntoConstraints = false

            // Add stack view to container
            containerView.addSubview(stackView)

            // Setup constraints
            NSLayoutConstraint.activate([
                // Stack view fills container
                stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

                // Icon size constraints
                iconView.widthAnchor.constraint(equalToConstant: 30),
                iconView.heightAnchor.constraint(equalToConstant: 30),

                // Container height
                containerView.heightAnchor.constraint(equalToConstant: 32),
            ])

            titleItem.view = containerView
            titleItem.label = ""
            titleItem.paletteLabel = "CodeLooper Settings"
            // Make the toolbar item non-interactive
            titleItem.isEnabled = false
            titleItem.autovalidates = false
            return titleItem
        }

        // Handle small space item
        if itemIdentifier == .smallSpace {
            let spaceItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            let spacerView = NSView()
            spacerView.translatesAutoresizingMaskIntoConstraints = false
            spacerView.widthAnchor.constraint(equalToConstant: 10).isActive = true
            spaceItem.view = spacerView
            return spaceItem
        }

        // Handle separator item
        if itemIdentifier == .separator {
            let separatorItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            let separatorView = NSView()
            separatorView.translatesAutoresizingMaskIntoConstraints = false
            separatorView.wantsLayer = true
            separatorView.layer?.backgroundColor = NSColor.separatorColor.cgColor
            separatorView.widthAnchor.constraint(equalToConstant: 1).isActive = true
            separatorView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            separatorItem.view = separatorView
            return separatorItem
        }

        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        // Create the tab button view
        let tabButton = ToolbarTabButtonView(
            tab: tab,
            selectedTab: selectedTab
        )

        let hostingView = NSHostingView(rootView: tabButton)
        hostingView.setFrameSize(hostingView.fittingSize)

        item.view = hostingView
        item.label = tab.title
        item.paletteLabel = tab.title

        // Create menu representation for overflow menu
        let menuItem = NSMenuItem(title: tab.title, action: #selector(selectTab(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = tab.rawValue
        menuItem.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.title)
        item.menuFormRepresentation = menuItem

        return item
    }

    func toolbarWillAddItem(_: Notification) {
        // Handle toolbar item addition if needed
    }

    func toolbarDidRemoveItem(_: Notification) {
        // Handle toolbar item removal if needed
    }

    // This method is called when items are in the overflow menu
    @objc func selectTab(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let tab = SettingsTab(rawValue: identifier) else { return }
        selectedTab.send(tab)
    }

    // MARK: Private

    private var tabItems: [SettingsTab] = []
    private var debugMode = Defaults[.debugMode]
    private var cancellables = Set<AnyCancellable>()
    private weak var toolbar: NSToolbar?

    private func updateTabItems() {
        tabItems = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced]
        if debugMode {
            tabItems.append(.debug)
        }
    }

    private func reloadToolbar() {
        guard let toolbar else { return }

        // Get current selected tab
        let currentSelectedIdentifier = toolbar.selectedItemIdentifier

        // Remove all items and re-add them
        while !toolbar.items.isEmpty {
            toolbar.removeItem(at: 0)
        }

        // Re-add all items
        for identifier in toolbarDefaultItemIdentifiers(toolbar) {
            toolbar.insertItem(withItemIdentifier: identifier, at: toolbar.items.count)
        }

        // Restore selection if it still exists
        if let currentSelectedIdentifier,
           toolbar.items.contains(where: { $0.itemIdentifier == currentSelectedIdentifier })
        {
            toolbar.selectedItemIdentifier = currentSelectedIdentifier
        }
    }
}
