import AppKit // For pid_t
import AXorcist // Add this import
import Foundation

// Renamed from MonitoredInstanceInfo
@MainActor
public struct MonitoredAppInfo: Identifiable { // Made Sendable
    public let id: pid_t // Using PID as unique ID for the app instance
    public var pid: pid_t
    public var displayName: String
    public var status: DisplayStatus // Aggregated status for the app
    public var isActivelyMonitored: Bool
    public var interventionCount: Int // Total interventions for this app instance across all windows
    public var windows: [MonitoredWindowInfo] // List of windows for this app

    // Initializer
    public init(
        id: pid_t,
        pid: pid_t,
        displayName: String,
        status: DisplayStatus,
        isActivelyMonitored: Bool,
        interventionCount: Int,
        windows: [MonitoredWindowInfo] = [] // Initialize with empty windows
    ) {
        self.id = id
        self.pid = pid
        self.displayName = displayName
        self.status = status
        self.isActivelyMonitored = isActivelyMonitored
        self.interventionCount = interventionCount
        self.windows = windows
    }
}

// New struct for window information
@MainActor
public struct MonitoredWindowInfo: Identifiable {
    public let id: String // Unique ID for the window (e.g., from AXUIElement or a generated UUID)
    public var windowTitle: String?
    public var windowAXElement: Element? // Changed from AXorcist.Element to Element
    public var isPaused: Bool = false // NEW: Pause state for this specific window
    // Add other window-specific properties as needed, e.g., specific status for this window
    // For simplicity, the main popover will display windows of the single monitored Cursor app.

    public init(id: String, windowTitle: String?, axElement: Element? = nil, isPaused: Bool = false) { // Added axElement and isPaused
        self.id = id
        self.windowTitle = windowTitle
        self.windowAXElement = axElement
        self.isPaused = isPaused
    }
}

// Ensure DisplayStatus is Sendable if it's not already
// public enum DisplayStatus: Sendable { ... }
// (Assuming DisplayStatus is already Sendable as per previous work) 
