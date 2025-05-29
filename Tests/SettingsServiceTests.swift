@testable import CodeLooper
import Combine
import Defaults
import Foundation
import Testing

@MainActor

func openSettingsSubjectAvailability() async throws {
    // Verify the subject is available and can be used
    let subject = SettingsService.openSettingsSubject
    #expect(subject != nil)
}

@MainActor

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


func defaultsKeysTextRecoverySettings() async throws {
    let expectedText = "Can you please re-evaluate the current context and continue?"
    #expect(Defaults[.textForCursorStopsRecovery] == expectedText)
}


func defaultsKeysRecoveryFeatureToggles() async throws {
    #expect(Defaults[.enableConnectionIssuesRecovery] == true)
    #expect(Defaults[.enableCursorForceStoppedRecovery] == true)
    #expect(Defaults[.enableCursorStopsRecovery] == true)
}


func defaultsKeysOnboardingState() async throws {
    #expect(Defaults[.hasShownWelcomeGuide] == false)
    #expect(Defaults[.isFirstLaunch] == true)
    #expect(Defaults[.hasCompletedOnboarding] == false)
    #expect(Defaults[.showWelcomeScreen] == true)
}


func defaultsKeysAppBehaviorSettings() async throws {
    #expect(Defaults[.startAtLogin] == true)
    #expect(Defaults[.showInDock] == false)
    #expect(Defaults[.showDebugMenu] == false)
    #expect(Defaults[.debugModeEnabled] == false)
    #expect(Defaults[.automaticallyCheckForUpdates] == true)
}


func defaultsKeysCounterDisplaySettings() async throws {
    #expect(Defaults[.showCopyCounter] == false)
    #expect(Defaults[.showPasteCounter] == false)
    #expect(Defaults[.showTotalInterventions] == true)
    #expect(Defaults[.flashIconOnIntervention] == true)
}


func defaultsKeysLoggingConfiguration() async throws {
    #expect(Defaults[.selectedLogLevel] == "info")
    #expect(Defaults[.verboseLogging] == false)
    #expect(Defaults[.enableDetailedLogging] == false)
}


func defaultsKeysMCPConfiguration() async throws {
    #expect(Defaults[.mcpConfigFilePath] == "~/.cursor/mcp_config.json")
    #expect(Defaults[.autoReloadMCPsOnChanges] == true)
}


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


func defaultsKeysAdvancedSettings() async throws {
    #expect(Defaults[.sidebarActivityMaxDepth] == 1)
    #expect(Defaults[.ollamaBaseURL] == "http://localhost:11434")
    #expect(Defaults[.aiGlobalAnalysisIntervalSeconds] == 10)
    #expect(Defaults[.gitClientApp] == "/Applications/Tower.app")
}


func defaultsKeysRuleSettings() async throws {
    #expect(Defaults[.showRuleExecutionCounters] == true)
    #expect(Defaults[.enableRuleNotifications] == true)
    #expect(Defaults[.enableRuleSounds] == true)
}


func defaultsKeysRuleSpecificSounds() async throws {
    #expect(Defaults[.stopAfter25LoopsRuleSound] == "Glass")
    #expect(Defaults[.plainStopRuleSound] == "")
    #expect(Defaults[.connectionIssuesRuleSound] == "")
    #expect(Defaults[.editedInAnotherChatRuleSound] == "")
}


func defaultsKeysRuleSpecificNotifications() async throws {
    #expect(Defaults[.stopAfter25LoopsRuleNotification] == true)
    #expect(Defaults[.plainStopRuleNotification] == false)
    #expect(Defaults[.connectionIssuesRuleNotification] == false)
    #expect(Defaults[.editedInAnotherChatRuleNotification] == false)
}


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


func defaultsKeysBooleanSettingsToggle() async throws {
    let originalValue = Defaults[.playSoundOnIntervention]

    // Toggle the value
    Defaults[.playSoundOnIntervention] = !originalValue
    #expect(Defaults[.playSoundOnIntervention] == !originalValue)

    // Toggle back
    Defaults[.playSoundOnIntervention] = originalValue
    #expect(Defaults[.playSoundOnIntervention] == originalValue)
}


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


func defaultsKeysNotificationSoundOptional() async throws {
    // Test that optional notification sound defaults work
    #expect(Defaults[.notificationSoundName] == "Default")

    // Test setting to nil
    Defaults[.notificationSoundName] = nil
    #expect(Defaults[.notificationSoundName] == nil)

    // Restore default
    Defaults[.notificationSoundName] = "Default"
    #expect(Defaults[.notificationSoundName] == "Default")
}
