import Defaults
import Foundation

extension Defaults.Keys {
    // --- Monitoring Loop Settings (Spec 3.3.A & CursorMonitor) ---
    static let monitoringIntervalSeconds = Key<TimeInterval>("monitoringIntervalSeconds", default: 1.0)
    static let maxInterventionsBeforePause = Key<Int>("maxInterventionsBeforePause", default: 5) // "Max Auto-Interventions Per Instance"

    // --- Intervention Specific Limits (Spec 3.3.E & CursorMonitor) ---
    static let maxConnectionIssueRetries = Key<Int>("maxConnectionIssueRetries", default: 3) // "Max 'Resume' clicks before typing text"
    static let maxConsecutiveRecoveryFailures = Key<Int>("maxConsecutiveRecoveryFailures", default: 3) // "Max recovery cycles before 'Persistent Error'"
    
    // --- General Behavior & Notifications (Spec 3.3.A / 3.3.E) ---
    static let playSoundOnIntervention = Key<Bool>("playSoundOnIntervention", default: true)
    static let sendNotificationOnPersistentError = Key<Bool>("sendNotificationOnPersistentError", default: true)
    
    // --- Text for "Cursor Stops" recovery (Spec 3.3.A) ---
    static let textForCursorStopsRecovery = Key<String>("textForCursorStopsRecovery", default: "Can you please re-evaluate the current context and continue?")

    // --- Global Monitoring & UI Toggles ---
    static let isGlobalMonitoringEnabled = Key<Bool>("isGlobalMonitoringEnabled", default: true) // Spec 3.1 / 3.2 Header
    static let showInMenuBar = Key<Bool>("showInMenuBar", default: true) // Used in AppDelegate for menu bar icon visibility

    // --- Cursor Supervision Tab (Spec 3.3.B) ---
    static let monitorSidebarActivity = Key<Bool>("monitorSidebarActivity", default: true) // Default ON as per Spec
    static let enableConnectionIssuesRecovery = Key<Bool>("enableConnectionIssuesRecovery", default: true)
    static let enableCursorForceStoppedRecovery = Key<Bool>("enableCursorForceStoppedRecovery", default: true)
    static let enableCursorStopsRecovery = Key<Bool>("enableCursorStopsRecovery", default: true)

    // --- Advanced Tab - Supervision Tuning (Spec 3.3.E) ---
    static let postInterventionObservationWindowSeconds = Key<TimeInterval>("postInterventionObservationWindowSeconds", default: 3.0)
    static let stuckDetectionTimeoutSeconds = Key<TimeInterval>("stuckDetectionTimeoutSeconds", default: 60.0) 

    // --- Onboarding ---
    static let hasShownWelcomeGuide = Key<Bool>("hasShownWelcomeGuide", default: false)

    // --- General Settings (from MenuManager usage in AppDelegate & Spec 3.3.A) ---
    static let startAtLogin = Key<Bool>("startAtLogin", default: true) // "Launch CodeLooper at Login"
    static let showDebugMenu = Key<Bool>("showDebugMenu", default: false) // For debug menu in status bar

    // --- Updates (Sparkle - Spec 3.3.A) ---
    static let automaticallyCheckForUpdates = Key<Bool>("automaticallyCheckForUpdates", default: true)

    // --- Custom Locators (JSON Strings - Spec 3.3.E) ---
    static let locatorJSON_generatingIndicatorText = Key<String>("locatorJSON_generatingIndicatorText", default: "") // Empty string means use app default
    static let locatorJSON_sidebarActivityArea = Key<String>("locatorJSON_sidebarActivityArea", default: "")
    static let locatorJSON_errorMessagePopup = Key<String>("locatorJSON_errorMessagePopup", default: "")
    static let locatorJSON_stopGeneratingButton = Key<String>("locatorJSON_stopGeneratingButton", default: "")
    static let locatorJSON_connectionErrorIndicator = Key<String>("locatorJSON_connectionErrorIndicator", default: "")
    static let locatorJSON_resumeConnectionButton = Key<String>("locatorJSON_resumeConnectionButton", default: "")
    static let locatorJSON_forceStopResumeLink = Key<String>("locatorJSON_forceStopResumeLink", default: "")
    static let locatorJSON_mainInputField = Key<String>("locatorJSON_mainInputField", default: "")
}