import AppKit
import AXorcist
import Diagnostics
import Foundation
import Network

/// Errors that can occur during hook connection
enum ConnectionError: Error, LocalizedError {
    case noAvailablePorts
    
    var errorDescription: String? {
        switch self {
        case .noAvailablePorts:
            return "No available ports for hook connection"
        }
    }
}

/// Errors that can occur with JS hooks
enum JSHookError: Error, LocalizedError {
    case noHookForWindow(String)
    case hookNotConnected
    
    var errorDescription: String? {
        switch self {
        case .noHookForWindow(let windowId):
            return "No hook found for window: \(windowId)"
        case .hookNotConnected:
            return "Hook is not connected"
        }
    }
}

/// Service responsible for managing JavaScript hook lifecycle in Cursor windows.
///
/// JSHookService provides a high-level interface for installing and managing JavaScript
/// hooks in Cursor IDE windows. It manages hook installation, monitoring, error handling,
/// and communication with hooks via WebSocket connections. The service runs on the main actor
/// to ensure thread safety when interacting with UI elements.
///
/// Key responsibilities:
/// - Managing hook installation for new windows
/// - Tracking hook status for monitored windows
/// - Coordinating with port management for WebSocket connections
/// - Handling hook installation errors and recovery
/// - Sending commands to hooked windows
@MainActor
final class JSHookService: Loggable {
    // MARK: - Singleton
    
    static let shared = JSHookService()
    
    private init() {
        logger.info("🚀 Initializing JSHook Service")
        Task { @MainActor in
            await initialize()
        }
    }
    
    // MARK: - Public API
    
    /// Initialize the service and probe for available ports
    func initialize() async {
        guard !state.isProbing else { return }
        
        logger.info("🔍 Starting initial port probe...")
        await probeAvailablePorts()
        logger.info("✅ Initial probe complete. Available ports: \(state.availablePorts.count)")
    }
    
    /// Check if a window has an active hook
    func isWindowHooked(_ windowId: String) -> Bool {
        state.hooks[windowId]?.isHooked ?? false
    }
    
    /// Check if a window has an active hook (alias for compatibility)
    func hasActiveHook(for windowId: String) -> Bool {
        isWindowHooked(windowId)
    }
    
    /// Check if a window has a hook installed (alias for compatibility)
    func hasHookForWindow(_ windowId: String) -> Bool {
        isWindowHooked(windowId)
    }
    
    /// Get the port number for a specific window's hook
    func getPort(for windowId: String) -> UInt16? {
        state.windowPorts[windowId]
    }
    
    /// Install a JavaScript hook for the specified window
    func installHook(for window: MonitoredWindowInfo) async throws {
        guard !isWindowHooked(window.id) else {
            logger.debug("🔄 Hook already exists for window \(window.id)")
            return
        }
        
        // Wait for any ongoing probing to complete
        while state.isProbing {
            try await Task.sleep(for: .seconds(TimingConfiguration.shortDelay))
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
            
            ErrorHandlingUtility.handleAndLog(
                error,
                logger: logger,
                context: "Hook installation failed for window '\(windowTitle)'"
            )
            handleHookInstallationError(error, for: window)
            throw error
        }
    }
    
    /// Inject hook into window (compatibility wrapper)
    func injectHook(into window: MonitoredWindowInfo, portManager _: PortManager) async {
        do {
            try await installHook(for: window)
            logger.info("✅ Hook installed for window: \(window.id)")
        } catch {
            ErrorHandlingUtility.handleAndLog(
                error,
                logger: logger,
                context: "Failed to install hook for window \(window.id)"
            )
            handleHookInstallationError(error, for: window)
        }
    }
    
    /// Handle a new window detection
    func handleNewWindow(_ window: MonitoredWindowInfo) {
        Task { @MainActor in
            await updateWindows([window])
        }
    }
    
    /// Update the service with the current set of monitored windows
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
    
    private var state = ServiceState()
    
    private struct ServiceState {
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
            ErrorHandlingUtility.handleAndLog(
                error,
                logger: logger,
                context: "Hook installation failed with code \(nsError.code)"
            )
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