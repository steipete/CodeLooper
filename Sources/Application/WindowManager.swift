import AppKit
import ApplicationServices
import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
import SwiftUI
import AXpector
import DesignSystem

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
        logger.info("Window Manager: Request to show AXpector window.")

        // We can rely on AXpectorView to handle the UI for missing permissions.
        // A silent check here is fine for initial logging or if AXpectorView needs it directly.
        let isTrusted = AXTrustUtil.checkAccessibilityPermissions(promptIfNeeded: false)
        logger.info("Silent accessibility check before showing AXpector: trusted = \(isTrusted)")

        // AXpectorView has its own UI to handle missing permissions and guide the user
        // to grant them, which should then trigger the system prompt via its own logic
        // or by calling a method like userInitiatedAccessibilityPrompt() on this WindowManager.

        // Proceed to show AXpector window regardless. 
        // AXpectorView has its own UI to handle missing permissions.
        if axpectorWindowController == nil {
            logger.info("Creating new AXpector window.")
            // Assuming AXpectorView is the main view from the AXpector module
            let axpectorView = AXpectorView().withDesignSystem() 
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
        logger.info("Before axpectorWindowController.showWindow(nil)")
        axpectorWindowController?.showWindow(nil)
        logger.info("After axpectorWindowController.showWindow(nil)")
        if let window = axpectorWindowController?.window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            logger.info("After axpectorWindowController.window.makeKeyAndOrderFront(nil)")
        } else {
            logger.error("AXpector window is nil after trying to show.")
        }
    }

    // MARK: - Accessibility (Consolidated)

    /// Checks accessibility permissions and prompts the user if needed.
    func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) {
        logger.info("Checking accessibility permissions...")
        
        // AXTrustUtil.checkAccessibilityPermissions returns Bool, doesn't throw
        let permissionsGranted = AXTrustUtil.checkAccessibilityPermissions(promptIfNeeded: showPromptIfNeeded)

        if permissionsGranted {
            logger.info("Accessibility permissions already granted.")
            sessionLogger.log(level: .info, message: "Accessibility permissions granted.")
        } else {
            // Permissions are not granted.
            // If promptIfNeeded was true, AXTrustUtil.checkAccessibilityPermissions should have triggered the system prompt.
            logger.warning("Accessibility permissions not granted. If prompt was requested, system prompt should have occurred.")
            sessionLogger.log(level: .warning, message: "Accessibility permissions not granted. System prompt may have occurred if requested.")
            
            // If we were supposed to prompt, and they are still not granted, 
            // it might be good to guide the user to settings, as the system prompt might have been missed or denied.
            if showPromptIfNeeded {
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
    // private func showAlert(title: String, message: String, style: NSAlert.Style) { // Method appears unused
    //     AlertPresenter.shared.showAlert(title: title, message: message, style: style)
    // }

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
