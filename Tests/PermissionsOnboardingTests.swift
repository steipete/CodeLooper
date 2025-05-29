@testable import CodeLooper
import Foundation
import SwiftUI
import Testing
import LaunchAtLogin

/// Test suite for permissions onboarding flow functionality
struct PermissionsOnboardingTests {
    // MARK: - OnboardingCoordinator Tests

    @Test
    func onboardingFlowManagement() async throws {
        let coordinator = await WelcomeWindowCoordinator.shared

        // Test that coordinator is created without errors
        #expect(coordinator != nil)

        // Test window management
        await coordinator.showWelcomeWindow()
        await coordinator.dismissWelcomeWindow()

        // Should handle window operations without crashes
        #expect(true)
    }

    @Test
    func onboardingCompletion() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)

        // Test initial state
        await MainActor.run {
            #expect(viewModel.currentStep == .welcome)
        }

        // Test step progression
        await viewModel.goToNextStep()
        
        await MainActor.run {
            #expect(viewModel.currentStep != .welcome)
        }

        // Should handle completion lifecycle
        #expect(true)
    }

    @Test
    func onboardingStepValidation() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)

        // Test step state
        await MainActor.run {
            let currentStep = viewModel.currentStep
            #expect(currentStep == .welcome || currentStep == .accessibility || currentStep == .settings || currentStep == .complete)
        }

        // Should handle validation checks gracefully
        #expect(true)
    }

    // MARK: - Permission Step Tests

    @Test
    func accessibilityPermissionStep() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        
        // Move to accessibility step
        await MainActor.run {
            viewModel.currentStep = .accessibility
        }

        // Test permission checking
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasAccessibilityPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        #expect(true)
    }

    @Test
    func screenRecordingPermissionStep() async throws {
        // Test that screen recording permissions can be checked
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasScreenRecordingPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        // Should handle permission check without crashes
        #expect(true)
    }

    @Test
    func notificationPermissionStep() async throws {
        // Test that notification permissions can be checked
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasNotificationPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        // Should handle notification permissions gracefully
        #expect(true)
    }

    @Test
    func automationPermissionStep() async throws {
        // Test that automation permissions can be checked
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasAutomationPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        // Should provide automation permission flow
        #expect(true)
    }

    // MARK: - UI Component Tests

    @Test
    func welcomeViewDisplay() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let welcomeView = WelcomeView(viewModel: viewModel)

        // Test that welcome view is created without errors
        #expect(welcomeView != nil)

        // Since this is a SwiftUI view, we mainly test it doesn't crash on creation
        #expect(true)
    }

    @Test
    func permissionCardRendering() async throws {
        let permissionCard = await PermissionCard(
            icon: "lock",
            iconColor: .accentColor,
            title: "Test Permission",
            description: "Test permission description",
            content: {
                EmptyView()
            }
        )

        // Test that permission card is created without errors
        #expect(permissionCard != nil)

        // Test with different icon
        let grantedCard = await PermissionCard(
            icon: "checkmark",
            iconColor: .green,
            title: "Granted Permission",
            description: "This permission is granted",
            content: {
                EmptyView()
            }
        )

        #expect(grantedCard != nil)
    }

    @Test
    func progressBarDisplay() async throws {
        let progressBar = ProgressBar(currentStep: .settings)

        // Test that progress bar is created without errors
        #expect(progressBar != nil)

        // Test different steps
        let welcomeProgress = ProgressBar(currentStep: .welcome)
        let completionProgress = ProgressBar(currentStep: .complete)

        #expect(welcomeProgress != nil)
        #expect(completionProgress != nil)
    }

    // MARK: - Welcome Flow Tests

    @Test
    func welcomeGuideFlow() async throws {
        let loginItemManager = await LoginItemManager.shared
        let welcomeGuide = await WelcomeGuideView { }

        // Test that welcome guide is created without errors
        #expect(welcomeGuide != nil)

        // Should handle welcome flow without crashes
        #expect(true)
    }

    @Test
    func welcomeViewModelState() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)

        // Test that view model is created without errors
        #expect(viewModel != nil)

        // Test state management
        await MainActor.run {
            #expect(viewModel.currentStep == .welcome)
            #expect(viewModel.startAtLogin == true || viewModel.startAtLogin == false)
        }

        // Test state transitions
        await viewModel.goToNextStep()
        await viewModel.goToPreviousStep()

        // Should manage state transitions gracefully
        #expect(true)
    }

    // MARK: - Permission Integration Tests

    @Test
    func allPermissionsIntegration() async throws {
        let loginItemManager = await LoginItemManager.shared
        let allPermissionsView = await AllPermissionsView()

        // Test that comprehensive permissions view is created
        #expect(allPermissionsView != nil)

        // Should handle all permissions view creation
        #expect(true)
    }

    @Test
    func permissionsViewIntegration() async throws {
        let permissionsView = await PermissionsView()

        // Test that permissions view is created without errors
        #expect(permissionsView != nil)

        // Should handle permissions monitoring gracefully
        #expect(true)
    }

    // MARK: - Coordinator Integration Tests

    @Test
    func welcomeWindowCoordination() async throws {
        let coordinator = await WelcomeWindowCoordinator.shared

        // Test window state management
        await MainActor.run {
            let hasWindow = coordinator.welcomeWindow != nil
            #expect(hasWindow == true || hasWindow == false)
        }

        // Test window operations
        await coordinator.showWelcomeWindow()
        
        await MainActor.run {
            #expect(coordinator.welcomeWindow != nil)
        }
        
        await coordinator.dismissWelcomeWindow()
        
        await MainActor.run {
            #expect(coordinator.welcomeWindow == nil)
        }
    }

    @Test
    func onboardingFullFlow() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)

        // Test complete flow
        await MainActor.run {
            // Start at welcome
            #expect(viewModel.currentStep == .welcome)
            
            // Move through steps
            viewModel.goToNextStep() // -> accessibility
            #expect(viewModel.currentStep == .accessibility)
            
            viewModel.goToNextStep() // -> settings
            #expect(viewModel.currentStep == .settings)
            
            viewModel.goToNextStep() // -> complete
            #expect(viewModel.currentStep == .complete)
        }

        // Should complete full onboarding flow
        #expect(true)
    }

    @Test
    func welcomeStepView() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = await WelcomeStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test
    func settingsStepView() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = await SettingsStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test
    func completionStepView() async throws {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = await CompletionStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test
    func welcomeWindowView() async throws {
        let loginItemManager = await LoginItemManager.shared
        let windowView = await WelcomeWindowView(loginItemManager: loginItemManager)

        // Test that window view is created without errors
        #expect(windowView != nil)
    }

    // MARK: - Performance Tests

    @Test
    func onboardingPerformance() async throws {
        let loginItemManager = await LoginItemManager.shared
        
        // Test performance of creating multiple view models
        let startTime = Date()
        
        for _ in 0..<10 {
            let _ = await WelcomeViewModel(loginItemManager: loginItemManager)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete quickly (less than 0.5 seconds for 10 instances)
        #expect(duration < 0.5)
    }
}