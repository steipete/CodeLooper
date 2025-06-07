import Foundation

public struct ClaudeInstance: Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        pid: Int32,
        ttyPath: String,
        workingDirectory: String,
        folderName: String,
        status: String?,
        currentActivity: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.pid = pid
        self.ttyPath = ttyPath
        self.workingDirectory = workingDirectory
        self.folderName = folderName
        self.status = status
        self.currentActivity = currentActivity
        self.lastUpdated = lastUpdated
    }

    // MARK: Public

    public let id: UUID = .init()
    public let pid: Int32
    public let ttyPath: String
    public let workingDirectory: String
    public let folderName: String
    public let status: String?
    public let currentActivity: String? // The live status line from terminal
    public let lastUpdated: Date
}

public enum ClaudeMonitoringState: Sendable {
    case idle
    case monitoring
    case error(String)
}
