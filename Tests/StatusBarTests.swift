import AppKit
@testable import CodeLooper
import Foundation
import SwiftUI
import Testing

@Suite("StatusBarTests")
struct StatusBarTests {
    @Test("Status icon state all cases") func statusIconStateAllCases() {
        let states: [StatusIconState] = [
            .idle,
            .syncing,
            .error,
            .warning,
            .success,
            .authenticated,
            .unauthenticated,
            .criticalError,
            .paused,
            .aiStatus(working: 2, notWorking: 1, unknown: 0),
        ]

        for state in states {
            #expect(state.rawValue.count > 0)
            #expect(state.description.count > 0)
            #expect(state.tooltipText.count > 0)
        }
    }

    @Test("Status icon state raw values") func statusIconStateRawValues() {
        #expect(StatusIconState.idle.rawValue == "idle")
        #expect(StatusIconState.syncing.rawValue == "syncing")
        #expect(StatusIconState.error.rawValue == "error")
        #expect(StatusIconState.warning.rawValue == "warning")
        #expect(StatusIconState.success.rawValue == "success")
        #expect(StatusIconState.authenticated.rawValue == "authenticated")
        #expect(StatusIconState.unauthenticated.rawValue == "unauthenticated")
        #expect(StatusIconState.criticalError.rawValue == "criticalError")
        #expect(StatusIconState.paused.rawValue == "paused")
        #expect(StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3).rawValue == "aiStatus")
    }

    @Test("Status icon state descriptions") func statusIconStateDescriptions() {
        #expect(StatusIconState.idle.description == "Idle")
        #expect(StatusIconState.syncing.description == "Syncing")
        #expect(StatusIconState.error.description == "Error")
        #expect(StatusIconState.warning.description == "Warning")
        #expect(StatusIconState.success.description == "Success")
        #expect(StatusIconState.authenticated.description == "Authenticated")
        #expect(StatusIconState.unauthenticated.description == "Not Logged In")
        #expect(StatusIconState.criticalError.description == "Critical Error")
        #expect(StatusIconState.paused.description == "Paused")

        let aiStatus = StatusIconState.aiStatus(working: 2, notWorking: 1, unknown: 3)
        #expect(aiStatus.description == "AI Status: 2 working, 1 not working, 3 unknown")
    }

    @Test("Status icon state tooltip text") func statusIconStateTooltipText() {
        #expect(StatusIconState.idle.tooltipText == "CodeLooper")
        #expect(StatusIconState.syncing.tooltipText == "CodeLooper - Syncing Contacts...")
        #expect(StatusIconState.error.tooltipText == "CodeLooper - Sync Error")
        #expect(StatusIconState.warning.tooltipText == "CodeLooper - Warning")
        #expect(StatusIconState.success.tooltipText == "CodeLooper - Sync Successful")
        #expect(StatusIconState.authenticated.tooltipText == "CodeLooper - Signed In")
        #expect(StatusIconState.unauthenticated.tooltipText == "CodeLooper - Signed Out")
        #expect(StatusIconState.criticalError.tooltipText == "CodeLooper: Critical Error - Check Settings")
        #expect(StatusIconState.paused.tooltipText == "CodeLooper: Supervision Paused")

        let aiStatus = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        #expect(aiStatus.tooltipText == "CodeLooper: AI Analysis - 1 Working, 2 Not Working, 3 Unknown")
    }

    @Test("Status icon state template image usage") func statusIconStateTemplateImageUsage() {
        #expect(StatusIconState.idle.useTemplateImage)
        #expect(StatusIconState.syncing.useTemplateImage)
        #expect(StatusIconState.error.useTemplateImage)
        #expect(StatusIconState.warning.useTemplateImage)
        #expect(StatusIconState.success.useTemplateImage)
        #expect(StatusIconState.authenticated.useTemplateImage)
        #expect(StatusIconState.unauthenticated.useTemplateImage)
        #expect(StatusIconState.criticalError.useTemplateImage)
        #expect(StatusIconState.paused.useTemplateImage)

        // AI status should not use template image for custom colors
        #expect(StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3).useTemplateImage == false)
    }

    @Test("Status icon state hashable and sendable") func statusIconStateHashableAndSendable() {
        let state1 = StatusIconState.idle
        let state2 = StatusIconState.idle
        let state3 = StatusIconState.syncing

        // Test equality
        #expect(state1 == state2)
        #expect(state1 != state3)

        // Test hashable
        var stateSet: Set<StatusIconState> = []
        stateSet.insert(state1)
        stateSet.insert(state2) // Should not add duplicate
        stateSet.insert(state3)

        #expect(stateSet.count == 2)
        #expect(stateSet.contains(.idle))
        #expect(stateSet.contains(.syncing))

        // Test AI status equality
        let aiStatus1 = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        let aiStatus2 = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        let aiStatus3 = StatusIconState.aiStatus(working: 2, notWorking: 1, unknown: 3)

        #expect(aiStatus1 == aiStatus2)
        #expect(aiStatus1 != aiStatus3)
    }

