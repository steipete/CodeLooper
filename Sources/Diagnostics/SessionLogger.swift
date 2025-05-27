import Foundation

// OSLog import might still be useful for other purposes or if LogLevel itself uses it.
import AppKit // Added AppKit for NSWindowController, NSWindow etc.
import OSLog
import SwiftUI // Added SwiftUI for NSHostingView and LogSettingsView if it's SwiftUI

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
        if Self.logWindowController == nil {
            let logView = LogSettingsView()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Session Log"
            window.contentView = NSHostingView(rootView: logView.environmentObject(self))
            window.isReleasedWhenClosed = false

            Self.logWindowController = NSWindowController(window: window)
        }
        Self.logWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    // logWindowController is static and already marked @MainActor in its previous declaration.
    // Making it private static as it's only used within showLogWindow.
    private static var logWindowController: NSWindowController?

    // logFileURL and fileHandle removed as they were unused.
    private var maxEntriesInMemory: Int
}
