import Foundation

/// Represents a Claude instance for HTTP API
struct HTTPClaudeInstanceInfo: Codable {
    let id: String
    let windowTitle: String
    let processId: Int32
    let isActive: Bool
    let lastSeen: Date
    let textContent: String?
}

/// Represents a Cursor instance for HTTP API
struct HTTPCursorInstanceInfo: Codable {
    let id: String
    let windowTitle: String
    let processId: Int32
    let isActive: Bool
    let lastSeen: Date
    let textContent: String?
    let status: String
}

/// Combined instance list response
struct InstancesResponse: Codable {
    let claudeInstances: [HTTPClaudeInstanceInfo]
    let cursorInstances: [HTTPCursorInstanceInfo]
    let timestamp: Date
}