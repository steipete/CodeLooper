import Defaults
import Diagnostics
import Observation
import OSLog
import SwiftUI

// MARK: - Welcome View Model

@MainActor
@Observable
final class WelcomeViewModel: ObservableObject {
    // MARK: Lifecycle

    init(loginItemManager: LoginItemManager, windowManager: WindowManager? = nil, onCompletion: (() -> Void)? = nil) {
        self.loginItemManager = loginItemManager
        self.windowManager = windowManager
        onCompletionCallback = onCompletion

        logger.info("WelcomeViewModel initialized for CodeLooper")
    }

    // MARK: Internal

    var currentStep: WelcomeStep = .welcome

    // Computed property for startAtLogin
    var startAtLogin: Bool {
        get { Defaults[.startAtLogin] }
        set { Defaults[.startAtLogin] = newValue }
    }

    // MARK: - Navigation

    func goToNextStep() {
        logger.info("Attempting to move from step: \(String(describing: self.currentStep)) to next step")

        // Special cases based on current step
        switch currentStep {
        case .welcome:
            // From welcome, go to accessibility step
            currentStep = .accessibility
            logger.info("Moving to accessibility step")

        case .accessibility:
            // From accessibility, go to settings step
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
        switch currentStep {
        case .welcome:
            // Already at first step
            logger.info("Already at welcome step")
        case .accessibility:
            currentStep = .welcome
            logger.info("Moving back to welcome step")
        case .settings:
            currentStep = .accessibility
            logger.info("Moving back to accessibility step")
        case .complete:
            currentStep = .settings
            logger.info("Moving back to settings step")
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

    // MARK: - Accessibility Handling

    func handleOpenAccessibilitySettingsAndPrompt() {
        logger.info("Handling open accessibility settings and prompt.")
        // First, try to trigger the system prompt via the provided WindowManager
        windowManager?.checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: true)

        // Then, open the system settings pane as before
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            logger.info("Opened System Settings to Accessibility pane.")
        } else {
            logger.error("Could not create URL for Accessibility settings.")
        }
    }

    // MARK: - Completion

    func finishOnboarding() {
        // Mark onboarding as complete and reset first launch flag
        Defaults[.hasCompletedOnboarding] = true
        Defaults[.isFirstLaunch] = false
        Defaults[.hasShownWelcomeGuide] = true

        logger
            .info(
                "Onboarding completed, hasCompletedOnboarding set to true, isFirstLaunch set to false, hasShownWelcomeGuide set to true"
            )

        // Trigger the delegate's completion callback
        onCompletionCallback?()

        // Post a notification to highlight the menu bar icon
        // This helps users find the app in the menu bar after completing onboarding
        NotificationCenter.default.post(name: .highlightMenuBarIcon, object: nil)
    }

    // MARK: Private

    private let logger = Logger(category: .onboarding)

    private var loginItemManager: LoginItemManager
    private var windowManager: WindowManager?
    private var onCompletionCallback: (() -> Void)?
}

// MARK: - Welcome Step Enum

enum WelcomeStep: Int, CaseIterable, CustomStringConvertible {
    case welcome = 0
    case accessibility = 1
    case settings = 2
    case complete = 3

    // MARK: Internal

    var description: String {
        switch self {
        case .welcome:
            "Welcome"
        case .accessibility:
            "Accessibility"
        case .settings:
            "Settings"
        case .complete:
            "Complete"
        }
    }
}
