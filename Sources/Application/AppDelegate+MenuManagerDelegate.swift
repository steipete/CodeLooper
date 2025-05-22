import AppKit
import Defaults
import Foundation
import OSLog

/// Extension to make AppDelegate conform to MenuManagerDelegate
@MainActor
extension AppDelegate: MenuManagerDelegate {
    // MARK: - Menu Actions

    func showSettings() {
        logger.info("Settings menu item clicked")
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    func toggleStartAtLogin() {
        logger.info("Toggle start at login clicked")
        let newValue = !Defaults[.startAtLogin]
        Defaults[.startAtLogin] = newValue
        loginItemManager?.syncLoginItemWithPreference()
        logger.info("Start at login set to: \(newValue)")
    }

    func toggleDebugMenu() {
        logger.info("Toggle debug menu clicked")
        let newValue = !Defaults[.showDebugMenu]
        Defaults[.showDebugMenu] = newValue
        logger.info("Debug menu set to: \(newValue)")
    }

    func showAbout() {
        logger.info("About menu item clicked")
        self.windowManager?.showAboutWindow()
    }

    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
