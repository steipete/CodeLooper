import ApplicationServices
import Diagnostics
import Foundation

/// Provides intervention methods for CursorMonitor
@MainActor
extension CursorMonitor {
    /// Resets all instances and resumes monitoring
    public func resetAllInstancesAndResume() async {
        logger.info("Resetting all instances and resuming monitoring")
        sessionLogger.log(level: .info, message: "Resetting all instances and resuming monitoring")

        // Reset global counters
        instanceStateManager.resetTotalAutomaticInterventionsThisSession()
        totalAutomaticInterventionsThisSessionDisplay = 0
    }

    /// Simulates pressing the Enter key
    internal func pressEnterKey() async -> Bool {
        let enterKeyCode: UInt16 = 36 // Enter key virtual key code

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: enterKeyCode, keyDown: true) else {
            logger.warning("Failed to create key down event for Enter key")
            return false
        }

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: enterKeyCode, keyDown: false) else {
            logger.warning("Failed to create key up event for Enter key")
            return false
        }

        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)

        // Small delay between key down and up
        try? await Task.sleep(for: .milliseconds(50))

        keyUpEvent.post(tap: .cghidEventTap)

        return true
    }

    /// Updates instance display information
    @MainActor
    internal func updateInstanceDisplayInfo(
        for pid: pid_t,
        newStatus: DisplayStatus,
        message _: String? = nil,
        isActive: Bool? = nil,
        interventionCount: Int? = nil
    ) {
        guard let index = monitoredApps.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to update display info for unknown PID: \(pid)")
            return
        }

        var updatedInfo = monitoredApps[index]
        updatedInfo.status = newStatus

        if let isActive {
            updatedInfo.isActivelyMonitored = isActive
        }

        if let interventionCount {
            updatedInfo.interventionCount = interventionCount
        }

        monitoredApps[index] = updatedInfo
    }
}