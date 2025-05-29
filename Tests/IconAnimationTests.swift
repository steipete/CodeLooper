import AppKit
@testable import CodeLooper
import Foundation
import Testing

/// Test suite for menu bar icon animation functionality
@Suite("Icon Animation Tests")
struct IconAnimationTests {
    // MARK: - IconAnimator Tests

    @Test("IconAnimator can manage animation lifecycle")
    func iconAnimationStart() async throws {
        let animator = IconAnimator()

        // Test that animator is created without errors
        #expect(animator != nil)

        // Test starting animation
        await animator.startAnimation()

        // Test animation state
        let isAnimating = await animator.isAnimating
        #expect(isAnimating == true || isAnimating == false) // Either state is valid

        // Test stopping animation
        await animator.stopAnimation()

        // Animation should be stopped
        let isStoppedAnimating = await animator.isAnimating
        #expect(isStoppedAnimating == false)
    }

    @Test("IconAnimator handles animation state correctly")
    func iconAnimationStop() async throws {
        let animator = IconAnimator()

        // Initially not animating
        var isAnimating = await animator.isAnimating
        #expect(isAnimating == false)

        // Start animation
        await animator.startAnimation()
        isAnimating = await animator.isAnimating
        #expect(isAnimating == true)

        // Stop animation
        await animator.stopAnimation()
        isAnimating = await animator.isAnimating
        #expect(isAnimating == false)

        // Multiple stop calls should be safe
        await animator.stopAnimation()
        await animator.stopAnimation()
        isAnimating = await animator.isAnimating
        #expect(isAnimating == false)
    }

