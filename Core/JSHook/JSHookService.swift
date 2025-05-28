import AppKit
import AXorcist
import Diagnostics
import Foundation

@MainActor
class JSHookService {
    // MARK: Lifecycle

    init() {
        jsHookManager.loadPortMappings()
        
        // Start proactive probing immediately
        Task { @MainActor in
            jsHookManager.startProactiveProbing()
        }
    }

    // MARK: Internal

    var hookedWindows: Set<String> {
        jsHookManager.hookedWindows
    }

    func isWindowHooked(_ windowId: String) -> Bool {
        jsHookManager.hasHookForWindow(windowId)
    }

    func loadPortMappings() {
        jsHookManager.loadPortMappings()
    }

    func injectHook(into window: MonitoredWindowInfo, portManager _: PortManager) async {
        logger.info("Starting JS hook injection for window: \(window.id)")

        // Try fast probing first - this is very quick
        jsHookManager.addWindowForFastProbing(window)
        
        // Give fast probe a moment to work (up to 2 seconds)
        for i in 0..<20 {
            if jsHookManager.hasHookForWindow(window.id) {
                logger.info("Fast probe found existing hook for window: \(window.id)")
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        // If no existing hook found, install new one
        do {
            try await jsHookManager.installHook(for: window)
            logger.info("Successfully installed hook for window: \(window.id)")
        } catch {
            logger.error("Failed to install hook for window \(window.id): \(error)")
            handleHookInstallationError(error, for: window)
        }
    }
    
    func addWindowForFastProbing(_ window: MonitoredWindowInfo) {
        // Immediately start fast probing for new windows
        jsHookManager.addWindowForFastProbing(window)
    }
    
    func handleNewWindow(_ window: MonitoredWindowInfo) {
        // Immediately start fast probing for new windows
        addWindowForFastProbing(window)
    }
    
    func installHook(for window: MonitoredWindowInfo) async throws {
        try await jsHookManager.installHook(for: window)
    }

    func checkForExistingHook(in window: MonitoredWindowInfo, portManager _: PortManager) async -> Bool {
        // Probe for existing hooks
        await jsHookManager.probeForExistingHooks(windows: [window])
        return jsHookManager.hasHookForWindow(window.id)
    }

    func probeCommonPorts(for window: MonitoredWindowInfo, portManager _: PortManager) async -> Bool {
        // This is now handled by probeForExistingHooks
        await jsHookManager.probeForExistingHooks(windows: [window])
        return jsHookManager.hasHookForWindow(window.id)
    }

    func stopAllHooks() {
        logger.info("Stopping all JS hooks")
        // Clear all hooks from the manager
        for windowId in jsHookManager.hookedWindows {
            jsHookManager.removeHookedWindow(windowId)
        }
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
