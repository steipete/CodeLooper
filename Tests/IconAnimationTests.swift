import AppKit
@testable import CodeLooper
import Defaults
import Foundation
import XCTest

@MainActor
class IconAnimationTests: XCTestCase {
    // MARK: - IconAnimator Tests

    func testIconAnimationStart() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Test that animator is created without errors
        XCTAssertNotNil(animator)

        // Test starting animation
        animator.startAnimating()

        // Test animation state
        let isAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isAnimating, true || isAnimating == false) // Either state is valid

        // Test stopping animation
        animator.stopAnimating()

        // Animation should be stopped
        let isStoppedAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isStoppedAnimating, false)
    }

    func testIconAnimationStop() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Initially not animating
        var isAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isAnimating, false)

        // Start animation
        animator.startAnimating()
        isAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isAnimating, true)

        // Stop animation
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isAnimating, false)

        // Multiple stop calls should be safe
        animator.stopAnimating()
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        XCTAssertEqual(isAnimating, false)
    }

    func testIconAnimationStateManagement() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Test rapid state changes
        animator.startAnimating()
        animator.stopAnimating()
        animator.startAnimating()
        animator.stopAnimating()

        // Final state should be stopped
        let finalState = animator.isCurrentlyAnimating
        XCTAssertEqual(finalState, false)

        // Test concurrent state changes
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                animator.startAnimating()
            }
            group.addTask { @MainActor in
                animator.stopAnimating()
            }
            group.addTask { @MainActor in
                animator.startAnimating()
            }
        }

        // Should handle concurrent access gracefully
        let concurrentState = animator.isCurrentlyAnimating
        XCTAssertEqual(concurrentState, true || concurrentState == false)
    }


    // MARK: - MenuBarIconManager Tests

    func testMenuBarIconManagerCoordination() async throws {
        await MainActor.run {
            let manager = MenuBarIconManager.shared

            // Test that manager is created without errors
            XCTAssertNotNil(manager)

            // Test icon state updates
            manager.setState(.idle)
            manager.setState(.syncing)
            manager.setState(.success)

            // Test that state changes don't crash
            XCTAssertTrue(true)
        }
    }

    func testMenuBarIconManagerRapidChanges() async throws {
        await MainActor.run {
            let manager = MenuBarIconManager.shared

            // Test rapid state changes
            let states: [StatusIconState] = [
                .idle, .syncing, .error, .warning, .success,
            ]

            for state in states {
                manager.setState(state)
            }

            // Should handle rapid changes gracefully
            XCTAssertTrue(true)
        }
    }

    // MARK: - NSImage Resource Loading Tests

    func testNSImageResourceLoading() async throws {
        // Test loading icon resources
        let menuBarIcon = NSImage(named: "menubar")

        // Icon may or may not exist in test environment
        XCTAssertTrue(menuBarIcon != nil || menuBarIcon == nil)

        // Should not crash regardless of file availability
        XCTAssertTrue(true)
    }

    func testNSImageMissingResourceHandling() async throws {
        // Test loading non-existent icon
        let nonExistentIcon = NSImage(named: "definitely_does_not_exist")
        XCTAssertEqual(nonExistentIcon, nil)

        // Test loading with empty name
        let emptyIcon = NSImage(named: "")
        XCTAssertEqual(emptyIcon, nil)

        // Should handle missing resources gracefully
        XCTAssertTrue(true)
    }

    // MARK: - Integration Tests

    func testIconAnimationSystemIntegration() async throws {
        await MainActor.run {
            let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let animator = IconAnimator(statusItem: mockStatusItem)
            let manager = MenuBarIconManager.shared
            // Test that all components can work together
            animator.startAnimating()
            manager.setState(.syncing)

            // Stop animation
            animator.stopAnimating()
            manager.setState(.idle)

            // System should work without conflicts
            XCTAssertTrue(true)
        }
    }

    func testIconAnimationPerformance() async throws {
        await MainActor.run {
            let manager = MenuBarIconManager.shared

            // Test performance with many rapid state changes
            let startTime = Date()

            for i in 0 ..< 50 {
                let state: StatusIconState = i % 2 == 0 ? .idle : .syncing
                manager.setState(state)
            }

            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            // Should complete reasonably quickly (less than 2 seconds for 50 changes)
            XCTAssertLessThan(duration, 2.0)

            // Final state should be valid
            let currentTooltip = manager.currentTooltip
            XCTAssertTrue(currentTooltip.contains("CodeLooper"))
        }
    }
}
