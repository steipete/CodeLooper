import Combine
import Defaults
import Diagnostics
import Foundation
import OSLog
import SwiftUI

/**
 Application-wide environment state model for SwiftUI.

 This class serves as a central state container that provides access to various
 app-wide state and services through the SwiftUI environment. It implements the
 ObservableObject protocol to provide reactive updates to SwiftUI views.

 This class directly manages theme state and dispatches notification events
 to keep the system appearance in sync with the selected theme.
 */
@MainActor
class AppEnvironment: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Default initializer sets up environment with default values
    init() {
        // Load settings from UserDefaults
        setupDefaultsBinding()

        // Setup notification observers
        setupNotificationObservers()

        logger.info("AppEnvironment initialized")
    }

    // MARK: Internal

    // MARK: - App State

    /// Whether the app has completed initial setup
    @Published var isSetupComplete: Bool = false

    // MARK: - App Settings and Preferences

    /// Whether to show the welcome screen
    @Published var showWelcomeScreen: Bool = false {
        didSet {
            if showWelcomeScreen {
                logger.info("Welcome screen visibility changed to visible in environment")
                // Post notification for AppMain to handle
                NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
            } else if oldValue == true {
                logger.info("Welcome screen visibility changed to hidden in environment")
                // Post notification to dismiss
                NotificationCenter.default.post(name: .dismissWelcomeWindow, object: nil)
            }
        }
    }

    // MARK: Private

    private let logger = Logger(category: .app)

    // MARK: - Private State

    /// Store for Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Setup bindings to UserDefaults
    private func setupDefaultsBinding() {
        // Access UserDefaults directly to avoid Defaults package Swift 6 compatibility issues
        let defaults = UserDefaults.standard

        // Check if setup is complete
        isSetupComplete = defaults.bool(forKey: "hasCompletedOnboarding")

        // Monitor setup completion changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let newSetupComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                if self.isSetupComplete != newSetupComplete {
                    self.isSetupComplete = newSetupComplete
                }
            }
        }
    }

    /// Setup notification observers
    private func setupNotificationObservers() {
        // Setup basic notification observers for core functionality
        logger.info("Setting up notification observers for core functionality")

        // Listen for theme changes if needed in the future
        // Additional observers can be added here as the app grows
    }
}

// MARK: - Environment Keys

/// Environment key for the app environment
@preconcurrency
struct AppEnvironmentKey: EnvironmentKey {
    // Use an unsafe creation pattern to satisfy protocol requirements
    // This is safe in practice as the environment is created on the main thread
    static var defaultValue: AppEnvironment {
        // Since AppEnvironment is MainActor-isolated, we need to handle this properly
        // Create an environment directly on the main thread
        let environment = MainActor.assumeIsolated {
            AppEnvironment()
        }

        return environment
    }
}

/// Extension to add app environment to the SwiftUI environment
extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - EnvironmentObject Extension

/// Convenience method to access app environment as an environment object
extension View {
    /// Provides app environment to the view and its subviews
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        environmentObject(environment)
    }
}

// Note: All notification names are defined in NotificationName.swift
