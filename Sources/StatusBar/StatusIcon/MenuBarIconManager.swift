import AppKit
import Foundation
import OSLog

@_exported import class Foundation.Timer

// Import required Foundation types
@_exported import struct Foundation.URL

// StatusIconState and IconAnimator are already part of the same module
// No need to import them explicitly

/// MenuBarIconManager provides status icon handling for the menu bar status item,
/// with full support for different states, dark/light mode, and animations.
@MainActor
class MenuBarIconManager {
    // MARK: - Properties

    private let logger = Logger(label: "MenuBarIconManager", category: .statusBar)
    weak var statusItem: NSStatusItem?
    private var appearanceObserver: Any?

    // Current state of the icon
    private var currentState: StatusIconState = .idle

    // Animator for icon animations
    private var iconAnimator: IconAnimator?

    // Icon cache for different states and appearance modes
    private var iconCache: [StatusIconState: [NSAppearance.Name: NSImage]] = [:]

    // MARK: - Initialization

    init(statusItem: NSStatusItem?) {
        self.statusItem = statusItem

        // Ensure we have a valid status item with a button before proceeding
        guard let statusItem,
            statusItem.button != nil
        else {
            logger.warning("Initializing with nil status item or button - will defer initialization")
            setupAppearanceObserver()
            return
        }

        // Initialize the animator
        iconAnimator = IconAnimator(statusItem: statusItem)

        setupAppearanceObserver()

        // Add a more substantial delay for the initial icon update
        // This is crucial to avoid the CGContextGetBase_initialized assertion failure
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            // Force initial state to idle
            currentState = .idle

            // Double check button is available before updating
            if statusItem.button != nil {
                updateIcon(for: .idle)
                logger.info("Menu bar icon initialized successfully with delay")
            } else {
                logger.warning("Button still nil after delay - icon update deferred")
            }
        }
    }

    deinit {
        // Use MainActor.assumeIsolated since we can't use async in deinit
        MainActor.assumeIsolated {
            removeAppearanceObserver()
            iconAnimator?.cleanup()
        }
    }

    // MARK: - Public Methods

    /// Sets the menu bar icon state
    /// - Parameter state: The new state for the icon
    func setState(_ state: StatusIconState) {
        // Check if we need to defer this update (during initialization)
        if statusItem?.button == nil {
            logger.info("Deferring state change to \(state.rawValue) - button not ready")

            // Store the state change for later
            currentState = state

            // Schedule a retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }

                // Check if button is now available
                if statusItem?.button != nil {
                    logger.info("Applying deferred state change to \(state.rawValue)")
                    updateIcon(for: state)
                } else {
                    logger.warning("Button still unavailable after delay")
                }
            }

            return
        }

        // Stop any ongoing animation
        iconAnimator?.stopAnimating()

        currentState = state

        // Start animation for syncing state, otherwise just update the icon
        if state == .syncing {
            // Use dispatch async to avoid any synchronization issues
            DispatchQueue.main.async { [weak self] in
                self?.startSyncingAnimation()
            }
        } else {
            // Use dispatch async to avoid any synchronization issues
            DispatchQueue.main.async { [weak self] in
                self?.updateIcon(for: state)
            }
        }
    }

    // Legacy methods for compatibility
    func setActiveIcon() { setState(.authenticated) }
    func setInactiveIcon() { setState(.unauthenticated) }
    func setUploadingIcon() { setState(.syncing) }
    func setNormalIcon() { setState(.idle) }

    /// Stops any ongoing animations and cleans up resources
    func cleanup() {
        iconAnimator?.cleanup()
        iconCache.removeAll()
    }

    // MARK: - Private Methods

    /// Start the syncing animation
    private func startSyncingAnimation() {
        guard let button = statusItem?.button else {
            logger.warning("Cannot start syncing animation - button is nil")

            // Schedule a retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }

                // If we're still in syncing state and the button is now available, try again
                if currentState == .syncing, statusItem?.button != nil {
                    startSyncingAnimation()
                }
            }

            return
        }

        // Ensure we have a valid animator
        guard let iconAnimator else {
            logger.warning("Cannot start syncing animation - animator is nil")
            return
        }

        // Get the base image for animation - first try to get the idle state icon
        let baseImage: NSImage

        // Try using the real app icon for the base (not syncing state icon)
        if let idleIcon = loadStatusBarIcon(for: .idle, appearance: getCurrentAppearance()) {
            baseImage = idleIcon
            logger.info("Using idle icon as base for animation")
        } else {
            // If no idle icon is available, load menu bar icon directly
            if let menuBarIcon = NSImage.loadResourceImage(named: Constants.menuBarIconName) {
                baseImage = menuBarIcon
                logger.info("Using menu bar icon as base for animation")
            } else {
                // Last resort - create a default icon
                baseImage = createDefaultIcon()
                logger.warning("Using default icon as base for animation - icon resources may be missing")
            }
        }

        // Set the tooltip
        button.toolTip = StatusIconState.syncing.tooltipText

        // Create animation frames with appropriate dot color based on appearance
        let isDarkMode = getCurrentAppearance() == .darkAqua
        let dotColor = isDarkMode ? NSColor.white : NSColor.black
        let frames = IconAnimator.createSyncingAnimationFrames(baseImage: baseImage, dotColor: dotColor)

        // Start the animation with a small delay to ensure context is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak iconAnimator] in
            guard let self, let iconAnimator else { return }

            iconAnimator.startAnimating(
                frames: frames,
                interval: 0.3,
                tooltipFormat: "CodeLooper - Syncing Contacts... %d%%"
            ) { [weak self] in
                // When animation is stopped, reset to idle state
                self?.setState(.idle)
            }
        }
    }

    /// Sets up an observer to detect appearance changes (dark/light mode)
    private func setupAppearanceObserver() {
        logger.info("Setting up appearance observer for menu bar icon")

        // Use the notification for appearance changes
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("System appearance changed, updating icon")
                self?.handleAppearanceChange()
            }
        }
    }

    /// Handle system appearance change
    private func handleAppearanceChange() {
        // Clear the icon cache when appearance changes
        iconCache.removeAll()

        // If we're currently animating, restart the animation with the new appearance
        if iconAnimator?.isCurrentlyAnimating == true, currentState == .syncing {
            // Restart the animation with proper colors for the new appearance
            DispatchQueue.main.async { [weak self] in
                self?.startSyncingAnimation()
            }
            return
        }

        // Otherwise just update the icon for the current state
        updateIcon(for: currentState)
    }

    /// Removes the appearance observer
    private func removeAppearanceObserver() {
        if let observer = appearanceObserver {
            NotificationCenter.default.removeObserver(observer)
            appearanceObserver = nil
        }
    }

    /// Get the current effective appearance
    private func getCurrentAppearance() -> NSAppearance.Name {
        let appearance = NSApp.effectiveAppearance

        // Check if we're in dark mode
        if let name = appearance.bestMatch(from: [.darkAqua, .aqua]) {
            return name
        }

        // Default to aqua if we can't determine
        return .aqua
    }

    /// Updates the status item button with the appropriate icon for the given state
    private func updateIcon(for state: StatusIconState) {
        guard let statusItem,
            let button = statusItem.button
        else {
            logger.warning("Status item or button is nil, can't update icon")
            return
        }

        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateIcon(for: state)
            }
            return
        }

        // Load the icon for the current state and appearance
        let icon = getIconForCurrentState() ?? createDefaultIcon()

        // Set template mode based on state
        icon.isTemplate = state.useTemplateImage

        // Ensure image size is correct and safe for menu bar
        if icon.size != Constants.menuBarIconSize {
            icon.size = Constants.menuBarIconSize
        }

        // Update the button image safely
        button.image = icon

        // Set tooltip based on state
        button.toolTip = state.tooltipText

        // Set proper accessibility
        button.image?.accessibilityDescription = "\(Constants.appName) \(state.description) icon"

        logger.info("Updated icon to \(state.rawValue) state")
    }

    /// Get the appropriate icon for the current state and appearance
    private func getIconForCurrentState() -> NSImage? {
        let state = currentState
        let appearance = getCurrentAppearance()

        // Check if we have a cached icon for this state and appearance
        if let cachedIcons = iconCache[state], let cachedIcon = cachedIcons[appearance] {
            return cachedIcon
        }

        // No cached icon, load from resources
        let icon = loadStatusBarIcon(for: state, appearance: appearance)

        // Store in cache if we loaded successfully
        if let icon {
            if iconCache[state] == nil {
                iconCache[state] = [:]
            }
            iconCache[state]?[appearance] = icon
        }

        return icon
    }

    /// Load the status bar icon for a specific state and appearance
    private func loadStatusBarIcon(for state: StatusIconState, appearance: NSAppearance.Name) -> NSImage? {
        // Use menu-bar-icon when in idle state
        if state == .idle {
            // Try to load menu-bar-icon
            if let menuBarIcon = NSImage.loadResourceImage(named: Constants.menuBarIconName) {
                return menuBarIcon
            }
        }

        // Determine icon name based on state and appearance
        let baseName = state == .idle ? "symbol" : "symbol-\(state.rawValue)"
        let iconName = appearance == .darkAqua ? "\(baseName)-dark" : baseName

        // Try to load the icon from resources
        if let icon = NSImage.loadResourceImage(named: iconName) {
            logger.info("Successfully loaded icon from resources: \(iconName)")
            prepareIconForStatusBar(icon, isTemplate: state.useTemplateImage)
            return icon
        }

        // Fallback to standard icon if we couldn't load the state-specific one
        if state != .idle {
            logger.info("Falling back to standard icon for state: \(state.rawValue)")
            return loadStatusBarIcon(for: .idle, appearance: appearance)
        }

        // Last resort: create a default icon
        logger.warning("Could not load any icon for state: \(state.rawValue), creating default")
        return createDefaultIcon()
    }

    /// Prepare an icon for use in the status bar
    private func prepareIconForStatusBar(_ icon: NSImage, isTemplate: Bool = true) {
        // Set correct size for menu bar (standard is 22x22)
        icon.size = Constants.menuBarIconSize

        // Set template mode based on parameter
        icon.isTemplate = isTemplate

        // Add accessibility description
        icon.accessibilityDescription = "\(Constants.appName) Status"
    }

    /// Create a default icon when no assets are available
    private func createDefaultIcon() -> NSImage {
        logger.info("Creating default menu bar icon")

        // Create a new template image with the app's symbol
        let symbolName = currentState == .error ? "exclamationmark.circle" : "circle.dashed"
        if let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: Constants.appName)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)) {

            prepareIconForStatusBar(icon)
            return icon
        }

        // Absolute fallback if SF Symbols are not available
        let size = Constants.menuBarIconSize
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw a simple circle
        let circlePath = NSBezierPath(ovalIn: NSRect(
            x: 1, y: 1, width: size.width - 2, height: size.height - 2
        ))

        switch currentState {
        case .error:
            NSColor.systemRed.setFill()
        case .success:
            NSColor.systemGreen.setFill()
        case .syncing:
            NSColor.systemOrange.setFill()
        default:
            NSColor.controlAccentColor.setFill()
        }

        circlePath.fill()

        image.unlockFocus()

        // Make it a template image for proper menu bar rendering
        image.isTemplate = currentState.useTemplateImage
        image.accessibilityDescription = Constants.appName

        return image
    }
}
