import SwiftUI
import Combine
import AppKit // For NSRunningApplication
import AXorcist // For Element, GlobalAXLogger and ax...Log helpers
// import OSLog // For logging // REMOVE OSLog
import Defaults // ADD for Defaults, might be used by other methods if this file grows

// MARK: - Application and Tree Handling
extension AXpectorViewModel {
    func fetchRunningApplications() {
        runningApplications = NSWorkspace.shared.runningApplications.filter { app in
            return app.activationPolicy != .prohibited && app.processIdentifier > 0 && app.bundleIdentifier != nil
        }.sorted(by: { $0.localizedName ?? "" < $1.localizedName ?? "" })
        axInfoLog("Fetched \(self.runningApplications.count) running applications.")
    }

    // func fetchAccessibilityTreeForSelectedApp() { ... } // DELETED - Refactored version exists in AXpectorViewModel.swift
} 