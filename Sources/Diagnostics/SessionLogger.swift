import Foundation
// OSLog import might still be useful for other purposes or if LogLevel itself uses it.
import OSLog

// LogLevel is now imported from LogLevel.swift
// public enum LogLevel: String, Codable, CaseIterable, Sendable { ... } // REMOVED

public struct LogEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel // Uses the existing LogLevel from LogLevel.swift
    public let message: String
    public let instancePID: pid_t? // Process ID, optional

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
}

// To conform to ObservableObject, an actor needs to be careful about its published properties.
// The mutations to @Published properties need to happen in a way that's safe with the actor's isolation.
public actor SessionLogger: ObservableObject {
    // @Published takes care of publishing changes on the MainActor for SwiftUI views.
    @Published public private(set) var entries: [LogEntry] = []
    
    private let maxEntries: Int

    // Making shared static let is a common pattern for actor singletons.
    public static let shared = SessionLogger()

    // Default initializer for the shared instance.
    private init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    public func log(level: LogLevel, message: String, pid: pid_t? = nil) {
        let entry = LogEntry(level: level, message: message, instancePID: pid)
        entries.insert(entry, at: 0) // Insert at the beginning for newest first
        if entries.count > maxEntries {
            entries.removeLast()
        }
    }

    public func clearLog() {
        entries.removeAll()
        log(level: .info, message: "Session log cleared by user.")
    }
    
    // Provide a nonisolated way to access entries for observation if direct binding in SwiftUI isn't sufficient
    // or if other non-actor parts of the app need to observe it. However, @ObservedObject typically handles this.
    // For direct use with @ObservedObject or @StateObject, the @Published property is sufficient.
}
