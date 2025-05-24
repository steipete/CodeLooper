import AppKit
import Combine
import Diagnostics
import os.log
import SwiftUI

/// Coordinator for triggering the settings window using the native Settings framework
@MainActor
public final class MainSettingsCoordinator: NSObject {
    // MARK: - Properties

    private let logger = Logger(category: .settings)
    private var cancellables = Set<AnyCancellable>()
    private let loginItemManager: LoginItemManager
    private let updaterViewModel: UpdaterViewModel

    // MARK: - Initialization

    public init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        self.loginItemManager = loginItemManager
        self.updaterViewModel = updaterViewModel
        super.init()

        // Set up observers
        setupObservers()

        logger.info("Settings coordinator initialized")
    }

    // MARK: - Public Interface

    /// Shows the settings window
    public func showSettings() {
        logger.info("Showing settings window")

        // Use the native Settings framework
        logger.info("Showing settings using native SwiftUI Settings framework")
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    /// Closes the settings window
    public func closeSettings() {
        logger.info("Native settings don't need to be explicitly closed")
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Listen for notifications to show settings window
        NotificationCenter.default
            .publisher(for: .showSettingsWindow)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.showSettings()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Cleanup

    deinit {
        // Use MainActor.assumeIsolated to safely access MainActor-isolated properties
        MainActor.assumeIsolated {
            cancellables.removeAll()
            logger.info("Settings coordinator deinitialized")
        }
    }
}
