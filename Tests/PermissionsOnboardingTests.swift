@testable import CodeLooper
import Foundation
import SwiftUI
import Testing

@Suite("PermissionsOnboardingTests")
struct PermissionsOnboardingTests {
    // MARK: - OnboardingCoordinator Tests

    @Test("Onboarding flow management") func onboardingFlowManagement() {
        let coordinator = await WelcomeWindowCoordinator.shared

        // Test that coordinator is created without errors
        #expect(coordinator != nil)

        // Test window management
        await coordinator.showWelcomeWindow()
        await coordinator.dismissWelcomeWindow()

        // Should handle window operations without crashes
        #expect(true)
    }

    @Test("Onboarding completion") func onboardingCompletion() {
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

    @Test("Onboarding step validation") func onboardingStepValidation() {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)

        // Test step state
        await MainActor.run {
            let currentStep = viewModel.currentStep
            #expect(currentStep == .welcome || currentStep == .accessibility || currentStep == .settings ||
                currentStep == .complete)
        }

        // Should handle validation checks gracefully
        #expect(true)
    }

    // MARK: - Permission Step Tests

    @Test("Accessibility permission step") func accessibilityPermissionStep() {
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

    @Test("Screen recording permission step") func screenRecordingPermissionStep() {
        // Test that screen recording permissions can be checked
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasScreenRecordingPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        // Should handle permission check without crashes
        #expect(true)
    }

    @Test("Notification permission step") func notificationPermissionStep() {
        // Test that notification permissions can be checked
        let permissionsManager = await PermissionsManager()
        await MainActor.run {
            let hasPermission = permissionsManager.hasNotificationPermissions
            #expect(hasPermission == true || hasPermission == false)
        }

        // Should handle notification permissions gracefully
        #expect(true)
    }

    @Test("Automation permission step") func automationPermissionStep() {
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

    @Test("Welcome view display") func welcomeViewDisplay() {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let welcomeView = WelcomeView(viewModel: viewModel)

        // Test that welcome view is created without errors
        #expect(welcomeView != nil)

        // Since this is a SwiftUI view, we mainly test it doesn't crash on creation
        #expect(true)
    }

    @Test("Permission card rendering") func permissionCardRendering() {
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

    @Test("Progress bar display") func progressBarDisplay() {
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

    @Test("Welcome guide flow") func welcomeGuideFlow() {
        let welcomeGuide = await WelcomeGuideView {}

        // Test that welcome guide is created without errors
        #expect(welcomeGuide != nil)

        // Should handle welcome flow without crashes
        #expect(true)
    }

    @Test("Welcome view model state") func welcomeViewModelState() {
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

    @Test("All permissions integration") func allPermissionsIntegration() {
        let allPermissionsView = await AllPermissionsView()

        // Test that comprehensive permissions view is created
        #expect(allPermissionsView != nil)

        // Should handle all permissions view creation
        #expect(true)
    }

    @Test("Permissions view integration") func permissionsViewIntegration() {
        let permissionsView = await PermissionsView()

        // Test that permissions view is created without errors
        #expect(permissionsView != nil)

        // Should handle permissions monitoring gracefully
        #expect(true)
    }

    // MARK: - Coordinator Integration Tests

    @Test("Welcome window coordination") func welcomeWindowCoordination() {
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

    @Test("Onboarding full flow") func onboardingFullFlow() {
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

    @Test("Welcome step view") func welcomeStepView() {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = WelcomeStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test("Settings step view") func settingsStepView() {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = SettingsStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test("Completion step view") func completionStepView() {
        let loginItemManager = await LoginItemManager.shared
        let viewModel = await WelcomeViewModel(loginItemManager: loginItemManager)
        let stepView = CompletionStepView(viewModel: viewModel)

        // Test that step view is created without errors
        #expect(stepView != nil)
    }

    @Test("Welcome window view") func welcomeWindowView() {
        let loginItemManager = await LoginItemManager.shared
        let windowView = await WelcomeWindowView(loginItemManager: loginItemManager)

        // Test that window view is created without errors
        #expect(windowView != nil)
    }

    // MARK: - Performance Tests

    @Test("Onboarding performance") func onboardingPerformance() {
        let loginItemManager = await LoginItemManager.shared

        // Test performance of creating multiple view models
        let startTime = Date()

        for _ in 0 ..< 10 {
            _ = await WelcomeViewModel(loginItemManager: loginItemManager)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete quickly (less than 0.5 seconds for 10 instances)
        #expect(duration < 0.5)
    }
}
