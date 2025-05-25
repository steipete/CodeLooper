import Defaults
import Diagnostics
import KeyboardShortcuts
import os
import SwiftUI
import Logging
import Combine // For .onReceive
import MenuBarExtraAccess

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
    @State private var isMenuPresented: Bool = false // tracks menu presentation for MenuBarExtraAccess

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
    
    @ViewBuilder
    private func menuBarLabelView(cursorMonitor: CursorMonitor) -> some View {
        HStack(spacing: 2) {
            Image("MenuBarTemplateIcon")
                .renderingMode(.template)
                .foregroundColor(isGlobalMonitoringEnabled ? Color(appIconStateController.currentTintColor ?? NSColor.controlAccentColor) : .gray.opacity(0.7))
            
            let count = cursorMonitor.monitoredApps.count
            if count > 0 {
                Text(" \\(count)") // Add space for padding from icon
                    .font(.system(size: 12)) // Consistent with typical menu bar extras
                    .foregroundColor(isGlobalMonitoringEnabled ? .primary : .secondary)
            }
        }
        .contentShape(Rectangle())
    }

    var body: some Scene {
        MenuBarExtra {
            // This is the content for the popover (left-click)
            menuBarContent
        } label: {
            menuBarLabelView(cursorMonitor: cursorMonitor)
        }
        
        .menuBarExtraStyle(.window) // Makes the content (MainPopoverView) a popover
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            // This block is now only for direct NSStatusItem manipulation if needed in the future,
            // but we are not calling MenuBarStatusRightClickHelper.shared.attach here anymore.
            // logger.info("StatusItem available: \(statusItem)")
        }

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
