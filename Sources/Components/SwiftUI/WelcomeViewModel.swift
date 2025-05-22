import Defaults
import Observation
import OSLog
import SwiftUI

// MARK: - Welcome View Model

@MainActor
@Observable final class WelcomeViewModel: ObservableObject {
    private let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "WelcomeViewModel")
    var currentStep: WelcomeStep = .welcome

    // Computed property for startAtLogin
    var startAtLogin: Bool {
        get { Defaults[.startAtLogin] }
        set { Defaults[.startAtLogin] = newValue }
    }

    private var loginItemManager: LoginItemManager
    private var onCompletionCallback: (() -> Void)?

    init(loginItemManager: LoginItemManager, onCompletion: (() -> Void)? = nil) {
        self.loginItemManager = loginItemManager
        onCompletionCallback = onCompletion

        logger.info("WelcomeViewModel initialized for CodeLooper")
    }

    // MARK: - Navigation

    func goToNextStep() {
        logger.info("Attempting to move from step: \(String(describing: self.currentStep)) to next step")

        // Special cases based on current step
        switch currentStep {
        case .welcome:
            // From welcome, go to settings step
            currentStep = .settings
            logger.info("Moving to settings step")

        case .settings:
            // Move to completion
            currentStep = .complete
            logger.info("Moving to completion step")

        case .complete:
            // At complete step, finishOnboarding should be called instead
            logger.info("Already at completion step")
        }
    }

    func goToPreviousStep() {
        if let prevStep = WelcomeStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }

    // MARK: - Login Item Setting

    func updateStartAtLogin(_ enabled: Bool) {
        // The computed property will automatically update UserDefaults
        startAtLogin = enabled
        // Update the system login item setting
        loginItemManager.setStartAtLogin(enabled: enabled)
        logger.info("Updated startAtLogin setting to: \(enabled)")
    }

    // MARK: - Completion

    func finishOnboarding() {
        // Mark onboarding as complete and reset first launch flag
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.isFirstLaunch] = false

        logger.info("Onboarding completed, hasCompletedOnboarding set to true, isFirstLaunch set to false")

        // Trigger the delegate's completion callback
        onCompletionCallback?()

        // Post a notification to highlight the menu bar icon
        // This helps users find the app in the menu bar after completing onboarding
        NotificationCenter.default.post(name: .highlightMenuBarIcon, object: nil)
    }
}

// MARK: - Welcome Step Enum

enum WelcomeStep: Int, CaseIterable, CustomStringConvertible {
    case welcome = 0
    case settings = 1
    case complete = 2

    var description: String {
        switch self {
        case .welcome:
            "Welcome"
        case .settings:
            "Settings"
        case .complete:
            "Complete"
        }
    }
}
