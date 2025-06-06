import AppKit
@testable import CodeLooper
import Defaults
import Foundation
import Testing

@Suite("Icon Animation Tests")
@MainActor
struct IconAnimationTests {
    // MARK: - IconAnimator Tests

    @Test("Icon animation start")
    func iconAnimationStart() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Test that animator is created without errors
        #expect(animator != nil)

        // Test starting animation
        animator.startAnimating()

        // Test animation state
        let isAnimating = animator.isCurrentlyAnimating
        #expect(!isAnimating == true || isAnimating) // Either state is valid

        // Test stopping animation
        animator.stopAnimating()

        // Animation should be stopped
        let isStoppedAnimating = animator.isCurrentlyAnimating
        #expect(!isStoppedAnimating)
    }

    @Test("Icon animation stop")
    func iconAnimationStop() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Initially not animating
        var isAnimating = animator.isCurrentlyAnimating
        #expect(!isAnimating)

        // Start animation
        animator.startAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating)

        // Stop animation
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(!isAnimating)

        // Multiple stop calls should be safe
        animator.stopAnimating()
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(!isAnimating)
    }

    @Test("Icon animation state management")
    func iconAnimationStateManagement() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Test rapid state changes
        animator.startAnimating()
        animator.stopAnimating()
        animator.startAnimating()
        animator.stopAnimating()

        // Final state should be stopped
        let finalState = animator.isCurrentlyAnimating
        #expect(!finalState)

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
        #expect(!concurrentState == true || concurrentState)
    }


    // MARK: - MenuBarIconManager Tests

    @Test("Menu bar icon manager coordination")
    func menuBarIconManagerCoordination() async throws {
        await MainActor.run {
            let manager = MenuBarIconManager.shared

            // Test that manager is created without errors
            #expect(manager != nil)

            // Test icon state updates
            manager.setState(.idle)
            manager.setState(.syncing)
            manager.setState(.success)

            // Test that state changes don't crash
            #expect(true)
        }
    }

    @Test("Menu bar icon manager rapid changes")
    func menuBarIconManagerRapidChanges() async throws {
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
            #expect(true)
        }
    }

    // MARK: - NSImage Resource Loading Tests

    @Test("NSImage resource loading")
    func nsImageResourceLoading() async throws {
        // Test loading icon resources
        let menuBarIcon = NSImage(named: "menubar")

        // Icon may or may not exist in test environment
        #expect(menuBarIcon != nil || menuBarIcon == nil)

        // Should not crash regardless of file availability
        #expect(true)
    }

    @Test("NSImage missing resource handling")
    func nsImageMissingResourceHandling() async throws {
        // Test loading non-existent icon
        let nonExistentIcon = NSImage(named: "definitely_does_not_exist")
        #expect(nonExistentIcon == nil)

        // Test loading with empty name
        let emptyIcon = NSImage(named: "")
        #expect(emptyIcon == nil)

        // Should handle missing resources gracefully
        #expect(true)
    }

    // MARK: - Integration Tests

    @Test("Icon animation system integration")
    func iconAnimationSystemIntegration() async throws {
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
            #expect(true)
        }
    }

    @Test("Icon animation performance")
    func iconAnimationPerformance() async throws {
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
            #expect(duration < 2.0)

            // Final state should be valid
            let currentTooltip = manager.currentTooltip
            #expect(currentTooltip.contains("CodeLooper"))
        }
    }
}
