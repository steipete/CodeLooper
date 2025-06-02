import AppKit // For NSRunningApplication
import AXorcist // For Element, GlobalAXLogger, ax...Log helpers, and RunningApplicationHelper
import Combine
import CoreGraphics // For CGWindowListCopyWindowInfo
import Defaults // ADD for Defaults, might be used by other methods if this file grows
import SwiftUI

// MARK: - Application and Tree Handling

/// Extension providing application discovery and accessibility tree management.
///
/// This extension handles:
/// - Running application discovery and monitoring
/// - Periodic refresh of applications with accessible windows
/// - Application launch/termination observation
/// - Accessibility tree fetching and conversion
/// - Error handling for inaccessible applications
extension AXpectorViewModel {
    func fetchRunningApplications() {
        // Use the centralized helper from AXorcist module
        runningApplications = RunningApplicationHelper.accessibleApplicationsWithOnScreenWindows()
        axInfoLog("Fetched \(self.runningApplications.count) running applications with on-screen windows.")
    }

    func setupApplicationMonitoring() {
        // Set up periodic refresh for window changes
        windowRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchRunningApplications()
            }
        }
        // Monitor app launches
        appLaunchObserver = RunningApplicationHelper.observeApplicationLaunches { [weak self] app in
            guard let self else { return }

            // Check if the app is accessible before adding
            if RunningApplicationHelper.isAccessible(app) {
                axInfoLog("New application launched: \(RunningApplicationHelper.displayName(for: app))")

                // Wait a bit for windows to appear, then refresh
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    await MainActor.run {
                        self.fetchRunningApplications()
                    }
                }
            }
        }

        // Monitor app terminations
        appTerminateObserver = RunningApplicationHelper.observeApplicationTerminations { [weak self] app in
            guard let self else { return }

            let appPID = app.processIdentifier
            axInfoLog("Application terminated: \(RunningApplicationHelper.displayName(for: app))")

            // If the terminated app was selected, clear selection
            Task { @MainActor in
                if self.selectedApplicationPID == appPID {
                    self.selectedApplicationPID = nil
                }
                
                // Refresh the list
                self.fetchRunningApplications()
            }
        }
    }
}
