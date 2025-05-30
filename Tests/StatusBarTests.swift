import AppKit
@testable import CodeLooper
import Foundation
import SwiftUI
import XCTest

class StatusBarTests: XCTestCase {
    func testStatusIconStateAllCases() async throws {
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
            XCTAssertGreaterThan(state.rawValue.count, 0)
            XCTAssertGreaterThan(state.description.count, 0)
            XCTAssertGreaterThan(state.tooltipText.count, 0)
        }
    }

    func testStatusIconStateRawValues() async throws {
        XCTAssertEqual(StatusIconState.idle.rawValue, "idle")
        XCTAssertEqual(StatusIconState.syncing.rawValue, "syncing")
        XCTAssertEqual(StatusIconState.error.rawValue, "error")
        XCTAssertEqual(StatusIconState.warning.rawValue, "warning")
        XCTAssertEqual(StatusIconState.success.rawValue, "success")
        XCTAssertEqual(StatusIconState.authenticated.rawValue, "authenticated")
        XCTAssertEqual(StatusIconState.unauthenticated.rawValue, "unauthenticated")
        XCTAssertEqual(StatusIconState.criticalError.rawValue, "criticalError")
        XCTAssertEqual(StatusIconState.paused.rawValue, "paused")
        XCTAssertEqual(StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3).rawValue, "aiStatus")
    }

    func testStatusIconStateDescriptions() async throws {
        XCTAssertEqual(StatusIconState.idle.description, "Idle")
        XCTAssertEqual(StatusIconState.syncing.description, "Syncing")
        XCTAssertEqual(StatusIconState.error.description, "Error")
        XCTAssertEqual(StatusIconState.warning.description, "Warning")
        XCTAssertEqual(StatusIconState.success.description, "Success")
        XCTAssertEqual(StatusIconState.authenticated.description, "Authenticated")
        XCTAssertEqual(StatusIconState.unauthenticated.description, "Not Logged In")
        XCTAssertEqual(StatusIconState.criticalError.description, "Critical Error")
        XCTAssertEqual(StatusIconState.paused.description, "Paused")

        let aiStatus = StatusIconState.aiStatus(working: 2, notWorking: 1, unknown: 3)
        XCTAssertEqual(aiStatus.description, "AI Status: 2 working, 1 not working, 3 unknown")
    }

    func testStatusIconStateTooltipText() async throws {
        XCTAssertEqual(StatusIconState.idle.tooltipText, "CodeLooper")
        XCTAssertEqual(StatusIconState.syncing.tooltipText, "CodeLooper - Syncing Contacts...")
        XCTAssertEqual(StatusIconState.error.tooltipText, "CodeLooper - Sync Error")
        XCTAssertEqual(StatusIconState.warning.tooltipText, "CodeLooper - Warning")
        XCTAssertEqual(StatusIconState.success.tooltipText, "CodeLooper - Sync Successful")
        XCTAssertEqual(StatusIconState.authenticated.tooltipText, "CodeLooper - Signed In")
        XCTAssertEqual(StatusIconState.unauthenticated.tooltipText, "CodeLooper - Signed Out")
        XCTAssertEqual(StatusIconState.criticalError.tooltipText, "CodeLooper: Critical Error - Check Settings")
        XCTAssertEqual(StatusIconState.paused.tooltipText, "CodeLooper: Supervision Paused")

        let aiStatus = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        XCTAssertEqual(aiStatus.tooltipText, "CodeLooper: AI Analysis - 1 Working, 2 Not Working, 3 Unknown")
    }

    func testStatusIconStateTemplateImageUsage() async throws {
        XCTAssertEqual(StatusIconState.idle.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.syncing.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.error.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.warning.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.success.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.authenticated.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.unauthenticated.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.criticalError.useTemplateImage, true)
        XCTAssertEqual(StatusIconState.paused.useTemplateImage, true)

        // AI status should not use template image for custom colors
        XCTAssertEqual(StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3).useTemplateImage, false)
    }

    func testStatusIconStateHashableAndSendable() async throws {
        let state1 = StatusIconState.idle
        let state2 = StatusIconState.idle
        let state3 = StatusIconState.syncing

        // Test equality
        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)

        // Test hashable
        var stateSet: Set<StatusIconState> = []
        stateSet.insert(state1)
        stateSet.insert(state2) // Should not add duplicate
        stateSet.insert(state3)

        XCTAssertEqual(stateSet.count, 2)
        XCTAssertTrue(stateSet.contains(.idle))
        XCTAssertTrue(stateSet.contains(.syncing))

        // Test AI status equality
        let aiStatus1 = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        let aiStatus2 = StatusIconState.aiStatus(working: 1, notWorking: 2, unknown: 3)
        let aiStatus3 = StatusIconState.aiStatus(working: 2, notWorking: 1, unknown: 3)

        XCTAssertEqual(aiStatus1, aiStatus2)
        XCTAssertNotEqual(aiStatus1, aiStatus3)
    }

    func testStatusIconStateAIStatusEdgeCases() async throws {
        // Test zero counts
        let zeroStatus = StatusIconState.aiStatus(working: 0, notWorking: 0, unknown: 0)
        XCTAssertEqual(zeroStatus.description, "AI Status: 0 working, 0 not working, 0 unknown")
        XCTAssertEqual(zeroStatus.rawValue, "aiStatus")

        // Test large counts
        let largeStatus = StatusIconState.aiStatus(working: 999, notWorking: 888, unknown: 777)
        XCTAssertEqual(largeStatus.description, "AI Status: 999 working, 888 not working, 777 unknown")

        // Test single non-zero count
        let singleWorkingStatus = StatusIconState.aiStatus(working: 1, notWorking: 0, unknown: 0)
        XCTAssertEqual(singleWorkingStatus.description, "AI Status: 1 working, 0 not working, 0 unknown")
    }

    func testMenuBarIconManagerInitialization() async throws {
        let manager = await MenuBarIconManager()

        // Test initial state
        XCTAssertNotNil(manager)

        let initialTooltip = await manager.currentTooltip
        XCTAssertTrue(initialTooltip.contains("CodeLooper"))
    }

    func testMenuBarIconManagerStateChanges() async throws {
        let manager = await MenuBarIconManager()

        // Test setting different states
        await manager.setState(.idle)
        let idleTooltip = await manager.currentTooltip
        XCTAssertEqual(idleTooltip, "CodeLooper")

        await manager.setState(.error)
        let errorTooltip = await manager.currentTooltip
        XCTAssertEqual(errorTooltip, "CodeLooper - Sync Error")

        await manager.setState(.syncing)
        let syncingTooltip = await manager.currentTooltip
        XCTAssertEqual(syncingTooltip, "CodeLooper - Syncing Contacts...")

        await manager.setState(.paused)
        let pausedTooltip = await manager.currentTooltip
        XCTAssertEqual(pausedTooltip, "CodeLooper: Supervision Paused")
    }

    func testMenuBarIconManagerLegacyMethods() async throws {
        let manager = await MenuBarIconManager()

        // Test legacy method compatibility
        await manager.setActiveIcon()
        let activeTooltip = await manager.currentTooltip
        XCTAssertEqual(activeTooltip, "CodeLooper - Signed In")

        await manager.setInactiveIcon()
        let inactiveTooltip = await manager.currentTooltip
        XCTAssertEqual(inactiveTooltip, "CodeLooper - Signed Out")

        await manager.setUploadingIcon()
        let uploadingTooltip = await manager.currentTooltip
        XCTAssertEqual(uploadingTooltip, "CodeLooper - Syncing Contacts...")

        await manager.setNormalIcon()
        let normalTooltip = await manager.currentTooltip
        XCTAssertEqual(normalTooltip, "CodeLooper")
    }

    func testMenuBarIconManagerAIStatusIcon() async throws {
        let manager = await MenuBarIconManager()

        // Test AI status with various counts
        await manager.setState(.aiStatus(working: 3, notWorking: 2, unknown: 1))
        let aiTooltip = await manager.currentTooltip
        XCTAssertEqual(aiTooltip, "CodeLooper: AI Analysis - 3 Working, 2 Not Working, 1 Unknown")

        // Test AI status with zero counts
        await manager.setState(.aiStatus(working: 0, notWorking: 0, unknown: 0))
        let zeroAITooltip = await manager.currentTooltip
        XCTAssertEqual(zeroAITooltip, "CodeLooper: AI Analysis - 0 Working, 0 Not Working, 0 Unknown")
    }

    func testMenuBarIconManagerAttributedStringCreation() async throws {
        let manager = await MenuBarIconManager()

        // Test that attributed strings are created for different states
        await manager.setState(.idle)
        let idleString = await manager.currentIconAttributedString
        XCTAssertNotNil(idleString)

        await manager.setState(.error)
        let errorString = await manager.currentIconAttributedString
        XCTAssertNotNil(errorString)

        await manager.setState(.aiStatus(working: 2, notWorking: 1, unknown: 0))
        let aiString = await manager.currentIconAttributedString
        XCTAssertNotNil(aiString)
    }

    func testMenuBarIconManagerConcurrentStateChanges() async throws {
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
        XCTAssertTrue(finalTooltip.contains("CodeLooper"))
    }

    func testMenuBarIconManagerCleanupOperations() async throws {
        let manager = await MenuBarIconManager()

        // Test cleanup doesn't crash
        await manager.cleanup()

        // Manager should still be usable after cleanup
        await manager.setState(.idle)
        let tooltipAfterCleanup = await manager.currentTooltip
        XCTAssertEqual(tooltipAfterCleanup, "CodeLooper")
    }

    func testStatusBarAppearanceHandling() async throws {
        // Test appearance name constants
        let darkAppearance = NSAppearance.Name.darkAqua
        let lightAppearance = NSAppearance.Name.aqua

        XCTAssertEqual(darkAppearance.rawValue, "NSAppearanceNameDarkAqua")
        XCTAssertEqual(lightAppearance.rawValue, "NSAppearanceNameAqua")
        XCTAssertNotEqual(darkAppearance, lightAppearance)
    }

    func testStatusBarNotificationNames() async throws {
        // Test system notification name
        let themeChangeNotification = NSNotification.Name("AppleInterfaceThemeChangedNotification")
        XCTAssertEqual(themeChangeNotification.rawValue, "AppleInterfaceThemeChangedNotification")
    }

    func testStatusBarAttributedStringCreation() async throws {
        // Test creating attributed strings with different properties
        var attributes = AttributeContainer()
        attributes.font = Font.system(size: 12)
        attributes.foregroundColor = Color.white

        let attributedString = AttributedString("Test", attributes: attributes)
        XCTAssertEqual(attributedString.characters.count, 4)

        // Test appending attributed strings
        var result = AttributedString()
        result.append(AttributedString("🟢"))
        result.append(AttributedString("2"))
        XCTAssertEqual(result.characters.count, 2)
    }

    func testStatusBarColorDefinitions() async throws {
        // Test that colors can be created and are distinct
        let workingColor = Color.green
        let notWorkingColor = Color.red
        let unknownColor = Color.orange

        XCTAssertNotEqual(workingColor, notWorkingColor)
        XCTAssertNotEqual(notWorkingColor, unknownColor)
        XCTAssertNotEqual(unknownColor, workingColor)
    }

    func testStatusBarMemoryManagement() async throws {
        // Test creating and releasing multiple managers
        var managers: [MenuBarIconManager] = []

        for _ in 0 ..< 10 {
            let manager = await MenuBarIconManager()
            await manager.setState(.idle)
            managers.append(manager)
        }

        XCTAssertEqual(managers.count, 10)

        // Test cleanup
        for manager in managers {
            await manager.cleanup()
        }

        managers.removeAll()
        XCTAssertTrue(managers.isEmpty)
    }

    func testStatusBarStateValidation() async throws {
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
            XCTAssertGreaterThan(tooltip.count, 0)
            XCTAssertTrue(tooltip.contains("CodeLooper"))
        }
    }

    func testStatusBarPerformanceCharacteristics() async throws {
        let manager = await MenuBarIconManager()

        // Test rapid state changes
        let startTime = Date()
        for i in 0 ..< 100 {
            let state = StatusIconState.aiStatus(working: i % 10, notWorking: (i + 1) % 10, unknown: (i + 2) % 10)
            await manager.setState(state)
        }
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(elapsed, 1.0) // Should complete in under 1 second

        // Final state should be valid
        let finalTooltip = await manager.currentTooltip
        XCTAssertTrue(finalTooltip.contains("CodeLooper"))
    }
}
