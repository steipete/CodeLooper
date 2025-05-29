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
public class SparkleUpdaterManager: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate, ObservableObject {
    // MARK: Lifecycle

    override init() {
        super.init()
        // Accessing the lazy var here will trigger its initialization.
        _ = self.updaterController
        logger.info("SparkleUpdaterManager initialized. Updater controller lazy initialization triggered.")
    }

    // MARK: - SPUUpdaterDelegate (Optional methods)

    // Example: Customizing update check frequency or other behaviors
    /*
     func allowedChannels(for updater: SPUUpdater) -> Set<String> {
         // Return a set of allowed channels, e.g., ["beta", "stable"]
         return []
     }
     */

    // MARK: - SPUStandardUserDriverDelegate (Optional methods)

    // Example: Handling UI events or customizing behavior during update process
    /*
     func standardUserDriverWillShowModalAlert(_ alert: NSAlert!) {
         logger.debug("Sparkle: Standard user driver will show modal alert.")
     }

     func standardUserDriverDidReceiveUserAttention() {
         logger.debug("Sparkle: Standard user driver did receive user attention.")
     }
     */

    // Add any other necessary SPUUpdaterDelegate or SPUStandardUserDriverDelegate methods here
    // based on the app's requirements for customizing Sparkle's behavior.

    // MARK: Public

    // Use lazy var to initialize after self is available
    public lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        logger.info("SparkleUpdaterManager: SPUStandardUpdaterController initialized with self as delegates.")
        return controller
    }() // The () here executes the closure and assigns the result to updaterController

    // MARK: Private
}
