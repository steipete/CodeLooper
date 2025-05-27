import AXorcist
import Cocoa

/// Observes application launch and termination events.
class AXApplicationObserver {
    // MARK: Lifecycle

    // Logger instance will be added when integrating with main app

    init(axorcist: AXorcist?) {
        self.axorcist = axorcist
        setupObservers()
    }

    deinit {
        removeObservers()
    }

    // MARK: Internal

    /// Updates the set of application bundle identifiers to be monitored.
    /// - Parameter bundleIdentifiers: An array of bundle identifiers (String).
    func updateObservedApplications(bundleIdentifiers: [String]) {
        monitoredBundleIdentifiers = Set(bundleIdentifiers)
        // Log: Updated monitored applications: \(monitoredBundleIdentifiers.joined(separator: ", "))
    }

    // MARK: Private

    private let axorcist: AXorcist?
    private var monitoredBundleIdentifiers: Set<String> = []
    private let notificationCenter = NSWorkspace.shared.notificationCenter

    private func setupObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(notification:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(notification:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func removeObservers() {
        notificationCenter.removeObserver(self)
    }

    @objc
    private func applicationDidLaunch(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let _ = app.localizedName
        else {
            // Log error: Missing application information
            return
        }
        // Log: Application launched: \(appName) (\(bundleIdentifier)), PID: \(app.processIdentifier)

        if monitoredBundleIdentifiers.contains(bundleIdentifier) {
            // Log: Monitored application \(appName) launched.
            // Future: Potentially trigger an AXorcist scan or other actions.
            // Example:
            // Task {
            //     await MainActor.run {
            //         // let query = AXQuery(pid: app.processIdentifier, locator: ..., options: ...)
            //         // _ = try? await axorcist?.handleQuery(query)
            //     }
            // }
        }
    }

    @objc
    private func applicationDidTerminate(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let _ = app.localizedName
        else {
            // Log error: Missing application information
            return
        }
        // Log: Application terminated: \(appName) (\(bundleIdentifier)), PID: \(app.processIdentifier)

        if monitoredBundleIdentifiers.contains(bundleIdentifier) {
            // Log: Monitored application \(appName) terminated.
        }
    }
}
