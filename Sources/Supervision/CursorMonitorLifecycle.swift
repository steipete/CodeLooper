import AppKit
import Diagnostics
import Foundation

/// Manages instance lifecycle operations for CursorMonitor
@MainActor
extension CursorMonitor {
    /// Called when a new Cursor instance is launched
    public func didLaunchInstance(pid: pid_t) {
        logger.info("Instance launched: PID \(pid)")
        sessionLogger.log(level: .info, message: "Instance launched: PID \(pid)")
    }

    /// Called when a Cursor instance terminates
    public func didTerminateInstance(pid: pid_t) {
        logger.info("Instance terminated: PID \(pid)")
        sessionLogger.log(level: .info, message: "Instance terminated: PID \(pid)")
    }

    /// Refreshes the list of monitored instances
    public func refreshMonitoredInstances() {
        // Simplified implementation - actual refreshing handled by appLifecycleManager
        logger.info("Refreshing monitored instances")
    }

    /// Pauses monitoring for a specific instance
    public func pauseMonitoring(for pid: pid_t) {
        guard let index = monitoredApps.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to pause monitoring for unknown PID: \(pid)")
            return
        }
        monitoredApps[index].isActivelyMonitored = false
        logger.info("Paused monitoring for PID: \(pid)")
    }

    /// Resumes monitoring for a specific instance
    public func resumeMonitoring(for pid: pid_t) {
        guard let index = monitoredApps.firstIndex(where: { $0.pid == pid }) else {
            logger.warning("Attempted to resume monitoring for unknown PID: \(pid)")
            return
        }
        monitoredApps[index].isActivelyMonitored = true
        logger.info("Resumed monitoring for PID: \(pid)")
    }

    /// Pauses monitoring for a specific window within an instance
    public func pauseMonitoring(for windowId: String, in pid: pid_t) {
        guard let appIndex = monitoredApps.firstIndex(where: { $0.pid == pid }),
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId })
        else {
            logger.warning("Window ID \(windowId) in PID \(pid) not found for pausing.")
            return
        }
        monitoredApps[appIndex].windows[windowIndex].isPaused = true
        logger.info("Paused monitoring for window ID \(windowId) in PID \(pid)")
        objectWillChange.send()
    }

    /// Resumes monitoring for a specific window within an instance
    public func resumeMonitoring(for windowId: String, in pid: pid_t) {
        guard let appIndex = monitoredApps.firstIndex(where: { $0.pid == pid }),
              let windowIndex = monitoredApps[appIndex].windows.firstIndex(where: { $0.id == windowId })
        else {
            logger.warning("Window ID \(windowId) in PID \(pid) not found for resuming.")
            return
        }
        monitoredApps[appIndex].windows[windowIndex].isPaused = false
        logger.info("Resumed monitoring for window ID \(windowId) in PID \(pid)")
        objectWillChange.send()
    }

    /// Updates instance display information for UI
    public func updateInstanceDisplayInfo(for _: pid_t, newStatus _: DisplayStatus, interventionCount _: Int) {
        // This method is intentionally left minimal as it's called from UI context
        // The actual implementation would update the display info appropriately
    }
}