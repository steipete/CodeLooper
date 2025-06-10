import AppKit
import Combine
import Defaults
import SwiftUI
import Diagnostics

/// Manages the macOS status bar item for CodeLooper
@MainActor
final class StatusBarController: NSObject, ObservableObject {
    // MARK: - Singleton
    
    private static var _shared: StatusBarController?
    
    static var shared: StatusBarController {
        if _shared == nil {
            _shared = StatusBarController()
        }
        return _shared!
    }
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies
    private let diagnosticsManager = WindowAIDiagnosticsManager.shared
    private let claudeMonitorService = ClaudeMonitorService.shared
    
    // Settings
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.enableClaudeMonitoring) private var enableClaudeMonitoring
    
    // Debug mode
    private let debugMode = true
    
    // Custom menu window
    private var customMenuWindow: CustomMenuWindow?
    private var isMenuVisible = false
    
    // MARK: - Initialization
    
    private static let logger = Logger(category: .statusBar)
    
    override init() {
        super.init()
        Self.logger.info("StatusBarController initializing...")
        // Delay setup to ensure app is fully initialized
        Task { @MainActor in
            Self.logger.info("Setting up status item and observers...")
            setupStatusItem()
            setupObservers()
        }
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        Self.logger.info("Creating status bar item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            Self.logger.info("Configuring status bar button...")
            button.imagePosition = .imageOnly
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Accessibility
            button.setAccessibilityTitle("CodeLooper")
            button.setAccessibilityRole(.button)
            button.setAccessibilityHelp("Shows CodeLooper supervision status")
            
            updateStatusItemDisplay()
        } else {
            Self.logger.error("Failed to create status bar button")
        }
    }
    
    private func setupObservers() {
        // Observe changes to trigger updates
        diagnosticsManager.$windowStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        claudeMonitorService.$instances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        // Observe settings changes
        Defaults.publisher(.isGlobalMonitoringEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        Defaults.publisher(.enableClaudeMonitoring)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
    }
    
    // MARK: - Update Display
    
    private func updateStatusItemDisplay() {
        guard let button = statusItem?.button else {
            Self.logger.warning("No status item button available for display update")
            return
        }
        Self.logger.info("Updating status item display...")
        
        // Create the content we want to render
        let runningCount = debugMode ? 7 : workingInstancesCount
        let notRunningCount = debugMode ? 4 : notWorkingInstancesCount
        
        Self.logger.info("Rendering status bar with running: \(runningCount), not running: \(notRunningCount)")
        
        // Get the effective tint color from the status bar button
        let effectiveTintColor: Color
        if let button = statusItem?.button {
            // The button's effectiveAppearance tells us if we're in light or dark mode
            let isInDarkMode = button.effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            effectiveTintColor = isInDarkMode ? Color.white : Color.black
        } else {
            // Fallback to primary color
            effectiveTintColor = Color.primary
        }
        
        let content = HStack(spacing: 6) { // Even more spacing
            // Base icon - use effective tint color
            Image("MenuBarTemplateIcon")
                .renderingMode(.template)
                .frame(width: 18, height: 18) // Larger icon
                .foregroundColor(effectiveTintColor) // Use effective tint
            
            // Status indicators with colors
            StatusIndicators(
                runningCount: runningCount,
                notRunningCount: notRunningCount,
                isCompact: true
            )
        }
        .frame(height: 22)
        .padding(.horizontal, 6) // More padding to prevent clipping
        
        // Render to image
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0 // Retina display
        
        if let nsImage = renderer.nsImage {
            // Don't use template for colored badges
            nsImage.isTemplate = false
            button.image = nsImage
            Self.logger.info("Status bar icon updated successfully with size: \(nsImage.size)")
            
            // Restore highlight state if menu is visible
            if isMenuVisible {
                // Force the button to show highlight
                DispatchQueue.main.async {
                    button.highlight(true)
                }
            }
        } else {
            Self.logger.error("Failed to render status bar icon")
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else {
            handleLeftClick(sender)
            return
        }
        
        switch currentEvent.type {
        case .leftMouseUp:
            handleLeftClick(sender)
        case .rightMouseUp:
            handleRightClick(sender)
        default:
            handleLeftClick(sender)
        }
    }
    
    private func handleLeftClick(_ button: NSStatusBarButton) {
        if let window = customMenuWindow, window.isVisible {
            window.hide()
        } else {
            showMenuWindow(relativeTo: button)
        }
    }
    
    private func handleRightClick(_ button: NSStatusBarButton) {
        // Show context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CodeLooper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Clear menu after showing
    }
    
    @objc private func openSettings() {
        MainSettingsCoordinator.shared.showSettings()
    }
    
    private func showMenuWindow(relativeTo button: NSStatusBarButton) {
        Self.logger.info("Showing custom menu window")
        
        // Hide any existing window first
        customMenuWindow?.hide()
        
        // Create the main popover view with all required environment objects
        let popoverView = MainPopoverView()
            .environmentObject(SessionLogger.shared)
            .environmentObject(CursorMonitor.shared)
            .environmentObject(WindowAIDiagnosticsManager.shared)
            .environmentObject(ClaudeMonitorService.shared)
            .environmentObject(RuleCounterManager.shared)
        
        // Wrap in custom container for proper styling
        let containerView = CustomMenuContainer {
            popoverView
        }
        
        // Create new custom window 
        customMenuWindow = CustomMenuWindow(contentView: containerView)
        
        // Set up callback to unhighlight button when window hides
        customMenuWindow?.onHide = { [weak self, weak button] in
            self?.isMenuVisible = false
            button?.highlight(false)
        }
        
        // Show the custom window
        customMenuWindow?.show(relativeTo: button)
        
        // Highlight the button after window is shown
        isMenuVisible = true
        
        // Delay the highlight to ensure window is visible first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak button] in
            button?.highlight(true)
        }
    }
    
    // MARK: - Computed Properties
    
    private var workingInstancesCount: Int {
        var count = 0
        
        // Count Cursor windows
        for (_, windowInfo) in diagnosticsManager.windowStates where windowInfo.isLiveWatchingEnabled {
            if windowInfo.lastAIAnalysisStatus == .working {
                count += 1
            }
        }
        
        // Count Claude instances if enabled
        if enableClaudeMonitoring {
            for instance in claudeMonitorService.instances {
                if instance.currentActivity.type != .idle {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    private var notWorkingInstancesCount: Int {
        var count = 0
        
        // Count Cursor windows
        for (_, windowInfo) in diagnosticsManager.windowStates where windowInfo.isLiveWatchingEnabled {
            if windowInfo.lastAIAnalysisStatus == .notWorking || windowInfo.lastAIAnalysisStatus == .error {
                count += 1
            }
        }
        
        // Count Claude instances if enabled
        if enableClaudeMonitoring {
            for instance in claudeMonitorService.instances {
                if instance.currentActivity.type == .idle {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    // MARK: - Public Methods
    
    func hideMenuBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
    
    func showMenuBar() {
        if statusItem == nil {
            setupStatusItem()
        }
    }
    
}

// MARK: - Notification Names

extension Notification.Name {
    static let showCodeLooperMenu = Notification.Name("showCodeLooperMenu")
}