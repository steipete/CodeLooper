import SwiftUI
import Combine
import AppKit // For NSRunningApplication
import AXorcist // For Element, GlobalAXLogger, ax...Log helpers, and RunningApplicationHelper
import Defaults // ADD for Defaults, might be used by other methods if this file grows

// MARK: - Application and Tree Handling
extension AXpectorViewModel {
    func fetchRunningApplications() {
        // Use RunningApplicationHelper instead of custom logic
        runningApplications = RunningApplicationHelper.accessibleApplications()
        axInfoLog("Fetched \(self.runningApplications.count) running applications.")
    }
    
    func setupApplicationMonitoring() {
        // Monitor app launches
         appLaunchObserver = RunningApplicationHelper.observeApplicationLaunches { [weak self] app in
            guard let self = self else { return }
            
            // Check if the app is accessible before adding
            if RunningApplicationHelper.isAccessible(app) {
                axInfoLog("New application launched: \(RunningApplicationHelper.displayName(for: app))")
                
                // Refresh the list
                self.fetchRunningApplications()
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
