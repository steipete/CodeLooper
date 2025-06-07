import Foundation

// MARK: - Claude Instance Models

/// Represents a running Claude CLI instance with comprehensive metadata
public struct ClaudeInstance: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public let pid: Int32
    public let ttyPath: String
    public let workingDirectory: String
    public let folderName: String
    public let status: ClaudeInstanceStatus
    public let currentActivity: ClaudeActivity
    public let lastUpdated: Date
    
    public init(
        id: UUID = UUID(),
        pid: Int32,
        ttyPath: String,
        workingDirectory: String,
        folderName: String,
        status: ClaudeInstanceStatus,
        currentActivity: ClaudeActivity = .idle,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.pid = pid
        self.ttyPath = ttyPath
        self.workingDirectory = workingDirectory
        self.folderName = folderName
        self.status = status
        self.currentActivity = currentActivity
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Claude Instance Status

/// Type-safe status representation for Claude instances
public enum ClaudeInstanceStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case claudeCode = "Claude Code"
    case claudeChat = "Claude Chat"
    case claudeCLI = "Claude CLI"
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .claudeCode: return "terminal.fill"
        case .claudeChat: return "bubble.left.and.bubble.right.fill"
        case .claudeCLI: return "terminal"
        }
    }
}

// MARK: - Claude Activity

/// Type-safe activity representation with parsing capabilities
public struct ClaudeActivity: Sendable, Hashable, Codable, ExpressibleByStringLiteral {
    public let text: String
    public let type: ActivityType
    public let duration: TimeInterval?
    public let tokenCount: Int?
    
    public init(text: String, type: ActivityType? = nil, duration: TimeInterval? = nil, tokenCount: Int? = nil) {
        self.text = text
        self.type = type ?? Self.determineType(from: text)
        self.duration = duration ?? Self.parseDuration(from: text)
        self.tokenCount = tokenCount ?? Self.parseTokenCount(from: text)
    }
    
    public init(stringLiteral value: String) {
        self.init(text: value)
    }
    
    public enum ActivityType: String, Sendable, Hashable, Codable, CaseIterable {
        case idle = "idle"
        case working = "working"
        case generating = "generating"
        case thinking = "thinking"
        case syncing = "syncing"
        case resolving = "resolving"
        case branching = "branching"
        case compacting = "compacting"
        
        public var icon: String {
            switch self {
            case .idle: return "zzz"
            case .working, .generating: return "cpu"
            case .thinking: return "brain"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .resolving: return "magnifyingglass"
            case .branching: return "arrow.branch"
            case .compacting: return "archivebox"
            }
        }
        
        public var color: String {
            switch self {
            case .idle: return "secondary"
            case .working, .generating: return "accent"
            case .thinking: return "blue"
            case .syncing: return "orange"
            case .resolving: return "purple"
            case .branching: return "green"
            case .compacting: return "yellow"
            }
        }
    }
    
    // MARK: - Static Properties
    
    public static let idle = ClaudeActivity(text: "idle", type: .idle)
    
    // MARK: - Parsing Helpers
    
    private static func determineType(from text: String) -> ActivityType {
        let lowercased = text.lowercased()
        
        for type in ActivityType.allCases {
            if lowercased.contains(type.rawValue) {
                return type
            }
        }
        
        // Fallback logic
        if lowercased.contains("…") || lowercased.contains("...") {
            return .working
        }
        
        return .idle
    }
    
    private static func parseDuration(from text: String) -> TimeInterval? {
        // Parse patterns like "(1604s" or "(2210s •"
        let pattern = #"\((\d+)s"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let nsString = text as NSString
        let secondsString = nsString.substring(with: match.range(at: 1))
        return TimeInterval(secondsString)
    }
    
    private static func parseTokenCount(from text: String) -> Int? {
        // Parse patterns like "9.0k tokens" or "1.5k tokens"
        let patterns = [
            #"(\d+\.?\d*)k\s+tokens"#,  // "9.0k tokens"
            #"(\d+)\s+tokens"#          // "500 tokens"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }
            
            let nsString = text as NSString
            let numberString = nsString.substring(with: match.range(at: 1))
            
            if let number = Double(numberString) {
                // If it contains 'k', multiply by 1000
                let multiplier = text.lowercased().contains("k") ? 1000.0 : 1.0
                return Int(number * multiplier)
            }
        }
        
        return nil
    }
}

// MARK: - Monitoring State

/// Type-safe monitoring state with associated values
public enum ClaudeMonitoringState: Sendable, Hashable {
    case idle
    case monitoring(instanceCount: Int)
    case error(String, retryCount: Int = 0)
    
    public var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .monitoring(let count):
            return "Monitoring (\(count) instance\(count == 1 ? "" : "s"))"
        case .error(let message, let retryCount):
            return "Error: \(message)" + (retryCount > 0 ? " (retry \(retryCount))" : "")
        }
    }
    
    public var isMonitoring: Bool {
        if case .monitoring = self { return true }
        return false
    }
}
