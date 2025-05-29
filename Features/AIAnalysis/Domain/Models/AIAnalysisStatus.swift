import Foundation

/// Status of AI-powered window analysis operations.
///
/// Tracks the current state of AI analysis including:
/// - Active analysis (working/not working)
/// - Pending or scheduled analysis
/// - Error conditions during analysis
/// - Disabled state when live watching is off
/// - Unknown states for error handling
public enum AIAnalysisStatus: String, Codable, CaseIterable, Identifiable {
    case working
    case notWorking
    case pending // Analysis in progress or scheduled
    case error // Error during analysis
    case off // Live watching is disabled
    case unknown // New case

    // MARK: Public

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .working: "Working"
        case .notWorking: "Not Working"
        case .pending: "Pending Analysis"
        case .error: "Analysis Error"
        case .off: "Live Watching Off"
        case .unknown: "Unknown" // Display name for the new case
        }
    }
}
