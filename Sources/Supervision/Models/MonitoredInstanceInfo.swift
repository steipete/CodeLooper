import AppKit // For pid_t
import AXorcist // Add this import
import Foundation
import Defaults // <<< ADDED

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
    public let id: String // Unique ID for the window. Runtime identifier.
                         // NOTE: Current generation relies on PID, title, and index.
                         // Persisted settings using this ID might not be stable across app restarts
                         // if window titles or order change significantly.
    public var windowTitle: String?
    public var windowAXElement: Element?
    public var documentPath: String?
    public var isPaused: Bool = false

    public var isLiveWatchingEnabled: Bool = false
    public var aiAnalysisIntervalSeconds: Int = 10
    public var lastAIAnalysisStatus: AIAnalysisStatus = .off
    public var lastAIAnalysisTimestamp: Date? = nil
    public var lastAIAnalysisResponseMessage: String? = nil

    // Private helper to generate a more stable key for persisted settings
    private func getPersistentSettingsKeyPrefix() -> String {
        // Attempt to use PID + documentPath for better stability if documentPath exists
        // The original `self.id` is derived from PID, title, and index by CursorMonitor
        // For document windows, title might change less often than index, but documentPath is best.
        if let docPath = self.documentPath, !docPath.isEmpty {
            // Try to extract PID from the original id string, assuming format "<PID>-window-..."
            let components = self.id.split(separator: "-")
            if let pidString = components.first, let pid = Int32(pidString) {
                 // Use a combination of PID and a hash of the document path for stability
                return "windowsettings_pid\(pid)_docHash\(docPath.hashValue)"
            } else {
                // Fallback if PID cannot be extracted from id (should not happen with current id format)
                // In this case, use the original id, but this part of the key won't be as stable for doc windows.
                return "windowsettings_id\(self.id.hashValue)_docHash\(docPath.hashValue)"
            }
        } else {
            // For windows without a document path, fall back to using the runtime ID.
            // This retains the original level of stability (or instability) for these windows.
            return "windowsettings_id\(self.id)"
        }
    }

    public init(id: String, windowTitle: String?, axElement: Element? = nil, documentPath: String? = nil, isPaused: Bool = false) {
        self.id = id
        self.windowTitle = windowTitle
        self.windowAXElement = axElement
        self.documentPath = documentPath
        self.isPaused = isPaused

        let settingsKeyPrefix = getPersistentSettingsKeyPrefix()
        let liveWatchingKey = Defaults.Key<Bool>("\(settingsKeyPrefix)_live_watching", default: false)
        self.isLiveWatchingEnabled = Defaults[liveWatchingKey]

        if self.isLiveWatchingEnabled {
            self.lastAIAnalysisStatus = .pending
        } else {
            self.lastAIAnalysisStatus = .off
        }

        let intervalKey = Defaults.Key<Int>("\(settingsKeyPrefix)_ai_interval", default: 10)
        self.aiAnalysisIntervalSeconds = Defaults[intervalKey]
    }

    public func saveAISettings() {
        let settingsKeyPrefix = getPersistentSettingsKeyPrefix()
        let liveWatchingKey = Defaults.Key<Bool>("\(settingsKeyPrefix)_live_watching", default: false)
        Defaults[liveWatchingKey] = self.isLiveWatchingEnabled

        let intervalKey = Defaults.Key<Int>("\(settingsKeyPrefix)_ai_interval", default: 10)
        Defaults[intervalKey] = self.aiAnalysisIntervalSeconds
    }
}

// Ensure DisplayStatus is Sendable if it's not already
// public enum DisplayStatus: Sendable { ... }
// (Assuming DisplayStatus is already Sendable as per previous work)
