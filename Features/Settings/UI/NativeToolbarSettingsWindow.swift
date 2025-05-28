import AppKit
import Combine
import Defaults
import DesignSystem
import SwiftUI

/// Settings window with native NSToolbar implementation
@MainActor
final class NativeToolbarSettingsWindow: NSWindow {
    // MARK: Lifecycle

    init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        self.viewModel = MainSettingsViewModel(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 800),
            styleMask: [.closable, .miniaturizable, .resizable, .titled, .unifiedTitleAndToolbar, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window
        self.title = "CodeLooper"
        self.titlebarAppearsTransparent = false
        self.titleVisibility = .hidden // Hide the default title
        self.identifier = NSUserInterfaceItemIdentifier("settings")
        self.isReleasedWhenClosed = false
        // Use system background color that adapts to light/dark mode
        self.backgroundColor = .windowBackgroundColor

        // Set minimum window size
        self.minSize = NSSize(width: 600, height: 400)

        // Try to reduce spacing with titlebar separator
        self.titlebarSeparatorStyle = .none

        // Setup toolbar
        setupToolbar()

        // Create content
        let contentView = SettingsContentView(
            viewModel: viewModel,
            selectedTab: selectedTabSubject
        )

        self.contentView = NSHostingView(rootView: contentView)
        self.center()
    }

    // MARK: Private

    private var selectedTabSubject = CurrentValueSubject<SettingsTab, Never>(.general)
    private var viewModel: MainSettingsViewModel
    private var toolbarDelegate: SettingsToolbarDelegate?

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.displayMode = .iconOnly
        if #available(macOS 15.0, *) {
            toolbar.allowsDisplayModeCustomization = false
        }

        // Create and set delegate
        toolbarDelegate = SettingsToolbarDelegate(selectedTab: selectedTabSubject)
        toolbar.delegate = toolbarDelegate
        toolbarDelegate?.setToolbar(toolbar)

        self.toolbar = toolbar
        self.toolbarStyle = .unified
    }
}

// MARK: - Custom Views

/// A view that allows window dragging from its area by being transparent to events
private class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        // Return nil to make this view transparent to mouse events
        // This allows the window to handle the drag
        nil
    }
}

/// A stack view that passes through all mouse events to its parent
private class PassThroughStackView: NSStackView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        // Return nil to make this view transparent to mouse events
        nil
    }
}

/// An image view that passes through all mouse events and dims when window is inactive
@MainActor
private class PassThroughImageView: NSImageView {
    // MARK: Lifecycle

    deinit {
        // Cleanup will happen when window is removed
    }

    // MARK: Internal

    override var mouseDownCanMoveWindow: Bool {
        true // Allow window dragging from the icon
    }

    var onClick: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Remove previous observers
        if let observer = becomeKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            becomeKeyObserver = nil
        }
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }

        // Set initial state
        updateAppearance()

        // Observe window focus changes
        if let window {
            becomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }

            resignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Call onClick if it's a single click
        onClick?()
        // Pass the event to super to allow window dragging
        super.mouseDown(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return self to capture mouse events
        let boundsCheck = self.bounds.contains(self.convert(point, from: superview))
        return boundsCheck ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    // MARK: Private

    private var becomeKeyObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?

    private func updateAppearance() {
        if let window, window.isKeyWindow {
            self.alphaValue = 1.0
        } else {
            self.alphaValue = 0.6 // Dimmed when not focused
        }
    }
}

/// A text field that passes through mouse events and dims when window is inactive
@MainActor
private class PassThroughTextField: NSTextField {
    // MARK: Lifecycle

    deinit {
        // Cleanup will happen when window is removed
    }

    // MARK: Internal

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Remove previous observers
        if let observer = becomeKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            becomeKeyObserver = nil
        }
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }

        // Set initial state
        updateAppearance()

        // Observe window focus changes
        if let window {
            becomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }

            resignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }
        }
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    // MARK: Private

    private var becomeKeyObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?

    private func updateAppearance() {
        if let window, window.isKeyWindow {
            self.alphaValue = 1.0
        } else {
            self.alphaValue = 0.6 // Dimmed when not focused
        }
    }
}

// MARK: - Toolbar Item Identifiers

private extension NSToolbarItem.Identifier {
    static let smallSpace = NSToolbarItem.Identifier("smallSpace")
    static let separator = NSToolbarItem.Identifier("separator")
}

