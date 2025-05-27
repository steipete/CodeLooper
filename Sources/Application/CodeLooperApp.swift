import Combine // For .onReceive
import Defaults
import Diagnostics
import KeyboardShortcuts
import Logging
import MenuBarExtraAccess
import os
import SwiftUI

@main
struct CodeLooperApp: App {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        // Perform one-time setup for the logging system.
        Diagnostics.Logger.bootstrap(destination: .console, minLevel: .debug)

        logger.info("CodeLooperApp initialized. ScenePhase: \(scenePhase)")

        // Opens settings automatically in debug builds for faster development
        #if DEBUG
            DispatchQueue.main.async {
                NSApp.openSettings()
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

        Settings {
            SettingsSceneView()
                .environmentObject(sessionLogger)
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
    @EnvironmentObject var cursorMonitor: CursorMonitor
    @EnvironmentObject var appIconStateController: AppIconStateController

    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @State private var monitoredAppCount: Int = 0

    var body: some View {
        HStack(spacing: 2) {
            Image("MenuBarTemplateIcon")
                .renderingMode(.template)
                .foregroundColor(isGlobalMonitoringEnabled ?
                    Color(appIconStateController.currentTintColor ?? NSColor.controlAccentColor) : .gray.opacity(0.7))

            if monitoredAppCount > 0 {
                Text(" \(monitoredAppCount)")
                    .font(.system(size: 12))
                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)
            }
        }
        .contentShape(Rectangle())
        .onReceive(cursorMonitor.$monitoredApps) { apps in
            self.monitoredAppCount = apps.count
        }
    }
}

struct SettingsSceneView: View {
    // MARK: Internal

    var body: some View {
        SettingsContainerView()
            .environmentObject(mainSettingsViewModel)
            .onReceive(SettingsService.openSettingsSubject) { _ in
                openSettingsInternal()
            }
    }

    // MARK: Private

    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
    )
    @Environment(\.openSettings) private var openSettingsInternal // For macOS 14+
}
