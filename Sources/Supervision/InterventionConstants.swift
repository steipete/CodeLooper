import Foundation

enum InterventionConstants {
    // MARK: - Keywords

    static let positiveWorkKeywords = [
        "Thinking", "Processing", "Generating", "Loading", "Working",
        "Analyzing", "Computing", "Searching", "Fetching", "Compiling",
        "Running", "Executing", "Building", "Testing", "Deploying",
        "Indexing", "Parsing", "Optimizing", "Resolving", "Downloading",
        "Uploading", "Syncing", "Updating", "Installing", "Configuring",
        "Initializing", "Starting", "Connecting", "Authenticating", "Verifying",
        "Calculating", "Rendering", "Formatting", "Validating", "Scanning",
    ]

    static let errorIndicatingKeywords = [
        "Error", "Failed", "Exception", "Crash", "Timeout",
        "Refused", "Denied", "Rejected", "Invalid", "Unauthorized",
        "Forbidden", "Not Found", "Unavailable", "Disconnected", "Offline",
    ]

    static let sidebarKeywords = ["Copilot", "Chat", "Assistant", "Help", "AI", "GPT", "Claude", "LLM"]

    static let unrecoverableStateKeywords = [
        "Fatal", "Critical", "Unrecoverable", "Panic", "Abort",
        "Segmentation Fault", "Core Dump", "Out of Memory", "Stack Overflow",
    ]

    static let connectionIssueKeywords = [
        "Connection", "Network", "Internet", "Offline", "Disconnected",
        "Cannot Connect", "Connection Lost", "Connection Failed", "No Internet",
        "Network Error", "Connection Refused", "Connection Timeout", "Unable to Connect",
        "Check your connection", "ERR_NETWORK", "ERR_INTERNET_DISCONNECTED",
        "ERR_CONNECTION", "ENOTFOUND", "ECONNREFUSED", "ETIMEDOUT",
    ]

    // MARK: - Timing Constants

    static let interventionActionDelay: TimeInterval = 2.0 // Seconds to wait before intervention action
    static let sidebarCheckInterval: TimeInterval = 5.0 // How often to check for sidebar activity if no other activity
    static let positiveActivityResetThreshold: TimeInterval =
        60.0 // If positive activity detected, reset intervention counters after this time
    static let automatedInterventionCooldown: TimeInterval =
        30.0 // Minimum time between automated interventions for same instance
    static let postInterventionObservationWindow: TimeInterval = 3.0 // Seconds to observe after intervention
    static let stuckDetectionTimeout: TimeInterval = 60.0 // Seconds before considering process stuck

    // MARK: - Limits

    static let maxAutomaticInterventions = 5 // Per positive activity period
    static let maxTotalAutomaticInterventions = 20 // Per app session (CodeLooper session)
    static let maxConsecutiveRecoveryFailures = 3 // Before escalating or stopping automated attempts

    // MARK: - Display Texts

    static let interventionTypeTexts: [CursorInterventionEngine.InterventionType: String] = [
        .unknown: "Unknown state detected",
        .noInterventionNeeded: "No intervention needed",
        .positiveWorkingState: "Cursor is actively working",
        .sidebarActivityDetected: "Sidebar activity detected",
        .connectionIssue: "Connection issue detected",
        .generalError: "General error detected",
        .unrecoverableError: "Unrecoverable error state",
        .manualPause: "Manually paused by user",
        .automatedRecovery: "Automated recovery in progress",
        .interventionLimitReached: "Intervention limit reached",
        .awaitingAction: "Awaiting user action",
        .monitoringPaused: "Monitoring is paused",
        .processNotRunning: "Process is not running",
    ]
}