    @Test("Status icon state a i status edge cases") func statusIconStateAIStatusEdgeCases() {
        // Test zero counts
        let zeroStatus = StatusIconState.aiStatus(working: 0, notWorking: 0, unknown: 0)
        #expect(zeroStatus.description == "AI Status: 0 working, 0 not working, 0 unknown")
        #expect(zeroStatus.rawValue == "aiStatus")

        // Test large counts
        let largeStatus = StatusIconState.aiStatus(working: 999, notWorking: 888, unknown: 777)
        #expect(largeStatus.description == "AI Status: 999 working, 888 not working, 777 unknown")

        // Test single non-zero count
        let singleWorkingStatus = StatusIconState.aiStatus(working: 1, notWorking: 0, unknown: 0)
        #expect(singleWorkingStatus.description == "AI Status: 1 working, 0 not working, 0 unknown")
    }

    @Test("Menu bar icon manager initialization") func menuBarIconManagerInitialization() {
        let manager = await MenuBarIconManager()

        // Test initial state
        #expect(manager != nil)

        let initialTooltip = await manager.currentTooltip
        #expect(initialTooltip.contains("CodeLooper"))
    }

    @Test("Menu bar icon manager state changes") func menuBarIconManagerStateChanges() {
        let manager = await MenuBarIconManager()

        // Test setting different states
        await manager.setState(.idle)
        let idleTooltip = await manager.currentTooltip
        #expect(idleTooltip == "CodeLooper")

        await manager.setState(.error)
        let errorTooltip = await manager.currentTooltip
        #expect(errorTooltip == "CodeLooper - Sync Error")

        await manager.setState(.syncing)
        let syncingTooltip = await manager.currentTooltip
        #expect(syncingTooltip == "CodeLooper - Syncing Contacts...")

        await manager.setState(.paused)
        let pausedTooltip = await manager.currentTooltip
        #expect(pausedTooltip == "CodeLooper: Supervision Paused")
    }

    @Test("Menu bar icon manager legacy methods") func menuBarIconManagerLegacyMethods() {
        let manager = await MenuBarIconManager()

        // Test legacy method compatibility
        await manager.setActiveIcon()
        let activeTooltip = await manager.currentTooltip
        #expect(activeTooltip == "CodeLooper - Signed In")

        await manager.setInactiveIcon()
        let inactiveTooltip = await manager.currentTooltip
        #expect(inactiveTooltip == "CodeLooper - Signed Out")

        await manager.setUploadingIcon()
        let uploadingTooltip = await manager.currentTooltip
        #expect(uploadingTooltip == "CodeLooper - Syncing Contacts...")

        await manager.setNormalIcon()
        let normalTooltip = await manager.currentTooltip
        #expect(normalTooltip == "CodeLooper")
    }

    @Test("Menu bar icon manager a i status icon") func menuBarIconManagerAIStatusIcon() {
        let manager = await MenuBarIconManager()

        // Test AI status with various counts
        await manager.setState(.aiStatus(working: 3, notWorking: 2, unknown: 1))
        let aiTooltip = await manager.currentTooltip
        #expect(aiTooltip == "CodeLooper: AI Analysis - 3 Working, 2 Not Working, 1 Unknown")

        // Test AI status with zero counts
        await manager.setState(.aiStatus(working: 0, notWorking: 0, unknown: 0))
        let zeroAITooltip = await manager.currentTooltip
        #expect(zeroAITooltip == "CodeLooper: AI Analysis - 0 Working, 0 Not Working, 0 Unknown")
    }

    @Test("Menu bar icon manager attributed string creation") func menuBarIconManagerAttributedStringCreation() {
        let manager = await MenuBarIconManager()

        // Test that attributed strings are created for different states
        await manager.setState(.idle)
        let idleString = await manager.currentIconAttributedString
        #expect(idleString != nil)

        await manager.setState(.error)
        let errorString = await manager.currentIconAttributedString
        #expect(errorString != nil)

        await manager.setState(.aiStatus(working: 2, notWorking: 1, unknown: 0))
        let aiString = await manager.currentIconAttributedString
        #expect(aiString != nil)
    }

