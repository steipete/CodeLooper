@testable import CodeLooper
import Combine
import Defaults
import Foundation
import Testing

@MainActor
@Suite("SettingsService Tests")
struct SettingsServiceTests {
    // MARK: Lifecycle

    init() {
        // Reset all relevant defaults to their defined default values before each test

        // Basic monitoring and intervention settings
        Defaults.reset(.monitoringIntervalSeconds)
        Defaults.reset(.maxInterventionsBeforePause)
        Defaults.reset(.playSoundOnIntervention)
        Defaults.reset(.successfulInterventionSoundName)
        Defaults.reset(.sendNotificationOnMaxInterventions)
        Defaults.reset(.isGlobalMonitoringEnabled)
        Defaults.reset(.showInMenuBar)
        Defaults.reset(.notificationSoundName)
        Defaults.reset(.textForCursorStopsRecovery)

        // Recovery feature toggles
        Defaults.reset(.enableConnectionIssuesRecovery)
        Defaults.reset(.enableCursorForceStoppedRecovery)
        Defaults.reset(.enableCursorStopsRecovery)

        // Onboarding state
        Defaults.reset(.hasShownWelcomeGuide)
        Defaults.reset(.isFirstLaunch)
        Defaults.reset(.hasCompletedOnboarding)
        Defaults.reset(.showWelcomeScreen)

        // App behavior settings
        Defaults.reset(.startAtLogin)
        Defaults.reset(.showInDock)
        Defaults.reset(.showDebugMenu)
        Defaults.reset(.debugModeEnabled)
        Defaults.reset(.automaticallyCheckForUpdates)

        // Counter display settings
        Defaults.reset(.showCopyCounter)
        Defaults.reset(.showPasteCounter)
        Defaults.reset(.showTotalInterventions)
        Defaults.reset(.flashIconOnIntervention)

        // Logging configuration
        Defaults.reset(.selectedLogLevel)
        Defaults.reset(.verboseLogging)
        Defaults.reset(.enableDetailedLogging)

        // MCP configuration
        Defaults.reset(.mcpConfigFilePath)
        Defaults.reset(.autoReloadMCPsOnChanges)

        // Locator JSON defaults
        Defaults.reset(.locatorJSONGeneratingIndicatorText)
        Defaults.reset(.locatorJSONSidebarActivityArea)
        Defaults.reset(.locatorJSONErrorMessagePopup)
        Defaults.reset(.locatorJSONStopGeneratingButton)
        Defaults.reset(.locatorJSONConnectionErrorIndicator)
        Defaults.reset(.locatorJSONResumeConnectionButton)
        Defaults.reset(.locatorJSONForceStopResumeLink)
        Defaults.reset(.locatorJSONMainInputField)

        // Advanced settings
        Defaults.reset(.sidebarActivityMaxDepth)
        Defaults.reset(.ollamaBaseURL)
        Defaults.reset(.aiGlobalAnalysisIntervalSeconds)
        Defaults.reset(.gitClientApp)

        // Rule settings
        Defaults.reset(.showRuleExecutionCounters)
        Defaults.reset(.enableRuleNotifications)
        Defaults.reset(.enableRuleSounds)

        // Rule-specific sounds
        Defaults.reset(.stopAfter25LoopsRuleSound)
        Defaults.reset(.plainStopRuleSound)
        Defaults.reset(.connectionIssuesRuleSound)
        Defaults.reset(.editedInAnotherChatRuleSound)

        // Rule-specific notifications
        Defaults.reset(.stopAfter25LoopsRuleNotification)
        Defaults.reset(.plainStopRuleNotification)
        Defaults.reset(.connectionIssuesRuleNotification)
        Defaults.reset(.editedInAnotherChatRuleNotification)

        // Debug settings
        Defaults.reset(.debugMode)
        Defaults.reset(.useDynamicMenuBarIcon)
        Defaults.reset(.automaticJSHookInjection)
    }

    // MARK: Internal

    @Test("Open settings subject is available")
    func openSettingsSubjectAvailability() async throws {
        // Verify the subject is available and can be used
        let subject = SettingsService.openSettingsSubject
        #expect(subject != nil)
    }

    @Test("Open settings subject emits events correctly")
    func openSettingsSubjectEmission() async throws {
        let subject = SettingsService.openSettingsSubject
        var receivedEvents = 0

        let cancellable = subject.sink { _ in
            receivedEvents += 1
        }

        // Send some events
        subject.send()
        subject.send()

        // Small delay to let the publisher process
        try await Task.sleep(for: .milliseconds(10)) // 10ms

        #expect(receivedEvents == 2)
        cancellable.cancel()
    }

