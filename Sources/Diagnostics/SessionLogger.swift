import Foundation
// OSLog import might still be useful for other purposes or if LogLevel itself uses it.
import OSLog
import AppKit // Added AppKit for NSWindowController, NSWindow etc.
import SwiftUI // Added SwiftUI for NSHostingView and LogSettingsView if it's SwiftUI

// LogLevel is now imported from LogLevel.swift
// public enum LogLevel: String, Codable, CaseIterable, Sendable { ... } // REMOVED

public struct LogEntry: Identifiable, Codable, Sendable, Equatable {
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

// MARK: - Equatable Conformance for LogEntry (if not already provided by Codable synthesis)
// Explicitly adding for clarity and ensuring it meets requirements.
public func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
    lhs.id == rhs.id
}

// To conform to ObservableObject, an actor needs to be careful about its published properties.
// The mutations to @Published properties need to happen in a way that's safe with the actor's isolation.
public actor SessionLogger: ObservableObject {
    // @Published takes care of publishing changes on the MainActor for SwiftUI views.
    @Published public private(set) var entries: [LogEntry] = []
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private var maxEntriesInMemory: Int // Changed to var to be set in init

    // Making shared static let is a common pattern for actor singletons.
    public static let shared = SessionLogger()

    // Default initializer for the shared instance.
    private init(maxEntries: Int = 2000) { // Default to 2000 to match previous constant
        self.maxEntriesInMemory = maxEntries
    }

    // Window controller for the log view - stored on MainActor since it's UI
    @MainActor private static var logWindowController: NSWindowController?

    @MainActor // Ensure UI operations are on the main thread
    public func showLogWindow() {
        if Self.logWindowController == nil {
            // Assuming LogSettingsView is the view that displays logs.
            // It might need access to self (SessionLogger) to display entries.
            // If LogSettingsView is part of a larger SettingsView, this might need adjustment.
            // For now, assume LogSettingsView can be presented on its own.
            let logView = LogSettingsView() // This view needs access to the logger, typically via @EnvironmentObject or passed in.
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Session Log"
            window.contentView = NSHostingView(rootView: logView.environmentObject(self))
            window.isReleasedWhenClosed = false // We manage its lifecycle
            
            Self.logWindowController = NSWindowController(window: window)
        }
        Self.logWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func log(level: LogLevel, message: String, pid: pid_t? = nil) {
        let entry = LogEntry(level: level, message: message, instancePID: pid)
        // Append new entries to the end (FIFO for storage)
        entries.append(entry)
        // If over limit, remove the oldest entry (from the front)
        if entries.count > self.maxEntriesInMemory {
            entries.removeFirst()
        }
    }

    public func clearLog() {
        entries.removeAll()
        log(level: .info, message: "Session log cleared by user.")
    }
    
    // Provide a nonisolated way to access entries for observation if direct binding in SwiftUI isn't sufficient
    // or if other non-actor parts of the app need to observe it. However, @ObservedObject typically handles this.
    // For direct use with @ObservedObject or @StateObject, the @Published property is sufficient.

    // Method to allow LogSettingsView to fetch entries for display
    public nonisolated func getEntries() async -> [LogEntry] {
        return await self.entries
    }

    deinit {
        // ... existing code ...
    }
}
