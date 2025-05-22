import Foundation

/// Represents the information for a monitored Cursor instance, suitable for display in the UI.
public struct MonitoredInstanceInfo: Identifiable, Sendable, Hashable {
    public let id: pid_t // Conforms to Identifiable using pid
    let pid: pid_t
    var displayName: String // e.g., "Cursor (PID: 12345)"
    var status: DisplayStatus
    var isActivelyMonitored: Bool // Is the main loop currently processing this PID (not manually paused)
    var interventionCount: Int = 0 // Number of automatic interventions since last positive activity

    // Add more details as needed for the UI, e.g.:
    // var lastActivityTimestamp: Date?
    // var lastInterventionType: String?
    
    // Implement Hashable
    public static func == (lhs: MonitoredInstanceInfo, rhs: MonitoredInstanceInfo) -> Bool {
        lhs.pid == rhs.pid &&
        lhs.status == rhs.status &&
        lhs.isActivelyMonitored == rhs.isActivelyMonitored &&
        lhs.interventionCount == rhs.interventionCount &&
        lhs.displayName == rhs.displayName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(status)
        hasher.combine(isActivelyMonitored)
        hasher.combine(interventionCount)
        hasher.combine(displayName)
    }
}

/// Enum representing the display status of a monitored Cursor instance.
public enum DisplayStatus: String, Sendable, CaseIterable, Hashable {
    case unknown = "Unknown"
    case active = "Active" // Actively being checked by the monitor loop
    case positiveWork = "Working" // "Generating", "Thinking", "Processing" detected
    case intervening = "Intervening" // An automated intervention is in progress
    case observation = "Observing" // In post-intervention observation window
    case pausedInterventionLimit = "Paused (Limit)" // Paused due to max interventions
    case pausedUnrecoverable = "Paused (Error)" // Paused due to unrecoverable error
    case pausedManually = "Paused (Manual)" // User paused it via UI
    case idle = "Idle" // No specific issues, but no positive work
    case notRunning = "Not Running" // Process with this PID is no longer active
} 