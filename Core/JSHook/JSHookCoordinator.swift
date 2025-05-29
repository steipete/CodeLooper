import AppKit
import Diagnostics
import Foundation
import Network

/// Unified JavaScript hook coordinator that manages the complete lifecycle
/// of JavaScript injection and communication with Cursor windows.
///
/// This coordinator replaces the separate JSHookManager, JSHookService, and ConnectionManager
/// classes to provide a cleaner, more cohesive API with better error handling and state management.
@MainActor
final class JSHookCoordinator {
    // MARK: - Initialization
    
    static let shared = JSHookCoordinator()
    
    private init() {
        logger.info("🚀 Initializing JSHook Coordinator")
    }
    
    // MARK: - Public API
    
    /// Initialize the coordinator and probe for available ports
    func initialize() async {
        guard !state.isProbing else { return }
        
        logger.info("🔍 Starting initial port probe...")
        await probeAvailablePorts()
        logger.info("✅ Initial probe complete. Available ports: \(state.availablePorts.count)")
    }
    
    /// Check if a window has an active hook
    func hasActiveHook(for windowId: String) -> Bool {
        state.hooks[windowId]?.isHooked ?? false
    }
    
    /// Get the port number for a specific window's hook
    func getPort(for windowId: String) -> UInt16? {
        state.windowPorts[windowId]
    }
    
    /// Install a JavaScript hook for the specified window
    func installHook(for window: MonitoredWindowInfo) async throws {
        guard !hasActiveHook(for: window.id) else {
            logger.debug("🔄 Hook already exists for window \(window.id)")
            return
        }
        
        // Wait for any ongoing probing to complete
        while state.isProbing {
            try await Task.sleep(for: .milliseconds(100))
        }
        
        guard let port = getNextAvailablePort() else {
            throw ConnectionError.noAvailablePorts
        }
        
        let windowTitle = window.windowTitle ?? "Unknown"
        logger.info("🔨 Installing hook for window '\(windowTitle)' on port \(port)")
        
        // Reserve the port
        state.windowPorts[window.id] = port
        state.availablePorts.removeAll { $0 == port }
        
        do {
            let hook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                targetWindowTitle: window.windowTitle
            )
            
            state.hooks[window.id] = hook
            logger.info("✅ Hook installed successfully for '\(windowTitle)'")
            
        } catch {
            // Release the port if installation failed
            state.windowPorts.removeValue(forKey: window.id)
            state.availablePorts.append(port)
            
            logger.error("❌ Hook installation failed: \(error)")
            // Handle specific error types
            handleHookInstallationError(error, for: window)
            throw error
        }
    }
    
    /// Update the coordinator with the current set of monitored windows
    func updateWindows(_ windows: [MonitoredWindowInfo]) async {
        guard !state.isProbing else { return }
        
        let currentWindowIds = Set(state.windowPorts.keys)
        let newWindowIds = Set(windows.map(\.id))
        let removedWindowIds = currentWindowIds.subtracting(newWindowIds)
        
        // Clean up removed windows
        for windowId in removedWindowIds {
            removeHook(for: windowId)
        }
        
        // Re-probe if we need more ports for new windows
        let newWindows = windows.filter { !currentWindowIds.contains($0.id) }
        if !newWindows.isEmpty && state.availablePorts.isEmpty {
            await probeAvailablePorts()
        }
        
        if !removedWindowIds.isEmpty || !newWindows.isEmpty {
            logger.info("🔄 Windows updated. Removed: \(removedWindowIds.count), New: \(newWindows.count)")
        }
    }
    
    /// Send a command to a specific window's hook
    func sendCommand(_ command: [String: Any], to windowId: String) async throws -> String {
        guard let hook = state.hooks[windowId] else {
            throw JSHookError.noHookForWindow(windowId)
        }
        
        guard hook.isHooked else {
            throw JSHookError.hookNotConnected
        }
        
        return try await hook.sendCommand(command)
    }
    
    /// Get all window IDs that have active hooks
    func getAllHookedWindowIds() -> [String] {
        state.hooks.keys.filter { windowId in
            state.hooks[windowId]?.isHooked ?? false
        }
    }
    
    /// Stop all hooks and clean up resources
    func stopAllHooks() {
        logger.info("🛑 Stopping all JS hooks")
        
        for windowId in state.hooks.keys {
            removeHook(for: windowId)
        }
        
        state.availablePorts = Array(Constants.portRange)
        logger.info("✅ All hooks stopped and ports released")
    }
    
    // MARK: - Private Implementation
    
    private let logger = Logger(category: .jshook)
    private var state = CoordinatorState()
    
    private struct CoordinatorState {
        var hooks: [String: CursorJSHook] = [:]
        var windowPorts: [String: UInt16] = [:]
        var availablePorts: [UInt16] = []
        var isProbing = false
    }
    
    private enum Constants {
        static let portRange: ClosedRange<UInt16> = 9001...9010
    }
    
    /// Probe available ports for hook connections
    private func probeAvailablePorts() async {
        state.isProbing = true
        defer { state.isProbing = false }
        
        // Simple approach: prepare all ports in range as available
        // Individual port conflicts will be handled during actual usage
        state.availablePorts = Array(Constants.portRange)
        
        logger.info("🔍 Prepared \(state.availablePorts.count) ports for use")
    }
    
    /// Get the next available port from the pool
    private func getNextAvailablePort() -> UInt16? {
        state.availablePorts.first
    }
    
    /// Remove a hook and release its resources
    private func removeHook(for windowId: String) {
        if let port = state.windowPorts.removeValue(forKey: windowId) {
            state.availablePorts.append(port)
        }
        state.hooks.removeValue(forKey: windowId)
        logger.debug("🗑️ Removed hook for window: \(windowId)")
    }
    
    /// Handle errors that occur during hook installation
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
    
    /// Show alert for automation permission issues
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

