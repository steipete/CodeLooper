import Testing
import Foundation
import Defaults
import Combine
@testable import CodeLooper

@MainActor
@Test("SettingsService - OpenSettings Subject Availability")
func testOpenSettingsSubjectAvailability() async throws {
    // Verify the subject is available and can be used
    let subject = SettingsService.openSettingsSubject
    #expect(subject != nil)
}

@MainActor
@Test("SettingsService - OpenSettings Subject Emission")
func testOpenSettingsSubjectEmission() async throws {
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

@Test("DefaultsKeys - Basic Key Definitions")
func testDefaultsKeysBasicDefinitions() async throws {
    // Test that all basic keys have proper defaults
    #expect(Defaults[.monitoringIntervalSeconds] == 1.0)
    #expect(Defaults[.maxInterventionsBeforePause] == 5)
    #expect(Defaults[.playSoundOnIntervention] == true)
    #expect(Defaults[.successfulInterventionSoundName] == "Funk")
    #expect(Defaults[.sendNotificationOnMaxInterventions] == true)
    #expect(Defaults[.isGlobalMonitoringEnabled] == true)
    #expect(Defaults[.showInMenuBar] == true)
}

@Test("DefaultsKeys - Text Recovery Settings")
func testDefaultsKeysTextRecoverySettings() async throws {
    let expectedText = "Can you please re-evaluate the current context and continue?"
    #expect(Defaults[.textForCursorStopsRecovery] == expectedText)
}

@Test("DefaultsKeys - Recovery Feature Toggles")
func testDefaultsKeysRecoveryFeatureToggles() async throws {
    #expect(Defaults[.enableConnectionIssuesRecovery] == true)
    #expect(Defaults[.enableCursorForceStoppedRecovery] == true)
    #expect(Defaults[.enableCursorStopsRecovery] == true)
}

@Test("DefaultsKeys - Onboarding State")
func testDefaultsKeysOnboardingState() async throws {
    #expect(Defaults[.hasShownWelcomeGuide] == false)
    #expect(Defaults[.isFirstLaunch] == true)
    #expect(Defaults[.hasCompletedOnboarding] == false)
    #expect(Defaults[.showWelcomeScreen] == true)
}

@Test("DefaultsKeys - App Behavior Settings")
func testDefaultsKeysAppBehaviorSettings() async throws {
    #expect(Defaults[.startAtLogin] == true)
    #expect(Defaults[.showInDock] == false)
    #expect(Defaults[.showDebugMenu] == false)
    #expect(Defaults[.debugModeEnabled] == false)
    #expect(Defaults[.automaticallyCheckForUpdates] == true)
}

@Test("DefaultsKeys - Counter Display Settings")
func testDefaultsKeysCounterDisplaySettings() async throws {
    #expect(Defaults[.showCopyCounter] == false)
    #expect(Defaults[.showPasteCounter] == false)
    #expect(Defaults[.showTotalInterventions] == true)
    #expect(Defaults[.flashIconOnIntervention] == true)
}

@Test("DefaultsKeys - Logging Configuration")
func testDefaultsKeysLoggingConfiguration() async throws {
    #expect(Defaults[.selectedLogLevel] == "info")
    #expect(Defaults[.verboseLogging] == false)
    #expect(Defaults[.enableDetailedLogging] == false)
}

@Test("DefaultsKeys - MCP Configuration")
func testDefaultsKeysMCPConfiguration() async throws {
    #expect(Defaults[.mcpConfigFilePath] == "~/.cursor/mcp_config.json")
    #expect(Defaults[.autoReloadMCPsOnChanges] == true)
}

@Test("DefaultsKeys - Locator JSON Defaults")
func testDefaultsKeysLocatorJSONDefaults() async throws {
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

@Test("DefaultsKeys - Advanced Settings")
func testDefaultsKeysAdvancedSettings() async throws {
    #expect(Defaults[.sidebarActivityMaxDepth] == 1)
    #expect(Defaults[.ollamaBaseURL] == "http://localhost:11434")
    #expect(Defaults[.aiGlobalAnalysisIntervalSeconds] == 10)
    #expect(Defaults[.gitClientApp] == "/Applications/Tower.app")
}

@Test("DefaultsKeys - Rule Settings")
func testDefaultsKeysRuleSettings() async throws {
    #expect(Defaults[.showRuleExecutionCounters] == true)
    #expect(Defaults[.enableRuleNotifications] == true)
    #expect(Defaults[.enableRuleSounds] == true)
}

@Test("DefaultsKeys - Rule-Specific Sounds")
func testDefaultsKeysRuleSpecificSounds() async throws {
    #expect(Defaults[.stopAfter25LoopsRuleSound] == "Glass")
    #expect(Defaults[.plainStopRuleSound] == "")
    #expect(Defaults[.connectionIssuesRuleSound] == "")
    #expect(Defaults[.editedInAnotherChatRuleSound] == "")
}

@Test("DefaultsKeys - Rule-Specific Notifications")
func testDefaultsKeysRuleSpecificNotifications() async throws {
    #expect(Defaults[.stopAfter25LoopsRuleNotification] == true)
    #expect(Defaults[.plainStopRuleNotification] == false)
    #expect(Defaults[.connectionIssuesRuleNotification] == false)
    #expect(Defaults[.editedInAnotherChatRuleNotification] == false)
}

@Test("DefaultsKeys - Debug Settings")
func testDefaultsKeysDebugSettings() async throws {
    #expect(Defaults[.useDynamicMenuBarIcon] == false)
    #expect(Defaults[.automaticJSHookInjection] == false)
    
    // Debug mode default depends on build configuration
    #if DEBUG
    #expect(Defaults[.debugMode] == true)
    #else
    #expect(Defaults[.debugMode] == false)
    #endif
}

@Test("DefaultsKeys - Settings Persistence")
func testDefaultsKeysSettingsPersistence() async throws {
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

@Test("DefaultsKeys - Boolean Settings Toggle")
func testDefaultsKeysBooleanSettingsToggle() async throws {
    let originalValue = Defaults[.playSoundOnIntervention]
    
    // Toggle the value
    Defaults[.playSoundOnIntervention] = !originalValue
    #expect(Defaults[.playSoundOnIntervention] == !originalValue)
    
    // Toggle back
    Defaults[.playSoundOnIntervention] = originalValue
    #expect(Defaults[.playSoundOnIntervention] == originalValue)
}

@Test("DefaultsKeys - String Settings Modification")
func testDefaultsKeysStringSettingsModification() async throws {
    let originalValue = Defaults[.textForCursorStopsRecovery]
    let testValue = "Custom test recovery text"
    
    // Change the value
    Defaults[.textForCursorStopsRecovery] = testValue
    #expect(Defaults[.textForCursorStopsRecovery] == testValue)
    
    // Restore original value
    Defaults[.textForCursorStopsRecovery] = originalValue
    #expect(Defaults[.textForCursorStopsRecovery] == originalValue)
}

@Test("DefaultsKeys - Integer Settings Range")
func testDefaultsKeysIntegerSettingsRange() async throws {
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

@Test("DefaultsKeys - Notification Sound Optional")
func testDefaultsKeysNotificationSoundOptional() async throws {
    // Test that optional notification sound defaults work
    #expect(Defaults[.notificationSoundName] == "Default")
    
    // Test setting to nil
    Defaults[.notificationSoundName] = nil
    #expect(Defaults[.notificationSoundName] == nil)
    
    // Restore default
    Defaults[.notificationSoundName] = "Default"
    #expect(Defaults[.notificationSoundName] == "Default")
}