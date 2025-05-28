import SwiftUI
import AppKit
import DesignSystem
import Defaults
import Combine

/// Settings window with native NSToolbar implementation
@MainActor
final class NativeToolbarSettingsWindow: NSWindow {
    private var selectedTabSubject = CurrentValueSubject<SettingsTab, Never>(.general)
    private var viewModel: MainSettingsViewModel
    private var toolbarDelegate: SettingsToolbarDelegate?
    
    init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        self.viewModel = MainSettingsViewModel(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
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
        
        // Try to reduce spacing with titlebar separator
        if #available(macOS 11.0, *) {
            self.titlebarSeparatorStyle = .none
        }
        
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
    
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
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
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return nil to make this view transparent to mouse events
        // This allows the window to handle the drag
        return nil
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
    let selectedTab: CurrentValueSubject<SettingsTab, Never>
    private var tabItems: [SettingsTab] = []
    private var showDebugTab = Defaults[.showDebugTab]
    private var cancellables = Set<AnyCancellable>()
    private weak var toolbar: NSToolbar?
    
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
    
    func setToolbar(_ toolbar: NSToolbar) {
        self.toolbar = toolbar
    }
    
    private func updateTabItems() {
        tabItems = [.general, .supervision, .ruleSets, .externalMCPs, .ai, .advanced]
        if showDebugTab {
            tabItems.append(.debug)
        }
        tabItems.append(.about)
    }
    
    private func reloadToolbar() {
        guard let toolbar = toolbar else { return }
        
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
        if let currentSelectedIdentifier = currentSelectedIdentifier,
           toolbar.items.contains(where: { $0.itemIdentifier == currentSelectedIdentifier }) {
            toolbar.selectedItemIdentifier = currentSelectedIdentifier
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = [NSToolbarItem.Identifier("windowTitle"), .flexibleSpace]
        identifiers += tabItems.map { NSToolbarItem.Identifier($0.rawValue) }
        identifiers.append(.flexibleSpace)
        return identifiers
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = []
        // Add a custom title item first
        identifiers.append(NSToolbarItem.Identifier("windowTitle"))
        identifiers.append(.flexibleSpace) // Push tabs to center
        identifiers += tabItems.map { NSToolbarItem.Identifier($0.rawValue) }
        identifiers.append(.flexibleSpace) // Balance the centering
        return identifiers
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // Handle custom window title item
        if itemIdentifier.rawValue == "windowTitle" {
            let titleItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            // Create a container view for icon and title
            let containerView = DraggableView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            // App icon - load from Assets.xcassets
            let iconView = NSImageView()
            if let iconImage = NSImage(named: NSImage.Name("AppIcon")) {
                iconView.image = iconImage
            } else {
                // Fallback to application icon
                iconView.image = NSApp.applicationIconImage
            }
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.isEditable = false
            
            // Title label
            let titleLabel = NSTextField(labelWithString: "CodeLooper")
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .labelColor
            titleLabel.alignment = .left
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.isEditable = false
            titleLabel.isSelectable = false
            titleLabel.isBezeled = false
            titleLabel.drawsBackground = false
            
            // Add subviews
            containerView.addSubview(iconView)
            containerView.addSubview(titleLabel)
            
            // Setup constraints
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 30),
                iconView.heightAnchor.constraint(equalToConstant: 30),
                
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                
                containerView.heightAnchor.constraint(equalToConstant: 32)
            ])
            
            titleItem.view = containerView
            titleItem.label = ""
            titleItem.paletteLabel = "Window Title"
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
    
    func toolbarWillAddItem(_ notification: Notification) {
        // Handle toolbar item addition if needed
    }
    
    func toolbarDidRemoveItem(_ notification: Notification) {
        // Handle toolbar item removal if needed
    }
    
    // This method is called when items are in the overflow menu
    @objc func selectTab(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let tab = SettingsTab(rawValue: identifier) else { return }
        selectedTab.send(tab)
    }
}

// MARK: - Toolbar Tab Button View

private struct ToolbarTabButtonView: View {
    let tab: SettingsTab
    let selectedTab: CurrentValueSubject<SettingsTab, Never>
    @State private var isSelected = false
    @State private var isHovered = false
    
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
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .onReceive(selectedTab) { newTab in
            isSelected = newTab == tab
        }
    }
    
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
        case .general: return "General"
        case .supervision: return "Supervision"
        case .ruleSets: return "Rules"
        case .externalMCPs: return "Extensions"
        case .ai: return "AI"
        case .advanced: return "Advanced"
        case .debug: return "Debug"
        case .about: return "About"
        default: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .supervision: return "eye"
        case .ruleSets: return "checklist"
        case .externalMCPs: return "puzzlepiece.extension"
        case .ai: return "brain"
        case .advanced: return "wrench.and.screwdriver"
        case .debug: return "ladybug"
        case .about: return "info.circle"
        default: return "questionmark"
        }
    }
}

// MARK: - Content View

private struct SettingsContentView: View {
    let viewModel: MainSettingsViewModel
    let selectedTab: CurrentValueSubject<SettingsTab, Never>
    @State private var currentTab: SettingsTab = .general
    @Default(.showDebugTab) private var showDebugTab
    
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
            withAnimation {
                currentTab = newTab
            }
        }
    }
    
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
        case .about:
            AboutSettingsView()
        default:
            EmptyView()
        }
    }
}