    @Test("Basic settings have proper default values")
    func defaultsKeysBasicDefinitions() async throws {
        // Test that all basic keys have proper defaults
        #expect(Defaults[.monitoringIntervalSeconds] == 1.0)
        #expect(Defaults[.maxInterventionsBeforePause] == 5)
        #expect(Defaults[.playSoundOnIntervention] == true)
        #expect(Defaults[.successfulInterventionSoundName] == "Funk")
        #expect(Defaults[.sendNotificationOnMaxInterventions] == true)
        #expect(Defaults[.isGlobalMonitoringEnabled] == true)
        #expect(Defaults[.showInMenuBar] == true)
    }

    @Test("Text recovery settings have correct default values")
    func defaultsKeysTextRecoverySettings() async throws {
        let expectedText = "Can you please re-evaluate the current context and continue?"
        #expect(Defaults[.textForCursorStopsRecovery] == expectedText)
    }

    @Test("Recovery feature toggles have correct default values")
    func defaultsKeysRecoveryFeatureToggles() async throws {
        #expect(Defaults[.enableConnectionIssuesRecovery] == true)
        #expect(Defaults[.enableCursorForceStoppedRecovery] == true)
        #expect(Defaults[.enableCursorStopsRecovery] == true)
    }

    @Test("Onboarding state settings have correct default values")
    func defaultsKeysOnboardingState() async throws {
        #expect(Defaults[.hasShownWelcomeGuide] == false)
        #expect(Defaults[.isFirstLaunch] == true)
        #expect(Defaults[.hasCompletedOnboarding] == false)
        #expect(Defaults[.showWelcomeScreen] == true)
    }

    @Test("App behavior settings have correct default values")
    func defaultsKeysAppBehaviorSettings() async throws {
        #expect(Defaults[.startAtLogin] == true)
        #expect(Defaults[.showInDock] == false)
        #expect(Defaults[.showDebugMenu] == false)
        #expect(Defaults[.debugModeEnabled] == false)
        #expect(Defaults[.automaticallyCheckForUpdates] == true)
    }

    @Test("Counter display settings have correct default values")
    func defaultsKeysCounterDisplaySettings() async throws {
        #expect(Defaults[.showCopyCounter] == false)
        #expect(Defaults[.showPasteCounter] == false)
        #expect(Defaults[.showTotalInterventions] == true)
        #expect(Defaults[.flashIconOnIntervention] == true)
    }

    @Test("Logging configuration settings have correct default values")
    func defaultsKeysLoggingConfiguration() async throws {
        #expect(Defaults[.selectedLogLevel] == "info")
        #expect(Defaults[.verboseLogging] == false)
        #expect(Defaults[.enableDetailedLogging] == false)
    }

    @Test("MCP configuration settings have correct default values")
    func defaultsKeysMCPConfiguration() async throws {
        #expect(Defaults[.mcpConfigFilePath] == "~/.cursor/mcp_config.json")
        #expect(Defaults[.autoReloadMCPsOnChanges] == true)
    }

    @Test("Locator JSON settings have correct default values")
    func defaultsKeysLocatorJSONDefaults() async throws {
        // All locator JSON keys should default to empty strings
        #expect(Defaults[.locatorJSONGeneratingIndicatorText] == "")
        #expect(Defaults[.locatorJSONSidebarActivityArea] == "")
        #expect(Defaults[.locatorJSONErrorMessagePopup] == "")
        #expect(Defaults[.locatorJSONStopGeneratingButton] == "")
        #expect(Defaults[.locatorJSONConnectionErrorIndicator] == "")
        #expect(Defaults[.locatorJSONResumeConnectionButton] == "")
        #expect(Defaults[.locatorJSONForceStopResumeLink] == "")
        #expect(Defaults[.locatorJSONMainInputField] == "")
    }

    @Test("Advanced settings have correct default values")
    func defaultsKeysAdvancedSettings() async throws {
        #expect(Defaults[.sidebarActivityMaxDepth] == 1)
        #expect(Defaults[.ollamaBaseURL] == "http://localhost:11434")
        #expect(Defaults[.aiGlobalAnalysisIntervalSeconds] == 10)
        #expect(Defaults[.gitClientApp] == "/Applications/Tower.app")
    }

