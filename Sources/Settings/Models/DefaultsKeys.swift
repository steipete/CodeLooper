@preconcurrency import Defaults
import Foundation

extension Defaults.Keys {
    // --- Monitoring Loop Settings (Spec 3.3.A & CursorMonitor) ---
    static let monitoringIntervalSeconds = Key<TimeInterval>("monitoringIntervalSeconds", default: 1.0)
    static let maxInterventionsBeforePause = Key<Int>(
        "maxInterventionsBeforePause",
        default: 5
    ) // "Max Auto-Interventions Per Instance"

    // --- Intervention Specific Limits (Spec 3.3.E & CursorMonitor) ---
    static let maxConnectionIssueRetries = Key<Int>(
        "maxConnectionIssueRetries",
        default: 3
    ) // "Max 'Resume' clicks before typing text"
    static let maxConsecutiveRecoveryFailures = Key<Int>(
        "maxConsecutiveRecoveryFailures",
        default: 3
    ) // "Max recovery cycles before 'Persistent Error'"
    
    // --- General Behavior & Notifications (Spec 3.3.A / 3.3.E) ---
    static let playSoundOnIntervention = Key<Bool>("playSoundOnIntervention", default: true)
    static let successfulInterventionSoundName = Key<String>("successfulInterventionSoundName", default: "Funk")
    static let sendNotificationOnPersistentError = Key<Bool>("sendNotificationOnPersistentError", default: true)
    
    // --- Text for "Cursor Stops" recovery (Spec 3.3.A) ---
    static let textForCursorStopsRecovery = Key<String>(
        "textForCursorStopsRecovery",
        default: "Can you please re-evaluate the current context and continue?"
    )

    // --- Global Monitoring & UI Toggles ---
    static let isGlobalMonitoringEnabled = Key<Bool>(
        "isGlobalMonitoringEnabled",
        default: true
    ) // Spec 3.1 / 3.2 Header
    static let showInMenuBar = Key<Bool>(
        "showInMenuBar",
        default: true
    ) // Used in AppDelegate for menu bar icon visibility

    // --- Cursor Supervision Tab (Spec 3.3.B) ---
    static let monitorSidebarActivity = Key<Bool>("monitorSidebarActivity", default: true) // Default ON as per Spec
    static let enableConnectionIssuesRecovery = Key<Bool>("enableConnectionIssuesRecovery", default: true)
    static let enableCursorForceStoppedRecovery = Key<Bool>("enableCursorForceStoppedRecovery", default: true)
    static let enableCursorStopsRecovery = Key<Bool>("enableCursorStopsRecovery", default: true)

    // --- Advanced Tab - Supervision Tuning (Spec 3.3.E) ---
    static let postInterventionObservationWindowSeconds = Key<TimeInterval>(
        "postInterventionObservationWindowSeconds",
        default: 3.0
    )
    static let stuckDetectionTimeoutSeconds = Key<TimeInterval>("stuckDetectionTimeoutSeconds", default: 60.0) 

    // --- Onboarding ---
    static let hasShownWelcomeGuide = Key<Bool>("hasShownWelcomeGuide", default: false)
    static let isFirstLaunch = Key<Bool>("isFirstLaunch", default: true)
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)
    static let showWelcomeScreen = Key<Bool>("showWelcomeScreen", default: true)

    // --- General Settings (from MenuManager usage in AppDelegate & Spec 3.3.A) ---
    static let startAtLogin = Key<Bool>("startAtLogin", default: true) // "Launch CodeLooper at Login"
    static let showDebugMenu = Key<Bool>("showDebugMenu", default: false) // For debug menu in status bar
    static let debugModeEnabled = Key<Bool>("debugModeEnabled", default: false)
    static let showCopyCounter = Key<Bool>("showCopyCounter", default: false)
    static let showPasteCounter = Key<Bool>("showPasteCounter", default: false)
    static let showTotalInterventions = Key<Bool>("showTotalInterventions", default: true)
    static let flashIconOnIntervention = Key<Bool>("flashIconOnIntervention", default: true)

    // --- Updates (Sparkle - Spec 3.3.A) ---
    static let automaticallyCheckForUpdates = Key<Bool>("automaticallyCheckForUpdates", default: true)

    // --- Custom Locators (JSON Strings - Spec 3.3.E) ---
    static let locatorJSONGeneratingIndicatorText = Key<String>(
        "locatorJSON_generatingIndicatorText",
        default: ""
    ) // Empty string means use app default
    static let locatorJSONSidebarActivityArea = Key<String>(
        "locatorJSON_sidebarActivityArea",
        default: ""
    )
    static let locatorJSONErrorMessagePopup = Key<String>(
        "locatorJSON_errorMessagePopup",
        default: ""
    )
    static let locatorJSONStopGeneratingButton = Key<String>(
        "locatorJSON_stopGeneratingButton",
        default: ""
    )
    static let locatorJSONConnectionErrorIndicator = Key<String>(
        "locatorJSON_connectionErrorIndicator",
        default: ""
    )
    static let locatorJSONResumeConnectionButton = Key<String>(
        "locatorJSON_resumeConnectionButton",
        default: ""
    )
    static let locatorJSONForceStopResumeLink = Key<String>(
        "locatorJSON_forceStopResumeLink",
        default: ""
    )
    static let locatorJSONMainInputField = Key<String>(
        "locatorJSON_mainInputField",
        default: ""
    )

    // --- Logging Configuration (Spec 3.3.A / LogSettingsView) ---
    static let selectedLogLevel = Key<LogLevel>("selectedLogLevel", default: .info)
    static let verboseLogging = Key<Bool>("verboseLogging", default: false)

    // --- AXorcist Locators (Advanced Settings - Spec 3.3.A / AdvancedSettingsView) ---
    static let sidebarActivityMaxDepth = Key<Int>("sidebarActivityMaxDepth", default: 1)

    // --- Path for the MCP configuration file ---
    static let mcpConfigFilePath = Key<String>("mcpConfigFilePath", default: "~/.cursor/mcp_config.json")
}
