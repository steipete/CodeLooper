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
        // Clean up cancellables
        cancellables.removeAll()
        logger.info("Settings coordinator deinitialized")
    }

    // MARK: Public

    // MARK: - Shared Instance

    public static let shared = MainSettingsCoordinator(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: SparkleUpdaterManager())
    )

    // MARK: - Public Interface

    /// Shows the settings window (ensures only one instance)
    public func showSettings() {
        logger.info("Showing settings window")

        // Check if we already have a window
        if let window = settingsWindow, window.isVisible {
            // If window exists, bring it to front
            logger.info("Settings window already exists, bringing to front")
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create new settings window
            logger.info("Creating new settings window")
            openNewSettingsWindow()
        }
    }

    /// Closes the settings window
    public func closeSettings() {
        logger.info("Closing settings window")

        settingsWindow?.close()
        settingsWindow = nil
    }

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private let loginItemManager: LoginItemManager
    private let updaterViewModel: UpdaterViewModel
    private var settingsWindow: NativeToolbarSettingsWindow?

    private func openNewSettingsWindow() {
        logger.info("Creating transparent settings window")

        // Create the window
        settingsWindow = NativeToolbarSettingsWindow(
            loginItemManager: loginItemManager,
            updaterViewModel: updaterViewModel
        )

        // Show the window
        settingsWindow?.makeKeyAndOrderFront(nil)

        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
    }

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