    @Test("Rule settings have correct default values")
    func defaultsKeysRuleSettings() async throws {
        #expect(Defaults[.showRuleExecutionCounters] == true)
        #expect(Defaults[.enableRuleNotifications] == true)
        #expect(Defaults[.enableRuleSounds] == true)
    }

    @Test("Rule-specific sound settings have correct default values")
    func defaultsKeysRuleSpecificSounds() async throws {
        #expect(Defaults[.stopAfter25LoopsRuleSound] == "Glass")
        #expect(Defaults[.plainStopRuleSound] == "")
        #expect(Defaults[.connectionIssuesRuleSound] == "")
        #expect(Defaults[.editedInAnotherChatRuleSound] == "")
    }

    @Test("Rule-specific notification settings have correct default values")
    func defaultsKeysRuleSpecificNotifications() async throws {
        #expect(Defaults[.stopAfter25LoopsRuleNotification] == true)
        #expect(Defaults[.plainStopRuleNotification] == false)
        #expect(Defaults[.connectionIssuesRuleNotification] == false)
        #expect(Defaults[.editedInAnotherChatRuleNotification] == false)
    }

    @Test("Debug settings have correct default values")
    func defaultsKeysDebugSettings() async throws {
        #expect(Defaults[.useDynamicMenuBarIcon] == false)
        #expect(Defaults[.automaticJSHookInjection] == false)

        // Debug mode default depends on build configuration
        #if DEBUG
            #expect(Defaults[.debugMode] == true)
        #else
            #expect(Defaults[.debugMode] == false)
        #endif
    }

    @Test("Settings can be changed and retrieved correctly")
    func defaultsKeysSettingsPersistence() async throws {
        // Test that settings can be changed and retrieved
        let originalValue = Defaults[.monitoringIntervalSeconds]
        let testValue: TimeInterval = 2.5

        // Change the value
        Defaults[.monitoringIntervalSeconds] = testValue

        // Verify it was changed
        #expect(Defaults[.monitoringIntervalSeconds] == testValue)

        // Restore original value
        Defaults[.monitoringIntervalSeconds] = originalValue
        #expect(Defaults[.monitoringIntervalSeconds] == originalValue)
    }

    @Test("Boolean settings can be toggled correctly")
    func defaultsKeysBooleanSettingsToggle() async throws {
        let originalValue = Defaults[.playSoundOnIntervention]

        // Toggle the value
        Defaults[.playSoundOnIntervention] = !originalValue
        #expect(Defaults[.playSoundOnIntervention] == !originalValue)

        // Toggle back
        Defaults[.playSoundOnIntervention] = originalValue
        #expect(Defaults[.playSoundOnIntervention] == originalValue)
    }

    @Test("String settings can be modified correctly")
    func defaultsKeysStringSettingsModification() async throws {
        let originalValue = Defaults[.textForCursorStopsRecovery]
        let testValue = "Custom test recovery text"

        // Change the value
        Defaults[.textForCursorStopsRecovery] = testValue
        #expect(Defaults[.textForCursorStopsRecovery] == testValue)

        // Restore original value
        Defaults[.textForCursorStopsRecovery] = originalValue
        #expect(Defaults[.textForCursorStopsRecovery] == originalValue)
    }

    @Test("Integer settings can be changed within valid range")
    func defaultsKeysIntegerSettingsRange() async throws {
        let originalValue = Defaults[.maxInterventionsBeforePause]

        // Test different valid values
        Defaults[.maxInterventionsBeforePause] = 10
        #expect(Defaults[.maxInterventionsBeforePause] == 10)

        Defaults[.maxInterventionsBeforePause] = 1
        #expect(Defaults[.maxInterventionsBeforePause] == 1)

        // Restore original value
        Defaults[.maxInterventionsBeforePause] = originalValue
        #expect(Defaults[.maxInterventionsBeforePause] == originalValue)
    }

    @Test("Notification sound settings work correctly with optional values")
    func defaultsKeysNotificationSoundOptional() async throws {
        // Test that optional notification sound defaults work
        #expect(Defaults[.notificationSoundName] == "Default")

        // Test setting to a different value and back
        Defaults[.notificationSoundName] = "CustomSound"
        #expect(Defaults[.notificationSoundName] == "CustomSound")

        // Restore default
        Defaults[.notificationSoundName] = "Default"
        #expect(Defaults[.notificationSoundName] == "Default")
    }
}