// MARK: - Toolbar Delegate

@MainActor
private class SettingsToolbarDelegate: NSObject, NSToolbarDelegate {
    // MARK: Lifecycle

    init(selectedTab: CurrentValueSubject<SettingsTab, Never>) {
        self.selectedTab = selectedTab
        super.init()

        updateTabItems()

        // Observe debug tab changes
        Defaults.publisher(.showDebugTab)
            .sink { [weak self] change in
                self?.showDebugTab = change.newValue
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
            if let iconImage = NSImage(named: NSImage.Name("AppIcon")) {
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
    private var showDebugTab = Defaults[.showDebugTab]
    private var cancellables = Set<AnyCancellable>()
    private weak var toolbar: NSToolbar?

    private func updateTabItems() {
        tabItems = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced]
        if showDebugTab {
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

// MARK: - Toolbar Tab Button View

private struct ToolbarTabButtonView: View {
    // MARK: Internal

    let tab: SettingsTab
    let selectedTab: CurrentValueSubject<SettingsTab, Never>

    var body: some View {
        Button(action: {
            selectedTab.send(tab)
        }) {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(height: 18)

                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        }
        .buttonStyle(.plain)
        .opacity(isWindowKey ? 1.0 : 0.6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onReceive(selectedTab) { newTab in
            isSelected = newTab == tab
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow {
                // Check if this is our settings window
                if window.identifier == NSUserInterfaceItemIdentifier("settings") {
                    isWindowKey = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow {
                // Check if this is our settings window
                if window.identifier == NSUserInterfaceItemIdentifier("settings") {
                    isWindowKey = false
                }
            }
        }
    }

    // MARK: Private

    @State private var isSelected = false
    @State private var isHovered = false
    @State private var isWindowKey = true

    private var iconColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor)
        } else if isHovered {
            Color(NSColor.labelColor)
        } else {
            Color(NSColor.secondaryLabelColor)
        }
    }

    private var textColor: Color {
        if isSelected {
            Color(NSColor.labelColor)
        } else if isHovered {
            Color(NSColor.labelColor)
        } else {
            Color(NSColor.secondaryLabelColor)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor).opacity(0.15)
        } else if isHovered {
            Color(NSColor.controlBackgroundColor)
        } else {
            Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor).opacity(0.3)
        } else {
            Color.clear
        }
    }

    private var borderWidth: CGFloat {
        isSelected ? 1 : 0
    }
}

// MARK: - Settings Tab Extension

private extension SettingsTab {
    var title: String {
        switch self {
        case .general: "General"
        case .supervision: "Supervision"
        case .ruleSets: "Rules"
        case .externalMCPs: "Extensions"
        case .ai: "AI"
        case .advanced: "Advanced"
        case .debug: "Debug"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .supervision: "eye"
        case .ruleSets: "checklist"
        case .externalMCPs: "puzzlepiece.extension"
        case .ai: "brain"
        case .advanced: "wrench.and.screwdriver"
        case .debug: "ladybug"
        }
    }
}

// MARK: - Content View

private struct SettingsContentView: View {
    // MARK: Internal

    let viewModel: MainSettingsViewModel
    let selectedTab: CurrentValueSubject<SettingsTab, Never>

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(spacing: 0) {
                    tabContent
                        .padding(Spacing.xLarge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .withDesignSystem()
        .environmentObject(viewModel)
        .environmentObject(SessionLogger.shared)
        .onChange(of: showDebugTab) { _, newValue in
            if !newValue, currentTab == .debug {
                currentTab = .general
                selectedTab.send(.general)
            }
        }
        .onAppear {
            currentTab = selectedTab.value
        }
        .onReceive(selectedTab) { newTab in
            currentTab = newTab
        }
    }

    // MARK: Private

    @State private var currentTab: SettingsTab = .general

    @Default(.showDebugTab) private var showDebugTab

    @ViewBuilder
    private var tabContent: some View {
        switch currentTab {
        case .general:
            GeneralSettingsView(updaterViewModel: viewModel.updaterViewModel)
        case .supervision:
            CursorSupervisionSettingsView()
        case .ruleSets:
            CursorRuleSetsSettingsView()
        case .externalMCPs:
            ExternalMCPsSettingsView()
        case .ai:
            AISettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .debug:
            DebugSettingsView()
        }
    }
}
