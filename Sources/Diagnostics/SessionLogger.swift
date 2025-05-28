import Foundation
import OSLog

// LogLevel is now imported from LogLevel.swift

public struct LogEntry: Identifiable, Codable, Sendable, Equatable {
    // MARK: Lifecycle

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        instancePID: pid_t? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.instancePID = instancePID
    }

    // MARK: Public

    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let instancePID: pid_t? // Process ID, optional
}

public func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
    lhs.id == rhs.id
}

@MainActor // Ensure this class runs on the main thread as its @Published properties drive UI
public final class SessionLogger: ObservableObject {
    // MARK: Lifecycle

    private init(maxEntries: Int = 2000) {
        self.maxEntriesInMemory = maxEntries
    }

    // MARK: Public

    public static let shared = SessionLogger()

    @Published public private(set) var entries: [LogEntry] = []

    public func showLogWindow() { // Implicitly @MainActor
        // Log window functionality has been integrated into the Debug tab in Settings
        // This method is kept for backward compatibility but no longer shows a separate window
        print("Log viewer is now available in Settings > Debug tab")
    }

    public func log(level: LogLevel, message: String, pid: pid_t? = nil) { // Implicitly @MainActor
        let entry = LogEntry(level: level, message: message, instancePID: pid)

        entries.append(entry)
        if entries.count > self.maxEntriesInMemory {
            entries.removeFirst()
        }
    }

    public func clearLog() { // Implicitly @MainActor
        entries.removeAll()
        log(level: .info, message: "Session log cleared by user.")
    }

    public func getEntries() -> [LogEntry] {
        self.entries
    }

    // deinit removed as unused properties requiring cleanup are gone.

    // MARK: Private

    // logFileURL and fileHandle removed as they were unused.
    private var maxEntriesInMemory: Int
}
