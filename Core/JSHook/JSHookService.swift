import AppKit
import AXorcist
import Diagnostics
import Foundation

/// Service responsible for managing JavaScript hook lifecycle in Cursor windows.
///
/// JSHookService provides a high-level interface for installing and managing JavaScript
/// hooks in Cursor IDE windows. It coordinates with the JSHookManager to handle hook
/// installation, monitoring, and error handling. The service runs on the main actor
/// to ensure thread safety when interacting with UI elements.
///
/// Key responsibilities:
/// - Managing hook installation for new windows
/// - Tracking hook status for monitored windows
/// - Coordinating with port management for WebSocket connections
/// - Handling hook installation errors and recovery
@MainActor
class JSHookService {
    // MARK: Lifecycle

    private init() {
        // Initialize with clean probe-once logic
        Task { @MainActor in
            await jsHookManager.initialize()
        }
    }

    // MARK: Internal

    static let shared = JSHookService()

    func isWindowHooked(_ windowId: String) -> Bool {
        jsHookManager.hasHookForWindow(windowId)
    }

    func getPort(for windowId: String) -> UInt16? {
        jsHookManager.getPort(for: windowId)
    }

    func injectHook(into window: MonitoredWindowInfo, portManager _: PortManager) async {
        do {
            try await jsHookManager.installHook(for: window)
            logger.info("✅ Hook installed for window: \(window.id)")
        } catch {
            logger.error("❌ Failed to install hook for window \(window.id): \(error)")
            handleHookInstallationError(error, for: window)
        }
    }

    func handleNewWindow(_ window: MonitoredWindowInfo) {
        // Just notify the manager about the new window - it will handle probing efficiently
        Task { @MainActor in
            await jsHookManager.updateWindows([window])
        }
    }

    func installHook(for window: MonitoredWindowInfo) async throws {
        try await jsHookManager.installHook(for: window)
    }

    func updateWindows(_ windows: [MonitoredWindowInfo]) async {
        await jsHookManager.updateWindows(windows)
    }

    func stopAllHooks() {
        logger.info("🛑 Stopping all JS hooks")
        // Note: Individual hooks will be cleaned up when windows are removed
    }

    func sendCommand(_ command: [String: Any], to windowId: String) async throws -> String {
        try await jsHookManager.sendCommand(command, to: windowId)
    }

    func getAllHookedWindowIds() -> [String] {
        jsHookManager.getAllHookedWindowIds()
    }

    // MARK: Private

    private let logger = Logger(category: .supervision)
    private let jsHookManager = JSHookManager()

    private func handleHookInstallationError(_ error: Error, for _: MonitoredWindowInfo) {
        let nsError = error as NSError

        switch nsError.code {
        case -609: // Connection failed
            logger.error("JavaScript command rejected - possible permission issue")
            showAutomationPermissionAlert()
        case -25200: // Privileges error
            logger.error("System Events access denied")
            showAutomationPermissionAlert()
        default:
            logger.error("Hook installation failed with code \(nsError.code): \(nsError.localizedDescription)")
        }
    }

    private func showAutomationPermissionAlert() {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Automation Permission Required"
            alert.informativeText = """
            CodeLooper needs permission to control Cursor via JavaScript.

            Please grant permission to both CodeLooper and Cursor in:
            System Settings > Privacy & Security > Accessibility
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url =
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
