import Combine
import Diagnostics
import os
import Sparkle

/// Manages the Sparkle auto-update framework integration.
///
/// SparkleUpdaterManager provides:
/// - Automatic update checking and installation
/// - Update UI presentation and user interaction
/// - Delegate callbacks for update lifecycle events
/// - Configuration of update channels and behavior
///
/// This manager wraps Sparkle's functionality to provide a clean
/// interface for the rest of the application while handling all
/// update-related delegate callbacks and UI presentation.
@MainActor
public class SparkleUpdaterManager: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate, ObservableObject,
    Loggable
{
    // MARK: - Static Logger for nonisolated methods
    nonisolated private static let staticLogger = Logger(category: .appLifecycle)
    
    // MARK: Lifecycle

    override init() {
        super.init()
        
        // Skip Sparkle initialization in test environment to avoid dialogs
        if Constants.isTestEnvironment {
            self.logger.info("SparkleUpdaterManager initialized in test mode - Sparkle disabled")
            return
        }
        
        // Accessing the lazy var here will trigger its initialization.
        _ = self.updaterController
        self.logger.info("SparkleUpdaterManager initialized. Updater controller lazy initialization triggered.")
    }

    // MARK: Public

    // Use lazy var to initialize after self is available
    public lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )

        // Enable automatic update checks
        controller.updater.automaticallyChecksForUpdates = true
        self.logger.info("Automatic update checks enabled")

        // Check for updates on startup
        Task { @MainActor in
            // Wait a moment for the app to finish launching before checking
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                self.logger.info("Checking for updates on startup")
                controller.updater.checkForUpdatesInBackground()
            }
        }

        self.logger.info("SparkleUpdaterManager: SPUStandardUpdaterController initialized with self as delegates.")
        return controller
    }() // The () here executes the closure and assigns the result to updaterController

    // MARK: Private

    // MARK: - SPUUpdaterDelegate

    // Handle when no update is found or when there's an error checking for updates
    nonisolated public func updater(_: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: Error?) {
        if let error = error as NSError? {
            // Check if it's a "no update found" error - this is normal and shouldn't be logged as an error
            if error.domain == "SUSparkleErrorDomain", error.code == 1001 {
                Self.staticLogger.debug("No updates available")
                return
            }

            // Check for appcast-related errors (missing file, parse errors, etc.)
            if error.domain == "SUSparkleErrorDomain",
               error.code == 2001 || // SUAppcastError
               error.code == 2002 || // SUAppcastParseError
               error.code == 2000
            { // SUInvalidFeedURLError
                Self.staticLogger.warning("Appcast error (missing or invalid feed): \(error.localizedDescription)")
                // Suppress the error dialog - we'll handle this silently
                return
            }

            // For other network errors or missing appcast, log but don't show UI
            Self.staticLogger.warning("Update check failed: \(error.localizedDescription)")

            // Suppress default error dialog by not propagating the error
            return
        }

        Self.staticLogger.debug("Update check completed successfully")
    }

    // Prevent update checks if we know the appcast is not available
    nonisolated public func updater(_: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        // You can add logic here to prevent update checks under certain conditions
        // For now, we'll allow all checks but handle errors gracefully in didFinishUpdateCycleFor
        Self.staticLogger.debug("Allowing update check of type: \(updateCheck)")
    }

    // Handle when update is not found
    nonisolated public func updaterDidNotFindUpdate(_: SPUUpdater, error: Error) {
        if let error = error as NSError? {
            Self.staticLogger.info("No update found: \(error.localizedDescription)")
        } else {
            Self.staticLogger.info("No update available")
        }
    }

    // MARK: - SPUStandardUserDriverDelegate

    // Called before showing any modal alert
    nonisolated public func standardUserDriverWillShowModalAlert() {
        Self.staticLogger.debug("Sparkle will show modal alert")
    }

    // Called after showing any modal alert
    nonisolated public func standardUserDriverDidShowModalAlert() {
        Self.staticLogger.debug("Sparkle did show modal alert")
    }

    // Add any other necessary SPUUpdaterDelegate or SPUStandardUserDriverDelegate methods here
    // based on the app's requirements for customizing Sparkle's behavior.
}
