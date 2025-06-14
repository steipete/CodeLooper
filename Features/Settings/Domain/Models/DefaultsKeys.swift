@preconcurrency import Defaults

// import Diagnostics // Removed as DefaultsKeys should not be part of Diagnostics module
import Foundation

/// Extension defining all user preference keys for the CodeLooper application.
///
/// This extension provides type-safe access to:
/// - Monitoring interval and automation settings
/// - Intervention limits and behavior configuration
/// - UI preferences and appearance options
/// - API configuration for AI analysis
/// - Feature toggles and experimental options
/// - Debug and logging preferences
///
/// All keys include sensible defaults to ensure the app functions
/// properly on first launch without configuration.
extension Defaults.Keys {
    // --- Monitoring Loop Settings (Spec 3.3.A & CursorMonitor) ---
    static let monitoringIntervalSeconds = Key<TimeInterval>("monitoringIntervalSeconds", default: 1.0)
    static let maxInterventionsBeforePause = Key<Int>(
        "maxInterventionsBeforePause",
        default: 5
    ) // "Max Auto-Interventions Per Instance"

    // --- General Behavior & Notifications (Spec 3.3.A / 3.3.E) ---
    static let playSoundOnIntervention = Key<Bool>("playSoundOnIntervention", default: true)
    static let successfulInterventionSoundName = Key<String>("successfulInterventionSoundName", default: "Funk")
    static let sendNotificationOnMaxInterventions = Key<Bool>("sendNotificationOnMaxInterventions", default: true)
    static let notificationSoundName = Key<String?>("notificationSoundName",
                                                    default: "Default")

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
    static let enableConnectionIssuesRecovery = Key<Bool>("enableConnectionIssuesRecovery", default: true)
    static let enableCursorForceStoppedRecovery = Key<Bool>("enableCursorForceStoppedRecovery", default: true)
    static let enableCursorStopsRecovery = Key<Bool>("enableCursorStopsRecovery", default: true)

    // --- Onboarding ---
    static let hasShownWelcomeGuide = Key<Bool>("hasShownWelcomeGuide", default: false)
    static let isFirstLaunch = Key<Bool>("isFirstLaunch", default: true)
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)
    static let showWelcomeScreen = Key<Bool>("showWelcomeScreen", default: true)

    // --- General Settings (from MenuManager usage in AppDelegate & Spec 3.3.A) ---
    static let startAtLogin = Key<Bool>("startAtLogin", default: true) // "Launch CodeLooper at Login"
    static let showInDock = Key<Bool>("showInDock", default: false) // "Show CodeLooper in Dock"
    static let showDebugMenu = Key<Bool>("showDebugMenu", default: false) // For debug menu in status bar
    static let debugModeEnabled = Key<Bool>("debugModeEnabled", default: false)
    static let showDebugTab = Key<Bool>("showDebugTab", default: false) // For debug tab in settings
    static let showCopyCounter = Key<Bool>("showCopyCounter", default: false)
    static let showPasteCounter = Key<Bool>("showPasteCounter", default: false)
    static let showTotalInterventions = Key<Bool>("showTotalInterventions", default: true)
    static let flashIconOnIntervention = Key<Bool>("flashIconOnIntervention", default: true)

    // --- Updates (Sparkle - Spec 3.3.A) ---
    static let automaticallyCheckForUpdates = Key<Bool>("automaticallyCheckForUpdates", default: true)
    static let receivePreReleaseUpdates = Key<Bool>("receivePreReleaseUpdates", default: true)

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
    static let selectedLogLevel = Key<String>("selectedLogLevel", default: "info")
    static let verboseLogging = Key<Bool>("verboseLogging", default: false)
    static let enableDetailedLogging = Key<Bool>("enableDetailedLogging", default: false)

    // --- AXorcist Locators (Advanced Settings - Spec 3.3.A / AdvancedSettingsView) ---
    static let sidebarActivityMaxDepth = Key<Int>("sidebarActivityMaxDepth", default: 1)

    // --- Path for the MCP configuration file ---
    static let mcpConfigFilePath = Key<String>("mcpConfigFilePath", default: "~/.cursor/mcp_config.json")

    // --- MCP Auto-reload setting ---
    static let autoReloadMCPsOnChanges = Key<Bool>("autoReloadMCPsOnChanges", default: true)

    // --- AI Settings ---
    static let aiProvider = Key<AIProvider>("aiProvider", default: .openAI)
    static let aiModel = Key<AIModel>("aiModel", default: .gpt4o)
    static let ollamaBaseURL = Key<String>("ollamaBaseURL", default: "http://localhost:11434")
    static let aiGlobalAnalysisIntervalSeconds = Key<Int>("aiGlobalAnalysisIntervalSeconds", default: 10)

    // --- Git Client Settings ---
    static let gitClientApp = Key<String>("gitClientApp", default: "/Applications/Tower.app")

    // --- Rule Settings ---
    static let showRuleExecutionCounters = Key<Bool>("showRuleExecutionCounters", default: true)
    static let enableRuleNotifications = Key<Bool>("enableRuleNotifications", default: true)
    static let enableRuleSounds = Key<Bool>("enableRuleSounds", default: true)

    // Rule-specific sound settings
    static let stopAfter25LoopsRuleSound = Key<String>("stopAfter25LoopsRuleSound", default: "Glass")
    static let plainStopRuleSound = Key<String>("plainStopRuleSound", default: "")
    static let connectionIssuesRuleSound = Key<String>("connectionIssuesRuleSound", default: "")
    static let editedInAnotherChatRuleSound = Key<String>("editedInAnotherChatRuleSound", default: "")

    // Rule-specific notification settings
    static let stopAfter25LoopsRuleNotification = Key<Bool>("stopAfter25LoopsRuleNotification", default: true)
    static let plainStopRuleNotification = Key<Bool>("plainStopRuleNotification", default: false)
    static let connectionIssuesRuleNotification = Key<Bool>("connectionIssuesRuleNotification", default: false)
    static let editedInAnotherChatRuleNotification = Key<Bool>("editedInAnotherChatRuleNotification", default: false)

    // --- Debug Settings ---
    static let debugMode = Key<Bool>("debugMode", default: {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }())
    static let automaticJSHookInjection = Key<Bool>("automaticJSHookInjection", default: false)
    static let useDynamicMenuBarIcon = Key<Bool>("useDynamicMenuBarIcon", default: false)

    // --- Claude Monitoring Settings ---
    static let enableClaudeMonitoring = Key<Bool>("enableClaudeMonitoring", default: true)
    static let enableClaudeTitleOverride = Key<Bool>("enableClaudeTitleOverride", default: true)
    
    // --- HTTP Server Settings ---
    static let httpServerEnabled = Key<Bool>("httpServerEnabled", default: false)
    static let httpServerPort = Key<Int>("httpServerPort", default: 8080)
    static let ngrokAPIKey = Key<String>("ngrokAPIKey", default: "")
    static let httpServerScreenshotRefreshRate = Key<Int>("httpServerScreenshotRefreshRate", default: 1000) // milliseconds
}
