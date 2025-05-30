@testable import CodeLooper
import Combine
import Defaults
import Foundation
import XCTest

@MainActor
class SettingsServiceTests: XCTestCase {
    func testOpenSettingsSubjectAvailability() async throws {
        // Verify the subject is available and can be used
        let subject = SettingsService.openSettingsSubject
        XCTAssertNotNil(subject)
    }

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

        XCTAssertEqual(receivedEvents, 2)
        cancellable.cancel()
    }

    func testDefaultsKeysBasicDefinitions() async throws {
        // Test that all basic keys have proper defaults
        XCTAssertEqual(Defaults[.monitoringIntervalSeconds], 1.0)
        XCTAssertEqual(Defaults[.maxInterventionsBeforePause], 5)
        XCTAssertEqual(Defaults[.playSoundOnIntervention], true)
        XCTAssertEqual(Defaults[.successfulInterventionSoundName], "Funk")
        XCTAssertEqual(Defaults[.sendNotificationOnMaxInterventions], true)
        XCTAssertEqual(Defaults[.isGlobalMonitoringEnabled], true)
        XCTAssertEqual(Defaults[.showInMenuBar], true)
    }

    func testDefaultsKeysTextRecoverySettings() async throws {
        let expectedText = "Can you please re-evaluate the current context and continue?"
        XCTAssertEqual(Defaults[.textForCursorStopsRecovery], expectedText)
    }

    func testDefaultsKeysRecoveryFeatureToggles() async throws {
        XCTAssertEqual(Defaults[.enableConnectionIssuesRecovery], true)
        XCTAssertEqual(Defaults[.enableCursorForceStoppedRecovery], true)
        XCTAssertEqual(Defaults[.enableCursorStopsRecovery], true)
    }

    func testDefaultsKeysOnboardingState() async throws {
        XCTAssertEqual(Defaults[.hasShownWelcomeGuide], false)
        XCTAssertEqual(Defaults[.isFirstLaunch], true)
        XCTAssertEqual(Defaults[.hasCompletedOnboarding], false)
        XCTAssertEqual(Defaults[.showWelcomeScreen], true)
    }

    func testDefaultsKeysAppBehaviorSettings() async throws {
        XCTAssertEqual(Defaults[.startAtLogin], true)
        XCTAssertEqual(Defaults[.showInDock], false)
        XCTAssertEqual(Defaults[.showDebugMenu], false)
        XCTAssertEqual(Defaults[.debugModeEnabled], false)
        XCTAssertEqual(Defaults[.automaticallyCheckForUpdates], true)
    }

    func testDefaultsKeysCounterDisplaySettings() async throws {
        XCTAssertEqual(Defaults[.showCopyCounter], false)
        XCTAssertEqual(Defaults[.showPasteCounter], false)
        XCTAssertEqual(Defaults[.showTotalInterventions], true)
        XCTAssertEqual(Defaults[.flashIconOnIntervention], true)
    }

    func testDefaultsKeysLoggingConfiguration() async throws {
        XCTAssertEqual(Defaults[.selectedLogLevel], "info")
        XCTAssertEqual(Defaults[.verboseLogging], false)
        XCTAssertEqual(Defaults[.enableDetailedLogging], false)
    }

    func testDefaultsKeysMCPConfiguration() async throws {
        XCTAssertEqual(Defaults[.mcpConfigFilePath], "~/.cursor/mcp_config.json")
        XCTAssertEqual(Defaults[.autoReloadMCPsOnChanges], true)
    }

    func testDefaultsKeysLocatorJSONDefaults() async throws {
        // All locator JSON keys should default to empty strings
        XCTAssertEqual(Defaults[.locatorJSONGeneratingIndicatorText], "")
        XCTAssertEqual(Defaults[.locatorJSONSidebarActivityArea], "")
        XCTAssertEqual(Defaults[.locatorJSONErrorMessagePopup], "")
        XCTAssertEqual(Defaults[.locatorJSONStopGeneratingButton], "")
        XCTAssertEqual(Defaults[.locatorJSONConnectionErrorIndicator], "")
        XCTAssertEqual(Defaults[.locatorJSONResumeConnectionButton], "")
        XCTAssertEqual(Defaults[.locatorJSONForceStopResumeLink], "")
        XCTAssertEqual(Defaults[.locatorJSONMainInputField], "")
    }

    func testDefaultsKeysAdvancedSettings() async throws {
        XCTAssertEqual(Defaults[.sidebarActivityMaxDepth], 1)
        XCTAssertEqual(Defaults[.ollamaBaseURL], "http://localhost:11434")
        XCTAssertEqual(Defaults[.aiGlobalAnalysisIntervalSeconds], 10)
        XCTAssertEqual(Defaults[.gitClientApp], "/Applications/Tower.app")
    }

    func testDefaultsKeysRuleSettings() async throws {
        XCTAssertEqual(Defaults[.showRuleExecutionCounters], true)
        XCTAssertEqual(Defaults[.enableRuleNotifications], true)
        XCTAssertEqual(Defaults[.enableRuleSounds], true)
    }

    func testDefaultsKeysRuleSpecificSounds() async throws {
        XCTAssertEqual(Defaults[.stopAfter25LoopsRuleSound], "Glass")
        XCTAssertEqual(Defaults[.plainStopRuleSound], "")
        XCTAssertEqual(Defaults[.connectionIssuesRuleSound], "")
        XCTAssertEqual(Defaults[.editedInAnotherChatRuleSound], "")
    }

    func testDefaultsKeysRuleSpecificNotifications() async throws {
        XCTAssertEqual(Defaults[.stopAfter25LoopsRuleNotification], true)
        XCTAssertEqual(Defaults[.plainStopRuleNotification], false)
        XCTAssertEqual(Defaults[.connectionIssuesRuleNotification], false)
        XCTAssertEqual(Defaults[.editedInAnotherChatRuleNotification], false)
    }

    func testDefaultsKeysDebugSettings() async throws {
        XCTAssertEqual(Defaults[.useDynamicMenuBarIcon], false)
        XCTAssertEqual(Defaults[.automaticJSHookInjection], false)

        // Debug mode default depends on build configuration
        #if DEBUG
            XCTAssertEqual(Defaults[.debugMode], true)
        #else
            XCTAssertEqual(Defaults[.debugMode], false)
        #endif
    }

    func testDefaultsKeysSettingsPersistence() async throws {
        // Test that settings can be changed and retrieved
        let originalValue = Defaults[.monitoringIntervalSeconds]
        let testValue: TimeInterval = 2.5

        // Change the value
        Defaults[.monitoringIntervalSeconds] = testValue

        // Verify it was changed
        XCTAssertEqual(Defaults[.monitoringIntervalSeconds], testValue)

        // Restore original value
        Defaults[.monitoringIntervalSeconds] = originalValue
        XCTAssertEqual(Defaults[.monitoringIntervalSeconds], originalValue)
    }

    func testDefaultsKeysBooleanSettingsToggle() async throws {
        let originalValue = Defaults[.playSoundOnIntervention]

        // Toggle the value
        Defaults[.playSoundOnIntervention] = !originalValue
        XCTAssertEqual(Defaults[.playSoundOnIntervention], !originalValue)

        // Toggle back
        Defaults[.playSoundOnIntervention] = originalValue
        XCTAssertEqual(Defaults[.playSoundOnIntervention], originalValue)
    }

    func testDefaultsKeysStringSettingsModification() async throws {
        let originalValue = Defaults[.textForCursorStopsRecovery]
        let testValue = "Custom test recovery text"

        // Change the value
        Defaults[.textForCursorStopsRecovery] = testValue
        XCTAssertEqual(Defaults[.textForCursorStopsRecovery], testValue)

        // Restore original value
        Defaults[.textForCursorStopsRecovery] = originalValue
        XCTAssertEqual(Defaults[.textForCursorStopsRecovery], originalValue)
    }

    func testDefaultsKeysIntegerSettingsRange() async throws {
        let originalValue = Defaults[.maxInterventionsBeforePause]

        // Test different valid values
        Defaults[.maxInterventionsBeforePause] = 10
        XCTAssertEqual(Defaults[.maxInterventionsBeforePause], 10)

        Defaults[.maxInterventionsBeforePause] = 1
        XCTAssertEqual(Defaults[.maxInterventionsBeforePause], 1)

        // Restore original value
        Defaults[.maxInterventionsBeforePause] = originalValue
        XCTAssertEqual(Defaults[.maxInterventionsBeforePause], originalValue)
    }

    func testDefaultsKeysNotificationSoundOptional() async throws {
        // Test that optional notification sound defaults work
        XCTAssertEqual(Defaults[.notificationSoundName], "Default")

        // Test setting to nil
        Defaults[.notificationSoundName] = nil
        XCTAssertEqual(Defaults[.notificationSoundName], nil)

        // Restore default
        Defaults[.notificationSoundName] = "Default"
        XCTAssertEqual(Defaults[.notificationSoundName], "Default")
    }
}
