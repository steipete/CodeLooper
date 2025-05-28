import Foundation

public enum AIAnalysisStatus: String, Codable, CaseIterable, Identifiable {
    case working
    case notWorking
    case pending // Analysis in progress or scheduled
    case error   // Error during analysis
    case off     // Live watching is disabled
    case unknown // New case

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .working: return "Working"
        case .notWorking: return "Not Working"
        case .pending: return "Pending Analysis"
        case .error: return "Analysis Error"
        case .off: return "Live Watching Off"
        case .unknown: return "Unknown" // Display name for the new case
        }
    }
} 