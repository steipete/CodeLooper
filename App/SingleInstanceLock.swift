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
            // Skip for test environment
            let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                ProcessInfo.processInfo.arguments.contains("--test-mode") ||
                NSClassFromString("XCTest") != nil

            if isTestEnvironment {
                self.isPrimaryInstance = true
                logger.info("Test environment: Single instance lock is bypassed.")
            } else {
                // Set up observers first before checking
                setupObservers()

                Task {
                    self.isPrimaryInstance = await checkIfPrimaryInstance()

                    // If we're not the primary instance, remove observers
                    if !self.isPrimaryInstance {
                        self.removeObservers()
                    }
                }
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

    /// Attempts to activate the existing instance and show settings
    public func activateExistingInstance() {
        // First, notify the existing instance to show settings
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("me.steipete.codelooper.showSettings"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        // Then activate the app
        if let runningApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).first(where: { $0 != NSRunningApplication.current }) {
            logger.info("Activating existing instance and requesting settings window...")
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

    private func setupObservers() {
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

        logger.debug("Single instance observers set up")
    }

    private func removeObservers() {
        DistributedNotificationCenter.default().removeObserver(self)
        logger.debug("Single instance observers removed")
    }

    private func checkIfPrimaryInstance() async -> Bool {
        // Send a notification to check if another instance is running
        logger.info("Checking for other running instances... (PID: \(ProcessInfo.processInfo.processIdentifier))")

        return await withCheckedContinuation { continuation in
            self.checkContinuation = continuation

            // Post notification to check for other instances
            logger.debug("Posting instance check notification with identifier: \(identifier)")
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(Self.notificationName),
                object: nil,
                userInfo: ["identifier": identifier, "checkingPID": ProcessInfo.processInfo.processIdentifier],
                deliverImmediately: true
            )

            // Wait a brief moment for responses
            Task {
                try? await Task.sleep(for: .milliseconds(100)) // 0.1 seconds - much faster

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
        guard isPrimaryInstance else {
            logger.debug("Ignoring instance check - not yet established as primary")
            return
        }

        if let userInfo = notification.userInfo,
           let notificationIdentifier = userInfo["identifier"] as? String,
           notificationIdentifier == identifier
        {
            logger.info(
                """
                Received instance check from another instance. \
                Current PID: \(ProcessInfo.processInfo.processIdentifier). Responding...
                """
            )

            // Send response that we're already running
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(Self.responseNotificationName),
                object: nil,
                userInfo: ["identifier": identifier, "pid": ProcessInfo.processInfo.processIdentifier],
                deliverImmediately: true
            )
        }
    }

    @objc private func handleInstanceResponseNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let notificationIdentifier = userInfo["identifier"] as? String,
           notificationIdentifier == identifier
        {
            let respondingPID = userInfo["pid"] as? Int ?? -1
            let ourPID = ProcessInfo.processInfo.processIdentifier

            logger.info("Received response from existing instance. Their PID: \(respondingPID), Our PID: \(ourPID)")

            // Ignore if this is our own response (shouldn't happen but let's be safe)
            if respondingPID == ourPID {
                logger.warning("Ignoring response from ourselves! This shouldn't happen.")
                return
            }

            // Another instance is already running
            checkContinuation?.resume(returning: false)
            checkContinuation = nil
        }
    }
}
