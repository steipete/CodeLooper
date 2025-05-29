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