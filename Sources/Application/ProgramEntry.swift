import AppKit
import OSLog
import SwiftUI

// This was previously the main entry point, now replaced by AppMain.swift
// Note: @main attribute removed to avoid conflict with AppMain.swift
enum ProgramEntry {
    // Define a unique identifier for our app - using bundle ID is recommended
    private static let appIdentifier = "com.friendshipai.mac.instance"

    // Mark the main method as @MainActor because it interacts with UI components
    @MainActor
    static func main() async {
        // Initialize application first to prevent nil unwrapping
        _ = NSApplication.shared

        // Check if app is already running
        // Note: We're using the instance ID defined at the class level

        // Check if running under Xcode debugger
        let isDebug = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"]?.contains("Xcode") == true ||
            ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        if !isDebug {
            // TODO: Implement instance checking functionality
            // For now, skip instance check to allow build to complete
            print("Warning: Instance check not implemented yet")

            // Original code:
            // let instanceExists = await checkForExistingInstance(appIdentifier: appIdentifier)
            // if instanceExists {
            //     // Another instance is running, terminate this one
            //     // Use exit instead of NSApp.terminate to avoid implicitly unwrapping NSApp
            //     exit(0)
            // } else {
            //     // Set up instance listener
            //     setupInstanceListener(appIdentifier: appIdentifier)
            // }
        }

        // Create an app delegate that will handle all initialization
        let appDelegate = AppDelegate()

        // Set it as the application delegate
        NSApp.delegate = appDelegate

        // Configure app as a menu bar app
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        // Run the application event loop
        NSApp.run()
    }
}

// End of ProgramEntry implementation
