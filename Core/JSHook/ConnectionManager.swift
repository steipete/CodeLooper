import Diagnostics
import Foundation
import Network

/// Manages the entire JavaScript hook connection lifecycle with clean probe-once logic
@MainActor
final class ConnectionManager {
    // MARK: - State
    
    private var probedPorts: Set<UInt16> = []
    private var availablePorts: [UInt16] = []
    private var windowPorts: [String: UInt16] = [:]
    private var isProbing = false
    private var hooks: [String: CursorJSHook] = [:]
    
    // MARK: - Configuration
    
    private let portRange: ClosedRange<UInt16> = 9001...9010  // Probe exactly 10 ports
    private let logger = Logger(category: .jshook)
    
    // MARK: - Public API
    
    func startupProbe() async {
        guard !isProbing else { return }
        
        logger.info("🚀 Starting initial port probe...")
        await probeAvailablePorts()
        logger.info("✅ Initial probe complete. Available ports: \(availablePorts)")
    }
    
    func windowsChanged(windows: [MonitoredWindowInfo]) async {
        guard !isProbing else { return }
        
        let newWindows = windows.filter { !windowPorts.keys.contains($0.id) }
        let removedWindowIds = Set(windowPorts.keys).subtracting(windows.map(\.id))
        
        if !newWindows.isEmpty || !removedWindowIds.isEmpty {
            logger.info("🔄 Windows changed. New: \(newWindows.count), Removed: \(removedWindowIds.count)")
            
            // Clean up removed windows
            for windowId in removedWindowIds {
                if let port = windowPorts.removeValue(forKey: windowId) {
                    availablePorts.append(port)
                    hooks.removeValue(forKey: windowId)
                }
            }
            
            // Re-probe if we have new windows and need ports
            if !newWindows.isEmpty && availablePorts.isEmpty {
                await probeAvailablePorts()
            }
        }
    }
    
    func injectHook(for window: MonitoredWindowInfo) async throws {
        // Wait for any ongoing probing to complete
        while isProbing {
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Get an available port
        guard let port = getNextAvailablePort() else {
            throw ConnectionError.noAvailablePorts
        }
        
        // Reserve the port for this window
        windowPorts[window.id] = port
        availablePorts.removeAll { $0 == port }
        
        logger.info("💉 Injecting hook for window '\(window.windowTitle ?? "Unknown")' on port \(port)")
        
        do {
            // Create and inject the hook
            let hook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                targetWindowTitle: window.windowTitle
            )
            
            hooks[window.id] = hook
            logger.info("✅ Hook successfully injected and connected on port \(port)")
            
        } catch {
            // Release the port if injection failed
            windowPorts.removeValue(forKey: window.id)
            availablePorts.append(port)
            logger.error("❌ Hook injection failed: \(error)")
            throw error
        }
    }
    
    func getHook(for windowId: String) -> CursorJSHook? {
        hooks[windowId]
    }
    
    func hasHook(for windowId: String) -> Bool {
        hooks[windowId] != nil
    }
    
    // MARK: - Private Implementation
    
    private func probeAvailablePorts() async {
        isProbing = true
        defer { isProbing = false }
        
        // Simple approach: just assign all ports in the range as available
        // We'll handle conflicts when they occur during actual usage
        availablePorts = Array(portRange)
        
        logger.info("🔍 Prepared \(availablePorts.count) ports for use")
    }
    
    private func getNextAvailablePort() -> UInt16? {
        availablePorts.first
    }
}

// MARK: - Errors

enum ConnectionError: Error, LocalizedError {
    case noAvailablePorts
    case probingInProgress
    
    var errorDescription: String? {
        switch self {
        case .noAvailablePorts:
            "No available ports for JavaScript hook"
        case .probingInProgress:
            "Port probing is still in progress"
        }
    }
}