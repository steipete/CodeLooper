import SwiftUI
import Combine
import AppKit // For NSRunningApplication
import CoreGraphics // For CGWindowListCopyWindowInfo
import AXorcist // For Element, GlobalAXLogger, ax...Log helpers, and RunningApplicationHelper
import Defaults // ADD for Defaults, might be used by other methods if this file grows

// MARK: - Application and Tree Handling
extension AXpectorViewModel {
    /// Helper function to get running applications that have on-screen windows.
    private func appsWithOnScreenWindows() -> [NSRunningApplication] {
        // 1. Get ALL visible windows in one native call
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            axErrorLog("Failed to get CGWindowListCopyWindowInfo")
            return []
        }
        
        // 2. Collect PIDs that own at least one window
        let pidsWithWindows = Set(list.compactMap { $0[kCGWindowOwnerPID as String] as? pid_t })
        
        // 3. Get all running applications that are also accessible
        let accessibleApps = RunningApplicationHelper.accessibleApplications()
        
        // 4. Filter accessible applications to include only those with on-screen windows
        return accessibleApps.filter { pidsWithWindows.contains($0.processIdentifier) }
    }

    func fetchRunningApplications() {
        runningApplications = appsWithOnScreenWindows()
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
            guard let self = self else { return }
            
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
            guard let self = self else { return }
            
            let appPID = app.processIdentifier
            axInfoLog("Application terminated: \(RunningApplicationHelper.displayName(for: app))")
            
            // If the terminated app was selected, clear selection
            if self.selectedApplicationPID == appPID {
                self.selectedApplicationPID = nil
            }
            
            // Refresh the list
            self.fetchRunningApplications()
        }
    }

    // func fetchAccessibilityTreeForSelectedApp() { ... } // DELETED - Refactored version exists in AXpectorViewModel.swift
} 
