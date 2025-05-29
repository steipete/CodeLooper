import Combine // For .onReceive
import Defaults
import DesignSystem
import Diagnostics
import KeyboardShortcuts
import Logging
import MenuBarExtraAccess
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

        logger.info("CodeLooperApp initialized")

        // Check MCP extension versions on startup
        Task {
            await MCPVersionService.shared.checkAllVersions()
        }

        // Opens settings automatically in debug builds for faster development
        #if DEBUG
            Task { @MainActor in
                MainSettingsCoordinator.shared.showSettings()
            }
        #endif
    }

    // MARK: Internal

    // Use @NSApplicationDelegateAdaptor to connect AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            menuBarContent
        } label: {
            MenuBarIconView() // Use the new struct for the label
                .environmentObject(cursorMonitor)
                .environmentObject(appIconStateController)
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented) { _ in
        }

        WindowGroup("CodeLooper", id: "settings") {
            SettingsSceneView()
                .environmentObject(sessionLogger)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 640, height: 800)
        .commandsRemoved()
        .handlesExternalEvents(matching: Set(["settings"]))
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
    @State private var isMenuPresented: Bool = false // For MenuBarExtraAccess

    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.showDebugMenu) private var showDebugMenu // For the debug menu items
    @Default(.startAtLogin) private var startAtLogin // For the menu item state

    // Logger for CodeLooperApp
    private let logger = Logger(category: .app)

    @ViewBuilder
    private var menuBarContent: some View {
        MainPopoverView()
            .environmentObject(sessionLogger)
            .environmentObject(cursorMonitor)
    }
}

struct MenuBarIconView: View {
    @StateObject private var menuBarIconManager = MenuBarIconManager.shared
    @EnvironmentObject var appIconStateController: AppIconStateController // Keep for status display
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @Default(.useDynamicMenuBarIcon) private var useDynamicMenuBarIcon

    var body: some View {
        HStack(spacing: 4) {
            // Icon based on user preference
            if useDynamicMenuBarIcon {
                // Lottie animation icon
                LottieMenuBarView()
            } else {
                // Static PNG icon
                Image("MenuBarTemplateIcon")
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
            }

            // Display the status text from the manager
            Text(menuBarIconManager.currentIconAttributedString)
                .font(.system(size: 12, weight: .medium))
        }
        .contentShape(Rectangle())
    }
}

struct SettingsSceneView: View {
    // MARK: Internal

    var body: some View {
        SettingsContainerView()
            .environmentObject(mainSettingsViewModel)
            .onReceive(SettingsService.openSettingsSubject) { _ in
                // Handle settings opening if needed
            }
            .onAppear {
                ensureSingleSettingsWindow()
            }
    }

    // MARK: Private

    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
    )

    private func ensureSingleSettingsWindow() {
        // Close any duplicate settings windows
        let settingsWindows = NSApp.windows.filter { window in
            window.title.contains("Settings") || window.identifier?.rawValue == "settings"
        }

        // Keep only the first one, close the rest
        for window in settingsWindows.dropFirst() {
            print("Closing duplicate settings window: \(window.title)")
            window.close()
        }
    }
}