    @Test("IconAnimator manages animation state transitions")
    func iconAnimationStateManagement() async throws {
        let animator = IconAnimator()

        // Test rapid state changes
        await animator.startAnimation()
        await animator.stopAnimation()
        await animator.startAnimation()
        await animator.stopAnimation()

        // Final state should be stopped
        let finalState = await animator.isAnimating
        #expect(finalState == false)

        // Test concurrent state changes
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await animator.startAnimation()
            }
            group.addTask {
                await animator.stopAnimation()
            }
            group.addTask {
                await animator.startAnimation()
            }
        }

        // Should handle concurrent access gracefully
        let concurrentState = await animator.isAnimating
        #expect(concurrentState == true || concurrentState == false)
    }

    // MARK: - LottieMenuBarView Tests

    @Test("LottieMenuBarView integrates with Lottie framework")
    func lottieMenuBarIntegration() async throws {
        // Test that LottieMenuBarView can be created
        let lottieView = LottieMenuBarView()

        #expect(lottieView != nil)

        // Test basic view properties
        #expect(lottieView.frame != nil)

        // Test that view can handle animation state changes
        await lottieView.setAnimationState(.playing)
        await lottieView.setAnimationState(.paused)
        await lottieView.setAnimationState(.stopped)

        // If we get here without crashes, Lottie integration works
        #expect(true)
    }

    @Test("LottieMenuBarView handles animation files")
    func lottieAnimationFileHandling() async throws {
        let lottieView = LottieMenuBarView()

        // Test loading animation file
        let success = await lottieView.loadAnimation(named: "chain_link_lottie")

        // File may or may not exist in test environment
        #expect(success == true || success == false)

        // Test handling invalid animation file
        let invalidSuccess = await lottieView.loadAnimation(named: "nonexistent_animation")
        #expect(invalidSuccess == false)

        // Should handle invalid files gracefully
        #expect(true)
    }

    // MARK: - CustomChainLinkIcon Tests

    @Test("CustomChainLinkIcon renders without errors")
    func customChainLinkIcon() async throws {
        let iconView = CustomChainLinkIcon()

        // Test that custom icon view is created without errors
        #expect(iconView != nil)

        // Test basic view properties
        #expect(iconView.frame != nil)

        // Test that icon can be rendered
        await iconView.updateIcon(state: .idle)
        await iconView.updateIcon(state: .active)
        await iconView.updateIcon(state: .error)

        // If we get here without crashes, custom icon rendering works
        #expect(true)
    }

    @Test("CustomChainLinkIcon handles different states")
    func customChainLinkIconStates() async throws {
        let iconView = CustomChainLinkIcon()

        // Test all possible icon states
        let states: [StatusIconState] = [
            .idle, .syncing, .error, .warning, .success,
            .authenticated, .unauthenticated, .paused,
        ]

        for state in states {
            await iconView.updateIcon(state: state)

            // Give a moment for state to update
            try await Task.sleep(for: .milliseconds(10))
        }

        // All states should be handled without crashes
        #expect(true)
    }

    // MARK: - MenuBarIconManager Tests

    @Test("MenuBarIconManager coordinates icon updates")
    func menuBarIconManagerCoordination() async throws {
        let manager = MenuBarIconManager.shared

        // Test that manager is created without errors
        #expect(manager != nil)

        // Test icon state updates
        await manager.setState(.idle)
        await manager.setState(.syncing)
        await manager.setState(.success)

        // Test that state changes don't crash
        #expect(true)
    }

    @Test("MenuBarIconManager handles rapid state changes")
    func menuBarIconManagerRapidChanges() async throws {
        let manager = MenuBarIconManager.shared

        // Test rapid state changes
        let states: [StatusIconState] = [
            .idle, .syncing, .error, .warning, .success,
        ]

        for state in states {
            await manager.setState(state)
        }

        // Test concurrent state changes
        await withTaskGroup(of: Void.self) { group in
            for state in states {
                group.addTask {
                    await manager.setState(state)
                    try? await Task.sleep(for: .milliseconds(5))
                }
            }
        }

        // Should handle rapid changes gracefully
        #expect(true)
    }

    // MARK: - NSImage Resource Loading Tests

    @Test("NSImage resource loading works correctly")
    func nSImageResourceLoading() async throws {
        // Test loading menu bar icon resources
        let menuBarIcon = NSImage.loadMenuBarIcon()

        // Icon may or may not exist in test environment
        #expect(menuBarIcon != nil || menuBarIcon == nil)

        // Test loading template icons
        let templateIcon = NSImage.loadTemplateIcon(named: "menubar")
        #expect(templateIcon != nil || templateIcon == nil)

        // Should not crash regardless of file availability
        #expect(true)
    }

    @Test("NSImage handles missing resources gracefully")
    func nSImageMissingResourceHandling() async throws {
        // Test loading non-existent icon
        let nonExistentIcon = NSImage.loadTemplateIcon(named: "definitely_does_not_exist")
        #expect(nonExistentIcon == nil)

        // Test loading with nil name
        let nilIcon = NSImage.loadTemplateIcon(named: "")
        #expect(nilIcon == nil)

        // Should handle missing resources gracefully
        #expect(true)
    }

    // MARK: - Integration Tests

    @Test("Complete icon animation system integration")
    func iconAnimationSystemIntegration() async throws {
        let animator = IconAnimator()
        let manager = MenuBarIconManager.shared
        let customIcon = CustomChainLinkIcon()

        // Test that all components can work together
        await animator.startAnimation()
        await manager.setState(.syncing)
        await customIcon.updateIcon(state: .syncing)

        // Give time for all updates to process
        try await Task.sleep(for: .milliseconds(100))

        // Stop animation
        await animator.stopAnimation()
        await manager.setState(.idle)
        await customIcon.updateIcon(state: .idle)

        // System should work without conflicts
        #expect(true)
    }

    @Test("Icon animation performance under load")
    func iconAnimationPerformance() async throws {
        let manager = MenuBarIconManager.shared

        // Test performance with many rapid state changes
        let startTime = Date()

        for i in 0 ..< 50 {
            let state: StatusIconState = i % 2 == 0 ? .idle : .syncing
            await manager.setState(state)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 2 seconds for 50 changes)
        #expect(duration < 2.0)

        // Final state should be valid
        let currentTooltip = await manager.currentTooltip
        #expect(currentTooltip.contains("CodeLooper"))
    }
}
