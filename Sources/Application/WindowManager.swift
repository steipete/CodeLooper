import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
import SwiftUI
import AXpector

@MainActor
protocol WindowManagerDelegate: AnyObject {
    func windowManagerDidFinishOnboarding()
    // Removed windowManagerRequestsAccessibilityPermissions as WindowManager handles it directly now
}

@MainActor
class WindowManager: ObservableObject {
    // Standardized logger
    private let logger = Logger(category: .app) // From Diagnostics module
    private let sessionLogger: SessionLogger // Injected

    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var axpectorWindowController: NSWindowController? // For AXpector
    var mainSettingsCoordinator: MainSettingsCoordinator? // Keep if used by other parts

    // Debouncer for window resize events (if still needed, otherwise remove)
    private var resizeDebouncer = Debouncer(delay: 0.5)

    // Store observation tokens
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Properties
    private var aboutWindowController: NSWindowController?
    var welcomeWindowController: NSWindowController?

    // Dependencies
    private let loginItemManager: LoginItemManager
    weak var delegate: WindowManagerDelegate? // Added delegate property

    // MARK: - Initialization
    init(loginItemManager: LoginItemManager, sessionLogger: SessionLogger, delegate: WindowManagerDelegate?) {
        self.loginItemManager = loginItemManager
        self.sessionLogger = sessionLogger // Initialize injected sessionLogger
        self.delegate = delegate         // Initialize injected delegate
        
        logger.info("WindowManager initialized.")
        setupDebugMenuObserver()
        // Initial check for accessibility - DO NOT PROMPT HERE.
        // Prompting should only happen on user action from Welcome/Settings.
        checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: false)
    }

    private func setupDebugMenuObserver() {
        Defaults.publisher(.showDebugMenu) // Get a publisher for the specific key
            .sink { [weak self] change in // change is of type Defaults.KeyChange<Bool>
                guard let self = self else { return }
                // Access change.newValue directly as it's not a generic publisher change
                self.logger.info("showDebugMenu changed to: \(change.newValue). Updating menu bar.")
                NotificationCenter.default.post(name: .updateMenuBarExtras, object: nil)
            }
            .store(in: &cancellables)
    }

    // MARK: - Window Management
    @objc func showAboutWindow() {
        logger.info("Showing About Window.")
        if aboutWindowController == nil {
            let aboutView = AboutView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "About CodeLooper"
            window.isReleasedWhenClosed = false // Important for NSWindowController
            window.contentView = NSHostingView(rootView: aboutView)
            aboutWindowController = NSWindowController(window: window)
        }
        aboutWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showWelcomeWindow() {
        logger.info("Showing Welcome Window.")
        if welcomeWindowController == nil {
            let welcomeViewModel = WelcomeViewModel(
                loginItemManager: loginItemManager,
                windowManager: self // Pass self if WelcomeViewModel needs it
            ) { [weak self] in // Completion handler
                self?.welcomeWindowController?.close()
                self?.welcomeWindowController = nil // Release the controller
                self?.logger.info("Welcome onboarding flow finished.")
                self?.delegate?.windowManagerDidFinishOnboarding() // Call delegate
            }
            let welcomeView = WelcomeView(viewModel: welcomeViewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Welcome to CodeLooper"
            window.isReleasedWhenClosed = false // Important for NSWindowController
            window.contentView = NSHostingView(rootView: welcomeView)
            welcomeWindowController = NSWindowController(window: window)
        }
        welcomeWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    @objc func showAXpectorWindow() {
        logger.info("Showing AXpector Window.")
        if axpectorWindowController == nil {
            // Assuming AXpectorView is the main view from the AXpector module
            let axpectorView = AXpectorView() 
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), // Adjust size as needed
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "AXpector - Accessibility Inspector"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: axpectorView)
            axpectorWindowController = NSWindowController(window: window)
        }
        axpectorWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        axpectorWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Accessibility (Consolidated)

    /// Checks accessibility permissions and prompts the user if needed.
    func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) {
        logger.info("Checking accessibility permissions...")
        
        do {
            // Use the global AXorcist function, passing down the promptIfNeeded parameter
            try checkAccessibilityPermissions(promptIfNeeded: showPromptIfNeeded)
            logger.info("Accessibility permissions already granted.")
            sessionLogger.log(level: .info, message: "Accessibility permissions granted.")
        } catch let error as AccessibilityError {
            if case .notAuthorized = error, showPromptIfNeeded {
                logger.warning("Accessibility permissions not granted. System prompt should have been triggered by AXorcist.Error: \(error.localizedDescription)")
                sessionLogger.log(level: .warning, message: "Accessibility permissions not granted, system prompt should have occurred. Error: \(error.localizedDescription)")
                
                // The prompt is handled by AXorcist.checkAccessibilityPermissions when promptIfNeeded is true.
                // We just open settings as a fallback or for user to confirm.
                openAccessibilitySystemSettings()
            } else {
                logger.error("Error checking accessibility permissions: \(error.localizedDescription)")
                sessionLogger.log(level: .error, message: "Error checking accessibility permissions: \(error.localizedDescription)")
                if showPromptIfNeeded {
                    showAlert(title: "Accessibility Permissions Error", message: "CodeLooper encountered an error: \(error.localizedDescription). Please check System Settings.", style: .critical)
                    openAccessibilitySystemSettings()
                }
            }
        } catch { // Catch any other unexpected errors
            logger.error("An unexpected error occurred while checking accessibility permissions: \(error.localizedDescription)")
            sessionLogger.log(level: .error, message: "Unexpected error checking accessibility permissions: \(error.localizedDescription)")
            if showPromptIfNeeded {
                showAlert(title: "Accessibility Check Failed", message: "An unexpected error occurred: \(error.localizedDescription). Please check System Settings.", style: .critical)
                openAccessibilitySystemSettings()
            }
        }
    }

    private func openAccessibilitySystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Alert Helper
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        AlertPresenter.shared.showAlert(title: title, message: message, style: style)
    }

    // MARK: - Public Interface for UI Actions

    /// Called when the user explicitly clicks a "Grant Permissions" button.
    public func userInitiatedAccessibilityPrompt() {
        logger.info("User initiated accessibility prompt.")
        checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: true)
    }

    // MARK: - First Launch Logic
    func handleFirstLaunchOrWelcomeScreen() {
        logger.info("Checking if welcome guide should be shown.")
        if !Defaults[.hasShownWelcomeGuide] {
            logger.info("Welcome guide has not been shown. Displaying now.")
            showWelcomeWindow()
            // Do not prompt for accessibility here. The WelcomeView should have a button that calls userInitiatedAccessibilityPrompt.
        } else {
            logger.info("Welcome guide already shown. Ensuring accessibility permissions are checked (silently).")
            // This silent check is fine to update internal state or log.
            checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: false)
        }
    }
    
    // Remove the old checkAndHandleAccessibilityPermissions and ensureAccessibilityWithPrompt methods
    // as their logic is now consolidated into checkAndPromptForAccessibilityPermissions.
} 
