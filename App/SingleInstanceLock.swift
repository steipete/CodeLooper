import AppKit
import Diagnostics
import Foundation

/// A helper class to ensure only one instance of the application is running.
/// This uses NSDistributedNotificationCenter to detect and communicate with other instances.
@MainActor
public final class SingleInstanceLock {
    // MARK: Lifecycle

    public init(identifier: String) {
        self.identifier = identifier

        #if !DEBUG // Only enforce single instance lock in Release builds
            Task {
                self.isPrimaryInstance = await checkIfPrimaryInstance()
            }
        #else // For DEBUG builds, always assume primary instance
            self.isPrimaryInstance = true
            logger.info("DEBUG build: Single instance lock is bypassed.")
        #endif
    }

    deinit {
        // Remove observers
        DistributedNotificationCenter.default().removeObserver(self)

        #if !DEBUG
            logger.info("SingleInstanceLock deinitialized.")
        #endif
    }

    // MARK: Public

    /// Whether this is the primary (first) instance
    public private(set) var isPrimaryInstance: Bool = false

    /// Attempts to activate the existing instance
    public func activateExistingInstance() {
        if let runningApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).first(where: { $0 != NSRunningApplication.current }) {
            logger.info("Activating existing instance...")
            runningApp.activate(options: [.activateAllWindows])
        }
    }

    // MARK: Private

    private static let notificationName = "me.steipete.codelooper.instance.check"
    private static let responseNotificationName = "me.steipete.codelooper.instance.response"

    private let identifier: String
    private let logger = Logger(category: .app)

    /// A continuation to handle the async check for other instances
    private var checkContinuation: CheckedContinuation<Bool, Never>?

    private func checkIfPrimaryInstance() async -> Bool {
        // Register to respond to instance check notifications
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleInstanceCheckNotification(_:)),
            name: NSNotification.Name(Self.notificationName),
            object: nil
        )

        // Register to receive responses from other instances
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleInstanceResponseNotification(_:)),
            name: NSNotification.Name(Self.responseNotificationName),
            object: nil
        )

        // Send a notification to check if another instance is running
        logger.info("Checking for other running instances...")

        return await withCheckedContinuation { continuation in
            self.checkContinuation = continuation

            // Post notification to check for other instances
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(Self.notificationName),
                object: nil,
                userInfo: ["identifier": identifier],
                deliverImmediately: true
            )

            // Wait a brief moment for responses
            Task {
                try? await Task.sleep(for: .milliseconds(500)) // 0.5 seconds

                // If no response received, we're the primary instance
                if self.checkContinuation != nil {
                    self.checkContinuation?.resume(returning: true)
                    self.checkContinuation = nil
                    self.logger.info("No other instances detected. This is the primary instance.")
                }
            }
        }
    }

    @objc private func handleInstanceCheckNotification(_ notification: Notification) {
        // Only respond if we're already established as the primary instance
        guard isPrimaryInstance else { return }

        if let userInfo = notification.userInfo,
           let notificationIdentifier = userInfo["identifier"] as? String,
           notificationIdentifier == identifier
        {
            logger.info("Received instance check from another instance. Responding...")

            // Send response that we're already running
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(Self.responseNotificationName),
                object: nil,
                userInfo: ["identifier": identifier],
                deliverImmediately: true
            )
        }
    }

    @objc private func handleInstanceResponseNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let notificationIdentifier = userInfo["identifier"] as? String,
           notificationIdentifier == identifier
        {
            logger.info("Received response from existing instance.")

            // Another instance is already running
            checkContinuation?.resume(returning: false)
            checkContinuation = nil
        }
    }
}
