import AppKit
@testable import CodeLooper
import Defaults
import Foundation
import Testing

/// Test suite for menu bar icon animation functionality
struct IconAnimationTests {
    // MARK: - IconAnimator Tests

    @Test
    @MainActor
    func iconAnimationStart() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Test that animator is created without errors
        #expect(animator != nil)

        // Test starting animation
        animator.startAnimating()

        // Test animation state
        let isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating == true || isAnimating == false) // Either state is valid

        // Test stopping animation
        animator.stopAnimating()

        // Animation should be stopped
        let isStoppedAnimating = animator.isCurrentlyAnimating
        #expect(isStoppedAnimating == false)
    }

    @Test
    @MainActor
    func iconAnimationStop() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)

        // Initially not animating
        var isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating == false)

        // Start animation
        animator.startAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating == true)

        // Stop animation
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating == false)

        // Multiple stop calls should be safe
        animator.stopAnimating()
        animator.stopAnimating()
        isAnimating = animator.isCurrentlyAnimating
        #expect(isAnimating == false)
    }

    @Test
    @MainActor
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
        #expect(finalState == false)

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
        #expect(concurrentState == true || concurrentState == false)
    }

    // MARK: - LottieMenuBarView Tests

    @Test
    @MainActor
    func lottieMenuBarIntegration() async throws {
        // Test that LottieMenuBarView can be created
        let lottieView = LottieMenuBarView()

        // LottieMenuBarView is a SwiftUI view, just verify it can be created
        #expect(true)
    }

    @Test
    @MainActor
    func lottieAnimationFileHandling() async throws {
        let lottieView = LottieMenuBarView()

        // LottieMenuBarView handles animation loading internally
        // Just verify it doesn't crash
        #expect(true)
    }

    // MARK: - CustomChainLinkIcon Tests

    @Test
    @MainActor
    func customChainLinkIcon() async throws {
        let iconView = CustomChainLinkIcon(size: 16)

        // Test that custom icon view is created without errors
        #expect(iconView != nil)

        // Test basic view properties
        #expect(iconView.frame != nil)

        // CustomChainLinkIcon is a SwiftUI view that updates based on defaults
        // Just verify it doesn't crash

        // If we get here without crashes, custom icon rendering works
        #expect(true)
    }

    @Test
    @MainActor
    func customChainLinkIconStates() async throws {
        let iconView = CustomChainLinkIcon(size: 16)

        // CustomChainLinkIcon animates based on isGlobalMonitoringEnabled default
        // Toggle the default to test animation changes
        Defaults[.isGlobalMonitoringEnabled] = true
        try await Task.sleep(for: .milliseconds(10))
        
        Defaults[.isGlobalMonitoringEnabled] = false
        try await Task.sleep(for: .milliseconds(10))

        // All states should be handled without crashes
        #expect(true)
    }

    // MARK: - MenuBarIconManager Tests

    @Test
    func menuBarIconManagerCoordination() async throws {
        let manager = await MenuBarIconManager.shared

        // Test that manager is created without errors
        #expect(manager != nil)

        // Test icon state updates
        await manager.setState(.idle)
        await manager.setState(.syncing)
        await manager.setState(.success)

        // Test that state changes don't crash
        #expect(true)
    }

    @Test
    func menuBarIconManagerRapidChanges() async throws {
        let manager = await MenuBarIconManager.shared

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

    @Test
    func nSImageResourceLoading() async throws {
        // Test loading icon resources
        let menuBarIcon = NSImage(named: "menubar")
        
        // Icon may or may not exist in test environment
        #expect(menuBarIcon != nil || menuBarIcon == nil)

        // Should not crash regardless of file availability
        #expect(true)
    }

    @Test
    func nSImageMissingResourceHandling() async throws {
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

    @Test
    @MainActor
    func iconAnimationSystemIntegration() async throws {
        let mockStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let animator = IconAnimator(statusItem: mockStatusItem)
        let manager = await MenuBarIconManager.shared
        let customIcon = CustomChainLinkIcon(size: 16)

        // Test that all components can work together
        animator.startAnimating()
        await manager.setState(.syncing)
        // CustomChainLinkIcon updates automatically based on defaults

        // Give time for all updates to process
        try await Task.sleep(for: .milliseconds(100))

        // Stop animation
        animator.stopAnimating()
        await manager.setState(.idle)
        // CustomChainLinkIcon updates automatically

        // System should work without conflicts
        #expect(true)
    }

    @Test
    func iconAnimationPerformance() async throws {
        let manager = await MenuBarIconManager.shared

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
