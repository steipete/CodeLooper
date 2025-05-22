import AppKit // For NSRunningApplication
import Foundation // For pid_t if not covered by AppKit

public enum RecoveryType: String, CaseIterable, Codable, Sendable {
    case connection                 // For connection issues (e.g., clicking "Resume")
    case stopGenerating             // For clicking a "Stop Generating" button if Cursor is stuck generating
    case stuck                      // For general stuck/idle states, typically resolved by sending a nudge message
    case forceStop                  // For scenarios like "resume the conversation" after a loop limit
}

public enum CursorInstanceStatus: Equatable, Sendable {
    case unknown
    case working(detail: String) // e.g., "Generating", "Recent Sidebar Activity"
    case idle
    case recovering(type: RecoveryType, attempt: Int)
    case error(reason: String) // Specific error, might not be unrecoverable yet but needs attention
    case unrecoverable(reason: String)
    case paused // Interventions paused by limit
    
    // Equatable conformance
    public static func == (lhs: CursorInstanceStatus, rhs: CursorInstanceStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case let (.working(ld), .working(rd)):
            return ld == rd
        case (.idle, .idle):
            return true
        case let (.recovering(lt, la), .recovering(rt, ra)):
            return lt == rt && la == ra
        case let (.error(lr), .error(rr)):
            return lr == rr
        case let (.unrecoverable(lr), .unrecoverable(rr)):
            return lr == rr
        case (.paused, .paused):
            return true
        default:
            return false
        }
    }
}

public struct CursorInstanceInfo: Identifiable, Sendable {
    public var id: pid_t { pid }
    public let pid: pid_t
    // NSRunningApplication is not Sendable. We should only store Sendable properties if this struct needs to cross actor boundaries.
    // For now, if CursorMonitor is @MainActor and CursorInstanceInfo is primarily used by @MainActor UI, it might be okay.
    // However, to be safe, let's store only what's needed for UI that IS Sendable.
    public let processIdentifier: pid_t // Same as pid, for clarity if app is removed
    public let bundleIdentifier: String?
    public let localizedName: String?
    // public let icon: NSImage? // NSImage is not Sendable by default
    
    public var status: CursorInstanceStatus
    public var statusMessage: String // User-facing string derived from status

    // Initializer if we decide to pass NSRunningApplication and extract Sendable parts
    init(app: NSRunningApplication, status: CursorInstanceStatus, statusMessage: String) {
        self.pid = app.processIdentifier
        self.processIdentifier = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName
        self.status = status
        self.statusMessage = statusMessage
    }
    
    // Minimal initializer
    init(pid: pid_t, bundleId: String?, name: String?, status: CursorInstanceStatus, statusMessage: String) {
        self.pid = pid
        self.processIdentifier = pid
        self.bundleIdentifier = bundleId
        self.localizedName = name
        self.status = status
        self.statusMessage = statusMessage
    }
} 
