import Diagnostics
import Foundation

/// Manages JavaScript hook connections using clean probe-once logic
@MainActor
class JSHookManager {
    // MARK: Internal

    private let connectionManager = ConnectionManager()
    private let logger = Logger(category: .jshook)
    
    // MARK: - Public Methods

    func initialize() async {
        logger.info("🚀 Initializing JS Hook Manager")
        await connectionManager.startupProbe()
    }

    func hasHookForWindow(_ windowId: String) -> Bool {
        connectionManager.hasHook(for: windowId)
    }

    func installHook(for window: MonitoredWindowInfo) async throws {
        guard !hasHookForWindow(window.id) else {
            logger.debug("🔄 Hook already exists for window \(window.id)")
            return
        }

        let windowTitle = window.windowTitle ?? "Unknown"
        logger.info("🔨 Installing hook for window '\(windowTitle)'")
        
        try await connectionManager.injectHook(for: window)
        logger.info("✅ Hook installed successfully for '\(windowTitle)'")
    }
    
    func updateWindows(_ windows: [MonitoredWindowInfo]) async {
        await connectionManager.windowsChanged(windows: windows)
    }

    /// Get the port number for a specific window's hook
    func getPort(for windowId: String) -> UInt16? {
        connectionManager.getPort(for: windowId)
    }
    
    /// Send a command to a specific window's hook
    func sendCommand(_ command: [String: Any], to windowId: String) async throws -> String {
        guard let hook = connectionManager.getHook(for: windowId) else {
            throw JSHookError.noHookForWindow(windowId)
        }

        return try await hook.sendCommand(command)
    }

    func getAllHookedWindowIds() -> [String] {
        connectionManager.getAllHookedWindowIds()
    }
    
    @available(*, deprecated, message: "Use sendCommand instead")
    func runJavaScript(_ script: String, on windowId: String) async throws -> String {
        guard let hook = connectionManager.getHook(for: windowId) else {
            throw JSHookError.noHookForWindow(windowId)
        }

        return try await hook.runJS(script)
    }
}

// MARK: - Errors

enum JSHookError: Error, LocalizedError {
    case noHookForWindow(String)
    case hookNotConnected

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .noHookForWindow(windowId):
            "No JavaScript hook available for window: \(windowId)"
        case .hookNotConnected:
            "JavaScript hook is not connected"
        }
    }
}
