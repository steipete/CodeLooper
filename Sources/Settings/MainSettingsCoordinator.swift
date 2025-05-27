import AppKit
import Combine
import Diagnostics
import os.log
import SwiftUI

/// Coordinator for triggering the settings window using the native Settings framework
@MainActor
public final class MainSettingsCoordinator: NSObject {
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

    /// Shows the settings window
    public func showSettings() {
        logger.info("Showing settings window")

        // Use the native Settings framework with our custom SettingsContainerView
        logger.info("Showing settings using native SwiftUI Settings framework with design system")
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    /// Closes the settings window
    public func closeSettings() {
        logger.info("Native settings don't need to be explicitly closed")
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
