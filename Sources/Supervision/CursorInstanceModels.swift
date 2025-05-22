import AppKit // For NSRunningApplication
import Foundation // For pid_t if not covered by AppKit

public enum RecoveryType: String, CaseIterable, Codable, Sendable, Hashable {
    case connection                 // For connection issues (e.g., clicking "Resume")
    case stopGenerating             // For clicking a "Stop Generating" button if Cursor is stuck generating
    case stuck                      // For general stuck/idle states, typically resolved by sending a nudge message
    case forceStop                  // For scenarios like "resume the conversation" after a loop limit
}

public enum CursorInstanceStatus: Equatable, Sendable, Hashable {
    case unknown
    case working(detail: String) // e.g., "Generating", "Recent Sidebar Activity"
    case idle
    case recovering(type: RecoveryType, attempt: Int)
    case error(reason: String) // Specific error, might not be unrecoverable yet but needs attention
    case unrecoverable(reason: String)
    case paused // Interventions paused by limit
    
    // Equatable conformance (already provided by compiler or manually if complex)
    public static func == (lhs: CursorInstanceStatus, rhs: CursorInstanceStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case let (.working(ld), .working(rd)): return ld == rd
        case (.idle, .idle): return true
        case let (.recovering(lt, la), .recovering(rt, ra)): return lt == rt && la == ra
        case let (.error(lr), .error(rr)): return lr == rr
        case let (.unrecoverable(lr), .unrecoverable(rr)): return lr == rr
        case (.paused, .paused): return true
        default: return false
        }
    }

    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .unknown: hasher.combine(0)
        case .working(let detail):
            hasher.combine(1)
            hasher.combine(detail)
        case .idle: hasher.combine(2)
        case .recovering(let type, let attempt):
            hasher.combine(3)
            hasher.combine(type)
            hasher.combine(attempt)
        case .error(let reason):
            hasher.combine(4)
            hasher.combine(reason)
        case .unrecoverable(let reason):
            hasher.combine(5)
            hasher.combine(reason)
        case .paused: hasher.combine(6)
        }
    }
}

// MARK: - Instance Information (Spec 2.2 & 3.3.B)

/// Holds information about a monitored Cursor instance.
public struct CursorInstanceInfo: Identifiable, Hashable {
    public let id: pid_t // Process ID as the unique identifier
    public var app: NSRunningApplication // This will prevent synthesized Hashable/Equatable
    public var status: CursorInstanceStatus
    public var statusMessage: String
    public var lastInterventionType: RecoveryType? // Changed from InterventionType
    public var pid: pid_t { self.id } // Expose pid, same as id

    // NSRunningApplication is not Sendable or Hashable. 
    // We handle Hashable manually below.

    public let processIdentifier: pid_t // Same as id, for clarity
    public let bundleIdentifier: String?
    public let localizedName: String?
    
    init(app: NSRunningApplication, status: CursorInstanceStatus, statusMessage: String, lastInterventionType: RecoveryType? = nil) {
        self.id = app.processIdentifier
        self.processIdentifier = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName
        self.status = status
        self.statusMessage = statusMessage
        self.app = app
        self.lastInterventionType = lastInterventionType
    }
    
    // Minimal initializer might be less useful now that app is primary source of pid/bundleId etc.
    // init(pid: pid_t, bundleId: String?, name: String?, status: CursorInstanceStatus, statusMessage: String) {
    //     self.id = pid
    //     self.processIdentifier = pid
    //     self.bundleIdentifier = bundleId
    //     self.localizedName = name
    //     self.status = status
    //     self.statusMessage = statusMessage
    //     // `app` would be missing here, potentially problematic.
    // }

    // Manual Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
        hasher.combine(statusMessage)
        hasher.combine(lastInterventionType)
        // Do not hash `app` (NSRunningApplication)
    }

    // Manual Equatable conformance (needed if not synthesized due to non-Equatable properties like `app`)
    public static func == (lhs: CursorInstanceInfo, rhs: CursorInstanceInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.status == rhs.status &&
               lhs.statusMessage == rhs.statusMessage &&
               lhs.lastInterventionType == rhs.lastInterventionType &&
               lhs.app == rhs.app // NSRunningApplication is Equatable by its processIdentifier
    }
}

// MARK: - String Hashing for State Comparison

extension String {
    /// Generates a simple, stable hash for a string. Useful for detecting changes in UI element text.
    /// Note: This is not a cryptographic hash. For simple change detection only.
    func stableHash() -> Int {
        var hash = 0
        for char in self.unicodeScalars {
            hash = 31 &* hash &+ Int(char.value)
        }
        return hash
    }
}

// MARK: - Intervention Type (Spec 2.3 & 3.3.B)

// ... existing code ... 
