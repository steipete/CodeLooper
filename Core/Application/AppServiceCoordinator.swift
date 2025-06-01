import AppKit
import AXorcist
import Defaults
import Diagnostics
import Foundation

/// Coordinates initialization and lifecycle of core application services.
///
/// This coordinator manages the setup of essential services like accessibility observers,
/// window management, updates, and monitoring systems to reduce complexity in AppDelegate.
@MainActor
final class AppServiceCoordinator {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        logger.info("AppServiceCoordinator initialized")
    }

    // MARK: Internal

    // MARK: - Service Access

    private(set) var axorcist: AXorcist?
    private(set) var axApplicationObserver: AXApplicationObserver?
    private(set) var loginItemManager: LoginItemManager?
    private(set) var windowManager: WindowManager?
    private(set) var mainSettingsCoordinator: MainSettingsCoordinator?
    private(set) var sparkleUpdaterManager: SparkleUpdaterManager?
    private(set) var updaterViewModel: UpdaterViewModel?
    private(set) var locatorManager: LocatorManager = .shared

    // MARK: - Public API

    /// Initialize all core services required for application functionality
    func initializeServices() async throws {
        logger.info("🚀 Initializing essential services...")

        // Initialize services in dependency order
        try await initializeAccessibilityServices()
        try await initializeMonitoringServices()
        try await initializeUIServices()
        try await initializeUpdateServices()

        logger.info("✅ Essential services initialization complete")
    }

    /// Cleanup and shutdown all services
    func shutdownServices() {
        logger.info("🛑 Shutting down services...")

        // Stop monitoring first
        CursorMonitor.shared.stopMonitoringLoop()

        // Cleanup accessibility observers
        axApplicationObserver = nil
        axorcist = nil

        // Cleanup UI services
        windowManager = nil
        mainSettingsCoordinator = nil

        logger.info("✅ Service shutdown complete")
    }

    // MARK: - Service Accessors

    /// Get the window manager, throwing if not initialized
    func getWindowManager() throws -> WindowManager {
        guard let windowManager else {
            throw ServiceError.serviceNotInitialized("WindowManager")
        }
        return windowManager
    }

    /// Get the settings coordinator, throwing if not initialized
    func getSettingsCoordinator() throws -> MainSettingsCoordinator {
        guard let coordinator = mainSettingsCoordinator else {
            throw ServiceError.serviceNotInitialized("MainSettingsCoordinator")
        }
        return coordinator
    }

    // MARK: Private

    // MARK: - Private Implementation

    private let logger = Logger(category: .appDelegate)
    private let sessionLogger = SessionLogger.shared

    /// Initialize accessibility-related services
    private func initializeAccessibilityServices() async throws {
        logger.info("🔍 Initializing accessibility services...")

        axorcist = AXorcist()
        guard let axorcist else {
            throw ServiceError.initializationFailed("AXorcist")
        }

        axApplicationObserver = AXApplicationObserver(axorcist: axorcist)
        logger.info("✅ Accessibility services initialized")
    }

    /// Initialize monitoring and supervision services
    private func initializeMonitoringServices() async throws {
        logger.info("📡 Initializing monitoring services...")

        // CursorMonitor is a singleton and initializes itself
        _ = CursorMonitor.shared

        // Initialize locator manager
        _ = locatorManager

        logger.info("✅ Monitoring services initialized")
    }

    /// Initialize UI and window management services
    private func initializeUIServices() async throws {
        logger.info("🖥️ Initializing UI services...")

        // Initialize login item manager
        loginItemManager = LoginItemManager.shared

        // Initialize menu bar icon manager
        _ = MenuBarIconManager.shared

        // Setup settings coordinator
        setupSettingsCoordinator()

        // Initialize window manager
        guard let loginManager = loginItemManager else {
            throw ServiceError.dependencyMissing("LoginItemManager required for WindowManager")
        }

        // Create window manager with proper delegate handling
        windowManager = WindowManager(
            loginItemManager: loginManager,
            sessionLogger: sessionLogger,
            delegate: nil // Will be set by AppDelegate
        )

        logger.info("✅ UI services initialized")
    }

    /// Initialize update and maintenance services
    private func initializeUpdateServices() async throws {
        logger.info("🔄 Initializing update services...")

        // Initialize Sparkle with error handling to prevent dialogs
        sparkleUpdaterManager = SparkleUpdaterManager()

        if let sparkleManager = sparkleUpdaterManager {
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: sparkleManager)
            logger.info("✅ Sparkle update services initialized")
        } else {
            updaterViewModel = UpdaterViewModel(sparkleUpdaterManager: nil)
            logger.info("⚠️ Update services initialized without Sparkle (disabled)")
        }
    }

    /// Setup the main settings coordinator
    private func setupSettingsCoordinator() {
        logger.info("⚙️ Setting up settings coordinator...")

        // Initialize with available parameters
        if let updater = updaterViewModel {
            mainSettingsCoordinator = MainSettingsCoordinator(
                loginItemManager: loginItemManager ?? LoginItemManager.shared,
                updaterViewModel: updater
            )
        } else {
            // Create a placeholder updater view model if sparkle is disabled
            mainSettingsCoordinator = MainSettingsCoordinator(
                loginItemManager: loginItemManager ?? LoginItemManager.shared,
                updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
            )
        }

        logger.info("✅ Settings coordinator ready")
    }
}

// MARK: - Error Types

enum ServiceError: Error, LocalizedError {
    case serviceNotInitialized(String)
    case initializationFailed(String)
    case dependencyMissing(String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .serviceNotInitialized(service):
            "Service not initialized: \(service)"
        case let .initializationFailed(service):
            "Failed to initialize service: \(service)"
        case let .dependencyMissing(dependency):
            "Missing required dependency: \(dependency)"
        }
    }
}
