import Foundation
// OSLog import might still be useful for other purposes or if LogLevel itself uses it.
import OSLog
import AppKit // Added AppKit for NSWindowController, NSWindow etc.
import SwiftUI // Added SwiftUI for NSHostingView and LogSettingsView if it's SwiftUI

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
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private var maxEntriesInMemory: Int // Changed to var to be set in init
    @MainActor @Published private(set) var logWindowController: NSWindowController? = nil // For showing the log window

    // Making shared static let is a common pattern for actor singletons.
    public static let shared = SessionLogger()

    // Default initializer for the shared instance.
    private init(maxEntries: Int = 2000) { // Default to 2000 to match previous constant
        self.maxEntriesInMemory = maxEntries
    }

    public func log(level: LogLevel, message: String, pid: pid_t? = nil) {
        let entry = LogEntry(level: level, message: message, instancePID: pid)
        entries.insert(entry, at: 0) // Insert at the beginning for newest first
        if entries.count > self.maxEntriesInMemory { // Used self.maxEntriesInMemory
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

    // Method to toggle or show the log window
    @MainActor
    public func showLogWindow() async {
        if self.logWindowController == nil { // No await needed for @MainActor property from @MainActor func
            let logView = LogSettingsView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("SessionLogWindow")
            window.contentView = NSHostingView(rootView: logView)
            window.title = "Session Log"
            // Direct assignment is fine now as both context and property are @MainActor
            self.logWindowController = NSWindowController(window: window)
        }
        self.logWindowController?.showWindow(self) // No await needed for @MainActor property
        self.logWindowController?.window?.makeKeyAndOrderFront(self) // No await needed
    }

    deinit {
        // ... existing code ...
    }
}
