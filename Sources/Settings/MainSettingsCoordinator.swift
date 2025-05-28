import AppKit
import Combine
import Diagnostics
import os.log
import SwiftUI

/// Coordinator for triggering the settings window using the native Settings framework
@MainActor
public final class MainSettingsCoordinator: NSObject {
    // MARK: - Shared Instance
    
    public static let shared = MainSettingsCoordinator(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
    )
    
    // MARK: Lifecycle

    // MARK: - Initialization

    public init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        self.loginItemManager = loginItemManager
        self.updaterViewModel = updaterViewModel
        super.init()

        // Set up observers
        setupObservers()

        logger.info("Settings coordinator initialized")
    }

    // MARK: - Cleanup

    deinit {
        // Use MainActor.assumeIsolated to safely access MainActor-isolated properties
        MainActor.assumeIsolated {
            cancellables.removeAll()
            logger.info("Settings coordinator deinitialized")
        }
    }

    // MARK: Public

    // MARK: - Public Interface

    /// Shows the settings window (ensures only one instance)
    public func showSettings() {
        logger.info("Showing settings window")

        // First, check if a settings window already exists
        let existingSettingsWindows = NSApp.windows.filter { window in
            window.title.contains("Settings") || window.identifier?.rawValue == "settings"
        }
        
        if let existingWindow = existingSettingsWindows.first {
            // If window exists, bring it to front
            logger.info("Settings window already exists, bringing to front")
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            
            // Close any duplicate windows
            for window in existingSettingsWindows.dropFirst() {
                logger.warning("Closing duplicate settings window")
                window.close()
            }
        } else {
            // Create new settings window using the WindowGroup
            logger.info("Creating new settings window")
            openNewSettingsWindow()
        }
    }
    
    private func openNewSettingsWindow() {
        // Try to open via URL scheme first
        if let url = URL(string: "codelooper://settings") {
            NSWorkspace.shared.open(url)
            return
        }
    }

    /// Closes the settings window
    public func closeSettings() {
        logger.info("Closing settings window")
        
        let settingsWindows = NSApp.windows.filter { window in
            window.title.contains("Settings") || window.identifier?.rawValue == "settings"
        }
        
        for window in settingsWindows {
            logger.info("Closing settings window: \(window.title)")
            window.close()
        }
    }

    // MARK: Private

    private let logger = Logger(category: .settings)
    private var cancellables = Set<AnyCancellable>()
    private let loginItemManager: LoginItemManager
    private let updaterViewModel: UpdaterViewModel

    // MARK: - Private Methods

    private func setupObservers() {
        // Listen for notifications to show settings window
        NotificationCenter.default
            .publisher(for: .showSettingsWindow)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.logger
                        .info(
                            "Received .showSettingsWindow notification, calling MainSettingsCoordinator.showSettings()"
                        )
                    self?.showSettings()
                }
            }
            .store(in: &cancellables)
    }
}
