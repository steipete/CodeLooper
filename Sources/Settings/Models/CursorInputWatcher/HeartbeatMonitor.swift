import Diagnostics
import Foundation

protocol HeartbeatMonitorDelegate: AnyObject {
    func heartbeatMonitor(_ monitor: HeartbeatMonitor, didUpdateStatus status: HeartbeatStatus, for windowId: String)
}

@MainActor
class HeartbeatMonitor {
    // MARK: Lifecycle

    init() {}

    deinit {
        // Stop is handled by Task cancellation
    }

    // MARK: Internal

    weak var delegate: HeartbeatMonitorDelegate?

    func setupHeartbeatListener() {
        logger.info("Setting up heartbeat listener")
        startHeartbeatMonitoring()
    }

    func stop() {
        logger.info("Stopping heartbeat monitor")
        heartbeatListenerTask?.cancel()
        heartbeatListenerTask = nil
    }

    func processHeartbeat(from windowId: String, data: HeartbeatData) {
        var status = HeartbeatStatus()
        status.lastHeartbeat = Date()
        status.isAlive = true
        status.resumeNeeded = data.isPaused
        status.hookVersion = data.version
        status.location = data.location

        delegate?.heartbeatMonitor(self, didUpdateStatus: status, for: windowId)

        if data.isPaused {
            logger.warning("Hook for window \(windowId) reports paused state")
        }
    }

    func checkHeartbeatTimeout(for _: String, lastHeartbeat: Date?) -> Bool {
        guard let lastHeartbeat else { return true }
        return Date().timeIntervalSince(lastHeartbeat) > heartbeatTimeout
    }

    // MARK: Private

    private let logger = Logger(category: .supervision)
    private var heartbeatListenerTask: Task<Void, Never>?
    private let heartbeatTimeout: TimeInterval = 10.0

    private func startHeartbeatMonitoring() {
        heartbeatListenerTask?.cancel()

        heartbeatListenerTask = Task {
            while !Task.isCancelled {
                checkAllHeartbeats()

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }

    private func checkAllHeartbeats() {
        // This is a simplified version - in a real implementation,
        // you would check actual heartbeat data from hooks

        // Example heartbeat check logic would go here
        // For each window with a hook:
        // 1. Check last heartbeat time
        // 2. Update status
        // 3. Notify delegate
    }
}

// MARK: - Supporting Types

struct HeartbeatData {
    let version: String
    let timestamp: Date
    let isPaused: Bool
    let location: String?
}
