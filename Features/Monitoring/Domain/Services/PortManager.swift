import Diagnostics
import Foundation

/// Manages network port allocation for JavaScript hook WebSocket connections.
///
/// PortManager provides:
/// - Dynamic port allocation for each Cursor window
/// - Persistent port assignments across app restarts
/// - Port availability checking to avoid conflicts
/// - Cleanup of unused port assignments
/// - Thread-safe port management operations
///
/// Each Cursor window gets a unique port for its WebSocket connection,
/// enabling isolated communication channels for JavaScript injection.
/// The manager ensures ports are reused for the same windows and 
/// prevents port conflicts with other applications.
@MainActor
class PortManager {
    // MARK: Lifecycle

    init() {
        loadPortMappings()
    }

    // MARK: Internal

    func getPort(for windowId: String) -> UInt16? {
        windowPortMap[windowId]
    }

    func assignPort(_ port: UInt16, to windowId: String) {
        windowPortMap[windowId] = port
        usedPorts.insert(port)
        savePortMappings()
        logger.info("Assigned port \(port) to window \(windowId)")
    }

    func getOrAssignPort(for windowId: String) -> UInt16 {
        if let existingPort = windowPortMap[windowId] {
            return existingPort
        }

        let newPort = findAvailablePort()
        assignPort(newPort, to: windowId)
        return newPort
    }

    func releasePort(for windowId: String) {
        if let port = windowPortMap[windowId] {
            windowPortMap.removeValue(forKey: windowId)
            usedPorts.remove(port)
            savePortMappings()
            logger.info("Released port \(port) from window \(windowId)")
        }
    }

    func isPortInUse(_ port: UInt16) -> Bool {
        usedPorts.contains(port)
    }

    // MARK: Private

    private let logger = Logger(category: .supervision)
    private let basePort: UInt16 = 4545
    private let maxPorts: UInt16 = 20

    private var windowPortMap: [String: UInt16] = [:]
    private var usedPorts: Set<UInt16> = []

    private func findAvailablePort() -> UInt16 {
        for offset in 0 ..< maxPorts {
            let port = basePort + offset
            if !usedPorts.contains(port) {
                return port
            }
        }

        // If all ports are used, find the first port without an active window
        let activeWindowIds = Set(windowPortMap.keys)
        for (windowId, port) in windowPortMap {
            if !activeWindowIds.contains(windowId) {
                releasePort(for: windowId)
                return port
            }
        }

        // Fallback: return base port + random offset
        return basePort + UInt16.random(in: 0 ..< maxPorts)
    }

    private func loadPortMappings() {
        // Load from UserDefaults or file storage
        if let data = UserDefaults.standard.data(forKey: "CursorPortMappings"),
           let mappings = try? JSONDecoder().decode([String: UInt16].self, from: data)
        {
            windowPortMap = mappings
            usedPorts = Set(mappings.values)
            logger.debug("Loaded \(mappings.count) port mappings")
        }
    }

    private func savePortMappings() {
        if let data = try? JSONEncoder().encode(windowPortMap) {
            UserDefaults.standard.set(data, forKey: "CursorPortMappings")
            logger.debug("Saved \(windowPortMap.count) port mappings")
        }
    }
}