    @Test("Menu bar icon manager concurrent state changes") func menuBarIconManagerConcurrentStateChanges() {
        let manager = await MenuBarIconManager()

        // Test concurrent state changes
        await withTaskGroup(of: Void.self) { group in
            let states: [StatusIconState] = [
                .idle, .syncing, .error, .warning, .success,
                .authenticated, .unauthenticated, .paused,
            ]

            for state in states {
                group.addTask {
                    await manager.setState(state)
                    // Brief delay to allow state processing
                    try? await Task.sleep(for: .milliseconds(1)) // 1ms
                }
            }
        }

        // After all concurrent operations, manager should still be in a valid state
        let finalTooltip = await manager.currentTooltip
        #expect(finalTooltip.contains("CodeLooper"))
    }

    @Test("Menu bar icon manager cleanup operations") func menuBarIconManagerCleanupOperations() {
        let manager = await MenuBarIconManager()

        // Test cleanup doesn't crash
        await manager.cleanup()

        // Manager should still be usable after cleanup
        await manager.setState(.idle)
        let tooltipAfterCleanup = await manager.currentTooltip
        #expect(tooltipAfterCleanup == "CodeLooper")
    }

    @Test("Status bar appearance handling") func statusBarAppearanceHandling() {
        // Test appearance name constants
        let darkAppearance = NSAppearance.Name.darkAqua
        let lightAppearance = NSAppearance.Name.aqua

        #expect(darkAppearance.rawValue == "NSAppearanceNameDarkAqua")
        #expect(lightAppearance.rawValue == "NSAppearanceNameAqua")
        #expect(darkAppearance != lightAppearance)
    }

    @Test("Status bar notification names") func statusBarNotificationNames() {
        // Test system notification name
        let themeChangeNotification = NSNotification.Name("AppleInterfaceThemeChangedNotification")
        #expect(themeChangeNotification.rawValue == "AppleInterfaceThemeChangedNotification")
    }

    @Test("Status bar attributed string creation") func statusBarAttributedStringCreation() {
        // Test creating attributed strings with different properties
        var attributes = AttributeContainer()
        attributes.font = Font.system(size: 12)
        attributes.foregroundColor = Color.white

        let attributedString = AttributedString("Test", attributes: attributes)
        #expect(attributedString.characters.count == 4)

        // Test appending attributed strings
        var result = AttributedString()
        result.append(AttributedString("🟢"))
        result.append(AttributedString("2"))
        #expect(result.characters.count == 2)
    }

    @Test("Status bar color definitions") func statusBarColorDefinitions() {
        // Test that colors can be created and are distinct
        let workingColor = Color.green
        let notWorkingColor = Color.red
        let unknownColor = Color.orange

        #expect(workingColor != notWorkingColor)
        #expect(notWorkingColor != unknownColor)
        #expect(unknownColor != workingColor)
    }

    @Test("Status bar memory management") func statusBarMemoryManagement() {
        // Test creating and releasing multiple managers
        var managers: [MenuBarIconManager] = []

        for _ in 0 ..< 10 {
            let manager = await MenuBarIconManager()
            await manager.setState(.idle)
            managers.append(manager)
        }

        #expect(managers.count == 10)

        // Test cleanup
        for manager in managers {
            await manager.cleanup()
        }

        managers.removeAll()
        #expect(managers.isEmpty)
    }

    @Test("Status bar state validation") func statusBarStateValidation() {
        let manager = await MenuBarIconManager()

        // Test state transitions don't crash
        let stateSequence: [StatusIconState] = [
            .idle,
            .syncing,
            .success,
            .error,
            .warning,
            .criticalError,
            .paused,
            .authenticated,
            .unauthenticated,
            .aiStatus(working: 1, notWorking: 2, unknown: 3),
            .idle, // Back to idle
        ]

        for state in stateSequence {
            await manager.setState(state)
            let tooltip = await manager.currentTooltip
            #expect(tooltip.count > 0)
            #expect(tooltip.contains("CodeLooper"))
        }
    }

    @Test("Status bar performance characteristics") func statusBarPerformanceCharacteristics() {
        let manager = await MenuBarIconManager()

        // Test rapid state changes
        let startTime = Date()
        for i in 0 ..< 100 {
            let state = StatusIconState.aiStatus(working: i % 10, notWorking: (i + 1) % 10, unknown: (i + 2) % 10)
            await manager.setState(state)
        }
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 1.0) // Should complete in under 1 second

        // Final state should be valid
        let finalTooltip = await manager.currentTooltip
        #expect(finalTooltip.contains("CodeLooper"))
    }
}
