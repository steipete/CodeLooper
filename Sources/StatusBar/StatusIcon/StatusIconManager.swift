import AppKit
import Foundation
import OSLog

// StatusIconState is already part of the same module, no need to import it

/// Class responsible for managing the status bar icon state and transitions
@MainActor
class StatusIconManager {
    // MARK: - Properties

    private weak var menuManager: MenuManager?
    private var logger = Logger(subsystem: "com.friendshipai.mac", category: "StatusIconManager")

    // Track current state
    private var currentState: StatusIconState = .idle

    // Timer for auto-resetting transient states
    // This is safe because we're MainActor-isolated and Timer is only accessed on the main thread
    private var stateResetTimer: Timer?

    // MARK: - Initialization

    init(menuManager: MenuManager) {
        self.menuManager = menuManager
    }

    /// Clean up resources when the manager is deallocated
    deinit {
        // Note: We don't access any non-sendable properties here
        // Timer cleanup happens in the cleanup() method which should be called
        // before this object is deallocated
        print("StatusIconManager deallocated")
    }

    // MARK: - State Management

    /// Updates the status bar icon state
    /// - Parameter state: The new state to set
    func updateIconState(_ state: StatusIconState) {
        // Cancel any ongoing state reset timer
        stateResetTimer?.invalidate()
        stateResetTimer = nil

        // Update current state
        currentState = state

        // Get the menu bar icon manager
        if let menuBarIconManager = menuManager?.getMenuBarIconManager() {
            // Set the state on the icon manager
            menuBarIconManager.setState(state)

            // For transient states (success, error, authenticated, unauthenticated),
            // schedule a reset to idle state after a delay
            if isTransientState(state) {
                scheduleResetToIdle()
            }
        } else {
            logger.error("Cannot update icon state: MenuBarIconManager not available")
        }

        logger.info("Status icon state updated to: \(state.rawValue)")
    }

    /// Updates the menu bar icon to indicate upload status
    func updateMenuBarIconForUpload(_ isUploading: Bool) {
        // Simply update the icon state based on the upload status
        // State handling and animations are managed through the state system
        if isUploading {
            updateIconState(.syncing)
        } else {
            updateIconState(.success)
        }
    }

    /// Check if the state is transient (should automatically reset to idle)
    private func isTransientState(_ state: StatusIconState) -> Bool {
        switch state {
        case .success, .error, .authenticated, .unauthenticated:
            true
        case .idle, .syncing:
            false
        }
    }

    /// Schedule a reset to idle state after a delay
    private func scheduleResetToIdle() {
        // Cancel any existing timer
        stateResetTimer?.invalidate()

        // Create new timer
        stateResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Only reset if we're still in the same transient state
                if self.isTransientState(self.currentState) {
                    self.updateIconState(.idle)
                }

                self.stateResetTimer = nil
            }
        }
    }

    // Legacy progress indicator methods have been removed
    // Icon state is now handled entirely through the state-based system

    /// Formats a date for display in the menu
    func formatDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true // Uses "Today", "Yesterday" etc. when appropriate
        return formatter.string(from: date)
    }

    /// Clean up resources associated with the menu bar
    func cleanup() {
        logger.info("Cleaning up status icon manager")

        // Cancel state reset timer
        stateResetTimer?.invalidate()
        stateResetTimer = nil
    }

    /// Sets the menu bar icon using a system symbol as a fallback option
    func useSystemSymbolIcon() {
        guard let statusItem = menuManager?.statusItem,
              let button = statusItem.button
        else {
            logger.warning("Status item button is nil, can't update with system symbol")
            return
        }

        // Use a system symbol for the menu bar that's distinct and recognizable
        let symbolName = "circle.fill"
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: Constants.appName)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .medium))

        if let symbol {
            // Set as template image for proper menu bar appearance in dark/light mode
            symbol.isTemplate = true

            // Update button image
            button.image = symbol

            logger.info("Menu bar icon replaced with system symbol: \(symbolName)")
        } else {
            logger.error("Failed to create system symbol for menu bar")
        }
    }
}
