import Diagnostics
import Foundation

protocol HeartbeatMonitorDelegate: AnyObject {
    func heartbeatMonitor(_ monitor: HeartbeatMonitor, didUpdateStatus status: HeartbeatStatus, for windowId: String)
}

@MainActor
class HeartbeatMonitor {
    // MARK: Lifecycle

    init() {
        setupNotificationObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Internal

    weak var delegate: HeartbeatMonitorDelegate?

    func setupHeartbeatListener() {
        logger.info("Setting up heartbeat listener")
        startHeartbeatMonitoring()
    }
    
    func registerWindowPort(_ windowId: String, port: UInt16) {
        windowPortMapping[port] = windowId
        logger.debug("Registered window \(windowId) on port \(port)")
    }
    
    func unregisterWindowPort(_ port: UInt16) {
        if let windowId = windowPortMapping.removeValue(forKey: port) {
            lastHeartbeats.removeValue(forKey: windowId)
            logger.debug("Unregistered window \(windowId) from port \(port)")
        }
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
    private var windowPortMapping: [UInt16: String] = [:] // port -> windowId
    private var lastHeartbeats: [String: Date] = [:]
    // Track when we last logged the "before registration" message for each port
    private var lastUnregisteredPortLogTime: [UInt16: Date] = [:] // windowId -> last heartbeat

    private func startHeartbeatMonitoring() {
        heartbeatListenerTask?.cancel()

        heartbeatListenerTask = Task {
            while !Task.isCancelled {
                checkAllHeartbeats()

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeartbeatNotification(_:)),
            name: Notification.Name("CursorHeartbeat"),
            object: nil
        )
    }
    
    @objc private func handleHeartbeatNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let port = userInfo["port"] as? UInt16 else {
            logger.warning("Received heartbeat without port information")
            return
        }
        
        guard let windowId = windowPortMapping[port] else {
            // This can happen during initial setup - heartbeats arrive before port registration
            // Only log this message once every 10 seconds per port to reduce spam
            let now = Date()
            if let lastLog = lastUnregisteredPortLogTime[port], now.timeIntervalSince(lastLog) < 10 {
                // Skip logging
            } else {
                logger.debug("Received heartbeat for port \(port) before window registration (this is normal during setup)")
                lastUnregisteredPortLogTime[port] = now
            }
            return
        }
        
        let version = userInfo["version"] as? String ?? "unknown"
        let location = userInfo["location"] as? String
        let resumeNeeded = userInfo["resumeNeeded"] as? Bool ?? false
        
        let heartbeatData = HeartbeatData(
            version: version,
            timestamp: Date(),
            isPaused: resumeNeeded,
            location: location
        )
        
        Task { @MainActor in
            processHeartbeat(from: windowId, data: heartbeatData)
            lastHeartbeats[windowId] = Date()
        }
    }
    
    private func checkAllHeartbeats() {
        // Check for timed out heartbeats
        let now = Date()
        for (windowId, lastHeartbeat) in lastHeartbeats {
            if now.timeIntervalSince(lastHeartbeat) > heartbeatTimeout {
                logger.warning("Heartbeat timeout for window \(windowId)")
                var status = HeartbeatStatus()
                status.lastHeartbeat = lastHeartbeat
                status.isAlive = false
                delegate?.heartbeatMonitor(self, didUpdateStatus: status, for: windowId)
            }
        }
    }
}

// MARK: - Supporting Types

struct HeartbeatData {
    let version: String
    let timestamp: Date
    let isPaused: Bool
    let location: String?
}
