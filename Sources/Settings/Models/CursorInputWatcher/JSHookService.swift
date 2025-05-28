import Foundation
import AppKit
import AXorcist
import Diagnostics

@MainActor
class JSHookService {
    // MARK: Lifecycle
    
    init() {
        loadPortMappings()
    }
    
    // MARK: Internal
    
    private(set) var hookedWindows = Set<String>()
    
    func isWindowHooked(_ windowId: String) -> Bool {
        hookedWindows.contains(windowId)
    }
    
    func loadPortMappings() {
        // Load persisted port mappings if needed
        logger.debug("Loading port mappings")
    }
    
    func injectHook(into window: MonitoredWindowInfo, portManager: PortManager) async {
        guard !isWindowHooked(window.id) else {
            logger.info("Window \(window.id) already hooked")
            return
        }
        
        logger.info("Starting JS hook injection for window: \(window.id)")
        
        // Check for existing hook
        if await checkForExistingHook(in: window, portManager: portManager) {
            logger.info("Found existing hook for window: \(window.id)")
            return
        }
        
        // Probe common ports
        if await probeCommonPorts(for: window, portManager: portManager) {
            logger.info("Connected to existing hook on common port for window: \(window.id)")
            return
        }
        
        // Install new hook
        await installNewHook(in: window, portManager: portManager)
    }
    
    func checkForExistingHook(in window: MonitoredWindowInfo, portManager: PortManager) async -> Bool {
        guard let element = window.windowAXElement else { return false }
        
        // Check console for existing hooks
        if let consoleResponse = await checkConsoleForHooks(element) {
            logger.debug("Console response: \(consoleResponse)")
            // Parse console output to find existing hook
            if let data = consoleResponse.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let port = json["port"] as? Int {
                let portNum = UInt16(port)
                hookedWindows.insert(window.id)
                portManager.assignPort(portNum, to: window.id)
                return true
            }
        }
        
        return false
    }
    
    func probeCommonPorts(for window: MonitoredWindowInfo, portManager: PortManager) async -> Bool {
        let commonPorts: [UInt16] = [4545, 4546, 4547, 4548]
        
        for port in commonPorts {
            if await probePort(port, for: window, portManager: portManager) {
                return true
            }
        }
        
        return false
    }
    
    func stopAllHooks() {
        logger.info("Stopping all JS hooks")
        hookedWindows.removeAll()
    }
    
    // MARK: Private
    
    private let logger = Logger(category: .supervision)
    
    private func checkConsoleForHooks(_ element: Element) async -> String? {
        // TODO: Implement JavaScript execution via AXorcist
        // Script to check for existing hooks:
        // (function() {
        //     if (window.cursorHook) {
        //         return JSON.stringify({
        //             version: window.cursorHook.version,
        //             port: window.cursorHook.port,
        //             status: 'active'
        //         });
        //     }
        //     return null;
        // })();
        
        // For now, return nil
        return nil
    }
    
    private func probePort(_ port: UInt16, for window: MonitoredWindowInfo, portManager: PortManager) async -> Bool {
        do {
            _ = try await CursorJSHook(port: port)
            // TODO: Implement test connection method
            let isConnected = false
            if isConnected {
                hookedWindows.insert(window.id)
                portManager.assignPort(port, to: window.id)
                logger.info("Connected to hook on port \(port) for window \(window.id)")
                return true
            }
        } catch {
            logger.debug("Port \(port) probe failed: \(error)")
        }
        
        return false
    }
    
    private func installNewHook(in window: MonitoredWindowInfo, portManager: PortManager) async {
        guard window.windowAXElement != nil else {
            logger.error("No AXElement for window \(window.id)")
            return
        }
        
        let port = portManager.getOrAssignPort(for: window.id)
        do {
            _ = try await CursorJSHook(port: port)
            // TODO: Implement install in browser method
            // For now, just mark as hooked
            hookedWindows.insert(window.id)
            logger.info("Successfully installed hook on port \(port) for window \(window.id)")
        } catch {
            logger.error("Failed to install hook: \(error)")
            handleHookInstallationError(error, for: window)
        }
    }
    
    private func handleHookInstallationError(_ error: Error, for window: MonitoredWindowInfo) {
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
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}