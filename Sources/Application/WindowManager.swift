import AppKit
import AXorcistLib
import Combine
import Defaults
import Foundation
import os
import SwiftUI

@MainActor
protocol WindowManagerDelegate: AnyObject {
    func windowManagerDidFinishOnboarding()
    func windowManagerRequestsAccessibilityPermissions(showPromptIfNeeded: Bool)
    // Add other delegate methods if AppDelegate needs to be called back for other reasons
}

@MainActor
class WindowManager {
    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper", category: "WindowManager")

    // MARK: - Properties
    private var aboutWindowController: NSWindowController?
    var welcomeWindowController: NSWindowController? // Made public for AppDelegate access if needed

    // Dependencies
    private let loginItemManager: LoginItemManager
    private let sessionLogger: SessionLogger
    weak var delegate: WindowManagerDelegate?

    // MARK: - Initialization
    init(loginItemManager: LoginItemManager, sessionLogger: SessionLogger, delegate: WindowManagerDelegate?) {
        self.loginItemManager = loginItemManager
        self.sessionLogger = sessionLogger
        self.delegate = delegate
        logger.info("WindowManager initialized.")
    }

    // MARK: - Window Management
    @objc func showAboutWindow() {
        logger.info("Showing About Window.")
        if aboutWindowController == nil {
            let aboutView = AboutView() // Assuming AboutView is accessible
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "About CodeLooper"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: aboutView)
            aboutWindowController = NSWindowController(window: window)
        }
        aboutWindowController?.showWindow(nil) // Pass nil for sender
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showWelcomeWindow() {
        logger.info("Showing Welcome Window.")
        if welcomeWindowController == nil {
            let welcomeViewModel = WelcomeViewModel(loginItemManager: loginItemManager) { [weak self] in
                self?.welcomeWindowController?.close()
                self?.welcomeWindowController = nil
                self?.logger.info("Welcome onboarding flow finished.")
                self?.delegate?.windowManagerDidFinishOnboarding()
            }
            let welcomeView = WelcomeView(viewModel: welcomeViewModel) // Assuming WelcomeView is accessible
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Welcome to CodeLooper"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: welcomeView)
            welcomeWindowController = NSWindowController(window: window)
        }
        welcomeWindowController?.showWindow(nil) // Pass nil for sender
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    /// Checks accessibility permissions and prompts the user if needed.
    func checkAndPromptForAccessibilityPermissions(showPromptIfNeeded: Bool = true) {
        logger.info("Checking accessibility permissions (via WindowManager).")
        var debugLogs: [String] = []
        var permissionsGranted = false
        do {
            try AXorcistLib.checkAccessibilityPermissions(isDebugLoggingEnabled: false, currentDebugLogs: &debugLogs)
            permissionsGranted = true
            logger.info("Accessibility permissions already granted.")
            Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted.") }
        } catch let error as AccessibilityError {
            if case .notAuthorized = error, showPromptIfNeeded {
                logger.warning("Accessibility permissions not granted. Will attempt to prompt. Error: \(error.localizedDescription)")
                Task { await sessionLogger.log(level: .warning, message: "Accessibility permissions not granted, prompting. Error: \(error.localizedDescription)") }
                debugLogs.removeAll()
                
                do {
                    try AXorcistLib.checkAccessibilityPermissions(isDebugLoggingEnabled: false, currentDebugLogs: &debugLogs)
                    permissionsGranted = true
                    logger.info("Accessibility permissions granted after prompt (or were already granted).")
                    Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted after prompt.") }
                } catch let promptError {
                    logger.error("Failed to obtain accessibility permissions after prompt: \(promptError.localizedDescription)")
                    Task { await sessionLogger.log(level: .error, message: "Failed to obtain accessibility permissions after prompt: \(promptError.localizedDescription)") }
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                logger.error("Error checking accessibility permissions: \(error.localizedDescription)")
                Task { await sessionLogger.log(level: .error, message: "Error checking accessibility permissions: \(error.localizedDescription)") }
                if showPromptIfNeeded {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } catch {
            logger.error("An unexpected error occurred while checking accessibility permissions: \(error.localizedDescription)")
            Task { await sessionLogger.log(level: .error, message: "Unexpected error checking accessibility permissions: \(error.localizedDescription)") }
            if showPromptIfNeeded {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        if permissionsGranted {
            // Delegate can decide if any specific action is needed upon confirmation
        }
    }

    func handleFirstLaunchOrWelcomeScreen() {
        logger.info("Checking if welcome guide should be shown (via WindowManager).")
        if !Defaults[.hasShownWelcomeGuide] {
            logger.info("Welcome guide has not been shown. Displaying now.")
            showWelcomeWindow()
        } else {
            logger.info("Welcome guide already shown. Checking accessibility permissions.")
            delegate?.windowManagerRequestsAccessibilityPermissions(showPromptIfNeeded: true)
        }
    }
} 