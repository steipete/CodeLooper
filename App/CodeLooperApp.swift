import Combine // For .onReceive
import Defaults
import DesignSystem
import Diagnostics
import KeyboardShortcuts
import Logging
import os
import SwiftUI

/// The main entry point for the CodeLooper SwiftUI application.
///
/// CodeLooperApp configures:
/// - Application lifecycle and scene management
/// - Menu bar integration with custom status item
/// - Settings window presentation
/// - Global keyboard shortcuts
/// - AppDelegate bridging for legacy functionality
///
/// The app uses SwiftUI's modern app lifecycle while maintaining
/// compatibility with AppKit features through the AppDelegate.
@main
struct CodeLooperApp: App {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        // Perform one-time setup for the logging system.
        Diagnostics.Logger.bootstrap(destination: .console, minLevel: .debug)

        // Use temporary logger since the instance property isn't available yet
        let initLogger = Logger(category: .app)
        initLogger.info("CodeLooperApp initialized")

        // Check MCP extension versions on startup
        Task {
            await MCPVersionService.shared.checkAllVersions()
        }

        // Opens settings automatically in debug builds for faster development
        #if DEBUG
            if !Constants.isTestEnvironment {
                Task { @MainActor in
                    MainSettingsCoordinator.shared.showSettings()
                }
            }
        #endif
    }

    // MARK: Internal

    // Use @NSApplicationDelegateAdaptor to connect AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window groups - settings are handled by MainSettingsCoordinator
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About CodeLooper") {
                    appDelegate.windowManager?.showAboutWindow()
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openSettings) private var openSettings // For opening settings

    // Access the shared instance of CursorMonitor
    @StateObject private var cursorMonitor = CursorMonitor.shared
    @StateObject private var sessionLogger = SessionLogger.shared
    @StateObject private var appIconStateController = AppIconStateController.shared // Renamed for clarity

    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.showDebugMenu) private var showDebugMenu // For the debug menu items
    @Default(.startAtLogin) private var startAtLogin // For the menu item state

    // Logger for CodeLooperApp
    private let logger = Logger(category: .app)
}
