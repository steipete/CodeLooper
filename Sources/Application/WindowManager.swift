import AppKit
import AXorcistLib
import Combine
import Defaults
import Foundation
import os
import SwiftUI
import ApplicationServices

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
            let welcomeViewModel = WelcomeViewModel(
                loginItemManager: loginItemManager, 
                windowManager: self
            ) { [weak self] in
                self?.welcomeWindowController?.close()
                self?.welcomeWindowController = nil
                self?.logger.info("Welcome onboarding flow finished.")
                self?.delegate?.windowManagerDidFinishOnboarding()
            }
            let welcomeView = WelcomeView(viewModel: welcomeViewModel) // Assuming WelcomeView is accessible
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
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
            // First, try without prompting to see current status
            try AXorcistLib.checkAccessibilityPermissions(isDebugLoggingEnabled: false, currentDebugLogs: &debugLogs)
            permissionsGranted = true
            logger.info("Accessibility permissions already granted.")
            Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted.") }
        } catch let error as AccessibilityError {
            if case .notAuthorized = error, showPromptIfNeeded {
                logger.warning("Accessibility permissions not granted. Will attempt to trigger system prompt. Error: \(error.localizedDescription)")
                Task { await sessionLogger.log(level: .warning, message: "Accessibility permissions not granted, triggering system prompt. Error: \(error.localizedDescription)") }
                
                // **KEY FIX**: Make an actual accessibility API call to trigger the system prompt
                // This will cause macOS to show the authorization dialog and add CodeLooper to the accessibility list
                Task { @MainActor in
                    await triggerAccessibilityPrompt()
                }
                
                // Also open the System Settings as a fallback
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
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
    
    /// Triggers the accessibility prompt by making an actual accessibility API call
    @MainActor
    private func triggerAccessibilityPrompt() async {
        logger.info("Triggering accessibility prompt by making AX API call...")
        
        // Method 1: Use AXIsProcessTrustedWithOptions with prompt option
        // This is the standard way to trigger the accessibility permission prompt
        // Using the same approach as AXorcist's AccessibilityPermissions.swift
        let kAXTrustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"
        let options = [kAXTrustedCheckOptionPromptKey: true] as CFDictionary
        let isGranted = AXIsProcessTrustedWithOptions(options)
        
        if isGranted {
            logger.info("Accessibility permissions granted after prompt trigger.")
            Task { await sessionLogger.log(level: .info, message: "Accessibility permissions granted after prompt trigger.") }
        } else {
            logger.info("Accessibility prompt displayed. User needs to manually grant permissions.")
            Task { await sessionLogger.log(level: .info, message: "Accessibility prompt displayed. User needs to manually grant permissions.") }
        }
        
        // Method 2: As a backup, try to create a system-wide AX element to ensure the prompt is triggered
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let _ = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        // This call will fail if permissions aren't granted, but it ensures the app appears in the accessibility list
        
        logger.info("Accessibility API calls completed to trigger system prompt.")
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