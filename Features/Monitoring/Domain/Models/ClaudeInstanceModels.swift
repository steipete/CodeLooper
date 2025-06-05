import Foundation

public struct ClaudeInstance: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let pid: Int32
    public let ttyPath: String
    public let workingDirectory: String
    public let folderName: String
    public let status: String?
    public let lastUpdated: Date
    
    public init(
        pid: Int32,
        ttyPath: String,
        workingDirectory: String,
        folderName: String,
        status: String?,
        lastUpdated: Date = Date()
    ) {
        self.pid = pid
        self.ttyPath = ttyPath
        self.workingDirectory = workingDirectory
        self.folderName = folderName
        self.status = status
        self.lastUpdated = lastUpdated
    }
}

public enum ClaudeMonitoringState: Sendable {
    case idle
    case monitoring
    case error(String)
}