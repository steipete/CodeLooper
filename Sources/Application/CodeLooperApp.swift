import Defaults
import Diagnostics
import KeyboardShortcuts
import os
import SwiftUI
import Logging
import Combine // For .onReceive

@main
struct CodeLooperApp: App {
    // MARK: - Properties

    // Use @NSApplicationDelegateAdaptor to connect AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

    // MARK: - Initialization

    init() {
        // Perform one-time setup for the logging system.
        Diagnostics.Logger.bootstrap(destination: .console, minLevel: .debug)
        // If osLog is also desired:
        // Diagnostics.Logger.bootstrap(destination: .osLog, minLevel: .debug)
        // Note: swift-log's LoggingSystem.bootstrap typically replaces the handler factory.
        // To use multiple handlers, MultiplexLogHandler should be configured within LoggingSystemSetup.

        logger.info("CodeLooperApp initialized. ScenePhase: \(scenePhase)")
        
        // HACK: Opens settings right when app starts.
        // We use this for speeding up the debug loop
        #if DEBUG
        DispatchQueue.main.async { [self] in
            openSettings()
        }
        #endif
    }

    @ViewBuilder
    private var menuBarContent: some View {
        MainPopoverView()
            .environmentObject(sessionLogger)
            .environmentObject(cursorMonitor)
    }
    
    private var menuBarLabelView: some View { // Renamed for clarity as it's a View
        HStack(spacing: 2) {
            Image("MenuBarTemplateIcon")
                .renderingMode(.template)
                // Use .foregroundColor for template images for proper tinting
                .foregroundColor(isGlobalMonitoringEnabled ? Color(appIconStateController.currentTintColor ?? NSColor.controlAccentColor) : .gray.opacity(0.7))
            
            let count = cursorMonitor.monitoredApps.count
            if count > 0 {
                Text(" \(count)") // Add space for padding from icon
                    .font(.system(size: 12)) // Consistent with typical menu bar extras
                    // Text color should ideally adapt to the effective appearance (dark/light mode)
                    // or match the icon's tint logic if it implies status.
                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)
            }
        }
        .contextMenu { // This will be the "right-click" menu
            SettingsLink { Text("Settings...") }
            
            Button(action: {
                startAtLogin.toggle()
                // Ensure AppDelegate and its services are available
                AppDelegate.shared?.loginItemManager?.syncLoginItemWithPreference()
                logger.info("Toggled Start at Login to: \(startAtLogin)")
            }) {
                HStack {
                    Text("Start CodeLooper at Login")
                    Spacer()
                    if startAtLogin { Image(systemName: "checkmark") }
                }
            }

            Divider()
            
            if showDebugMenu {
                Menu("Debug Options") {
                    Button("Debug Action 1") { logger.info("Debug Action 1 Tapped") }
                    Button("Toggle AXpector") { NotificationCenter.default.post(name: .showAXpectorWindow, object: nil) }
                }
                Divider()
            }

            Button("About CodeLooper") {
                // Ensure AppDelegate and its windowManager are available
                AppDelegate.shared?.windowManager?.showAboutWindow()
                logger.info("About CodeLooper menu item tapped.")
            }

            Divider()
            Button("Quit CodeLooper") { NSApp.terminate(nil) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            // This is the content for the popover (left-click)
            menuBarContent
        } label: {
            menuBarLabelView // The label now includes the context menu
        }
        
        .menuBarExtraStyle(.window) // Makes the content (MainPopoverView) a popover

        Settings {
            SettingsSceneView()
                .environmentObject(sessionLogger)
        }
        
    }
}

struct SettingsSceneView: View {
    @StateObject private var mainSettingsViewModel = MainSettingsViewModel(
        loginItemManager: LoginItemManager.shared,
        updaterViewModel: UpdaterViewModel(sparkleUpdaterManager: nil)
    )
    @Environment(\.openSettings) private var openSettingsInternal // For macOS 14+
    
    var body: some View {
        SettingsContainerView()
            .environmentObject(mainSettingsViewModel)
            .onReceive(SettingsService.openSettingsSubject) { _ in
                openSettingsInternal()
            }
    }
}

// Ensure any necessary supporting structs or extensions (like KeyboardShortcuts.Name definitions
// or Notification.Name definitions if not globally available) are accessible.
// For example, if these are used by settings views:
// extension KeyboardShortcuts.Name {
//     static let toggleMonitoring = Self("toggleMonitoring", default: .init(.m, modifiers: [.command, .shift]))
// }
// extension Notification.Name {
//    static let menuBarVisibilityChanged = Notification.Name("menuBarVisibilityChanged")
// } 
