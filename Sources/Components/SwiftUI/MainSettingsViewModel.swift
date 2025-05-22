import Combine
import Defaults
import Foundation
import Observation
import OSLog
import SwiftUI

/// ViewModel for the Settings view - simplified for CodeLooper
@MainActor
@Observable
public final class MainSettingsViewModel: ObservableObject {
    // MARK: - Properties

    // Logger instance
    private let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "MainSettingsViewModel")

    // Dependencies
    private let loginItemManager: LoginItemManager
    let mcpConfigManager = MCPConfigManager.shared // Made public for access from previews if needed, but primarily internal

    // @Observable handles publishing for these, so @Published / @State are removed.
    private(set) var startAtLogin: Bool = Defaults[.startAtLogin]
    private(set) var showInMenuBar: Bool = Defaults[.showInMenuBar]
    private(set) var showWelcomeScreen: Bool = Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen]
    private(set) var showCopyCounter: Bool = Defaults[.showCopyCounter]
    private(set) var showPasteCounter: Bool = Defaults[.showPasteCounter]
    private(set) var showTotalInterventions: Bool = Defaults[.showTotalInterventions]
    var isGlobalMonitoringEnabled: Bool = Defaults[.isGlobalMonitoringEnabled]
    var playSoundOnIntervention: Bool = Defaults[.playSoundOnIntervention]
    var flashIconOnIntervention: Bool = Defaults[.flashIconOnIntervention]

    // Global Shortcut
    // Removed: var globalShortcutString: String = ""

    // Computed property for showDebugMenu
    var showDebugMenu: Bool {
        get { Defaults[.showDebugMenu] }
        set { Defaults[.showDebugMenu] = newValue }
    }

    // Published properties for MCP status messages - @Observable handles publishing
    var claudeCodeStatusMessage: String = "Loading..."
    var macOSAutomatorStatusMessage: String = "Loading..."
    var xcodeBuildStatusMessage: String = "Loading..."

    // Sheet presentation state - @Observable handles publishing
    var showingClaudeConfigSheet = false
    var showingXcodeConfigSheet = false
    var showingAutomatorConfigSheet = false

    // Properties to hold MCP configuration values, to be bound to config views
    var claudeCodeCustomCliName: String = ""
    var xcodeBuildVersionString: String = ""
    var xcodeBuildIncrementalBuilds: Bool = false
    var xcodeBuildSentryDisabled: Bool = false

    // Rule Set Properties - @Observable handles changes
    var projectDisplayName: String = "Selected Project"
    var ruleSetStatusMessage: String = "Verify or Install Rule Set"
    var selectedProjectURL: URL? = nil
    var currentRuleSetStatus: MCPConfigManager.RuleSetStatus = .notInstalled

    // Status for individual MCPs (raw boolean enabled/disabled)
    // These are now computed properties based on mcpConfigManager
    // The stored properties for these were removed in a previous step, this is a getter/setter structure
    var isClaudeCodeEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "claude-code", nameForEntry: "Claude Code", enabled: newValue, defaultCommand: ["claude-code"])
            refreshMCPStatusMessage(for: "claude-code")
        }
    }
    var isMacOSAutomatorEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "macos-automator").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "macos-automator", nameForEntry: "macOS Automator", enabled: newValue, defaultCommand: ["macos-automator"])
            refreshMCPStatusMessage(for: "macos-automator")
        }
    }
    var isXcodeBuildEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "XcodeBuildMCP", nameForEntry: "XcodeBuildMCP", enabled: newValue, defaultCommand: ["XcodeBuildMCP"])
            refreshMCPStatusMessage(for: "XcodeBuildMCP")
        }
    }

    // MARK: - Initialization

    /// Initialize with required services
    public init(loginItemManager: LoginItemManager) {
        self.loginItemManager = loginItemManager
        // Load initial global shortcut string - REMOVED
        // self.globalShortcutString = mcpConfigManager.getGlobalShortcut() ?? ""
        
        // These lines are now redundant as refreshAllMCPStatusMessages handles it.
        // xcodeBuildIncrementalBuilds = mcpConfigManager.getXcodeBuildIncrementalBuildsFlag()
        // xcodeBuildSentryDisabled = mcpConfigManager.getXcodeBuildSentryDisabledFlag()

        // Load initial MCP statuses
        refreshAllMCPStatusMessages()

        logger.info("MainSettingsViewModel initialized and MCP statuses refreshed.") // Updated log message
    }

    // MARK: - Settings Management

    /// Update start at login setting
    public func updateStartAtLogin(_ enabled: Bool) {
        // Log the current state before attempting to change
        logger.info("Updating startAtLogin setting from \(self.startAtLogin) to \(enabled)")

        // Update our stored property first for UI responsiveness
        startAtLogin = enabled

        // Update the login item status in the system
        let success = loginItemManager.setStartAtLogin(enabled: enabled)

        // Log the result
        if success {
            logger.info("Successfully updated startAtLogin system setting to: \(enabled)")
        } else {
            logger.warning("Failed to update startAtLogin system setting to: \(enabled)")

            // If the system update failed, update property and UserDefaults to reflect actual state
            let actualState = loginItemManager.startsAtLogin()
            startAtLogin = actualState
            logger.info("Corrected startAtLogin to match system: \(actualState)")
        }
    }

    /// Update show in menu bar setting
    public func updateShowInMenuBar(_ enabled: Bool) {
        // Log the current state for debugging
        logger.info("Updating showInMenuBar setting from \(self.showInMenuBar) to \(enabled)")

        // Update stored property for UI responsiveness
        showInMenuBar = enabled

        // Post a notification to inform that menu bar visibility changed
        logger.info("Menu bar visibility changed to: \(enabled)")

        // Use Task with sleep for consistency with Swift concurrency model
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            NotificationCenter.default.post(
                name: .menuBarVisibilityChanged,
                object: nil,
                userInfo: ["visible": enabled]
            )
        }
    }

    /// Update show welcome screen setting
    public func updateShowWelcomeScreen(_ enabled: Bool) {
        // Log the current state before attempting to change
        logger.info("Updating showWelcomeScreen setting from \(self.showWelcomeScreen) to \(enabled)")

        // Update stored property for UI responsiveness
        showWelcomeScreen = enabled

        if enabled {
            // If enabling welcome screen, also reset onboarding flag
            Defaults[.hasCompletedOnboarding] = false

            // Force sync these values to UserDefaults.standard as well for components that read directly
            UserDefaults.standard.set(true, forKey: Defaults.Keys.isFirstLaunch.name)
            UserDefaults.standard.set(false, forKey: Defaults.Keys.hasCompletedOnboarding.name)
            UserDefaults.standard.set(true, forKey: Defaults.Keys.showWelcomeScreen.name)

            logger.info("Set to show welcome screen on next launch (all defaults updated)")

            // Post notification to inform app of this significant change
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        } else {
            // Even when disabling, make sure UserDefaults.standard is in sync
            UserDefaults.standard.set(false, forKey: Defaults.Keys.showWelcomeScreen.name)
            logger.info("Disabled welcome screen for next launch")
        }
    }

    /// Toggle debug menu
    public func toggleDebugMenu() {
        Defaults[.showDebugMenu].toggle()
        NotificationCenter.default.post(name: .highlightMenuBarIcon, object: nil)
    }

    /// Reset settings to defaults
    public func resetToDefaults() async {
        // DefaultsManager.shared is MainActor-isolated
        if DefaultsManager.shared.resetToDefaults() {
            await refreshSettings()
        }
    }

    /// Method to refresh all settings
    public func refreshSettings() async {
        // Update our stored properties from UserDefaults
        self.startAtLogin = Defaults[.startAtLogin]
        self.showInMenuBar = Defaults[.showInMenuBar]
        self.showWelcomeScreen = Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen]

        logger.info("Settings refreshed")
    }

    // MARK: - Status Refresh Logic
    func refreshAllMCPStatusMessages() {
        let claudeStatus = mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code")
        self.claudeCodeStatusMessage = claudeStatus.displayStatus
        // Update other properties if needed from claudeStatus, e.g., for configureClaudeCode prefill
        self.claudeCodeCustomCliName = claudeStatus.customCliName ?? ""

        let automatorStatus = mcpConfigManager.getMCPStatus(mcpIdentifier: "macos-automator")
        self.macOSAutomatorStatusMessage = automatorStatus.displayStatus

        let xcodeStatus = mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP")
        self.xcodeBuildStatusMessage = xcodeStatus.displayStatus
        // Update other properties if needed from xcodeStatus for configureXcodeBuild prefill
        self.xcodeBuildVersionString = xcodeStatus.version ?? ""
        self.xcodeBuildIncrementalBuilds = xcodeStatus.incrementalBuildsEnabled ?? false
        self.xcodeBuildSentryDisabled = xcodeStatus.sentryDisabled ?? false

        logger.info("Refreshed all MCP status messages.")
        logger.info("Claude: \(self.claudeCodeStatusMessage), Automator: \(self.macOSAutomatorStatusMessage), Xcode: \(self.xcodeBuildStatusMessage)")
    }

    func refreshMCPStatusMessage(for mcpIdentifier: String) {
        // Implementation of refreshMCPStatusMessage method
    }
    
    /// Enable a specific MCP by its identifier
    public func enableMCP(_ mcpIdentifier: String) {
        switch mcpIdentifier {
        case "claude-code":
            isClaudeCodeEnabled = true
        case "macos-automator":
            isMacOSAutomatorEnabled = true
        case "XcodeBuildMCP":
            isXcodeBuildEnabled = true
        default:
            logger.warning("Attempted to enable unknown MCP: \(mcpIdentifier)")
        }
        refreshAllMCPStatusMessages()
    }

    // MARK: - Rule Set Management

    public func verifyTerminatorRuleSetStatus(projectURL: URL?) {
        guard let url = projectURL else {
            logger.info("No project URL provided for rule set status verification.")
            self.selectedProjectURL = nil
            self.projectDisplayName = "Selected Project"
            self.currentRuleSetStatus = .notInstalled
            self.ruleSetStatusMessage = "Select a project to verify."
            return
        }
        logger.info("Verifying Terminator Rule Set status for project: \(url.path)")
        let status = mcpConfigManager.verifyTerminatorRuleSet(at: url)
        
        self.selectedProjectURL = url
        self.projectDisplayName = url.lastPathComponent
        self.currentRuleSetStatus = status
        self.ruleSetStatusMessage = status.displayName
        
        logger.info("Rule set status for \(url.lastPathComponent): \(status.displayName)")
    }

    public func installTerminatorRuleSet(forProject projectURL: URL?) {
        let resolvedURL: URL?
        if projectURL == nil {
            resolvedURL = promptForProjectDirectory(title: "Select Project for Terminator Rule Set Installation")
        } else {
            resolvedURL = projectURL
        }

        guard let url = resolvedURL else {
            logger.info("Terminator Rule Set installation cancelled or no directory selected.")
            // Update status to reflect no project is selected if a prompt was cancelled
            if projectURL == nil { // Only if we prompted and got nothing
                self.selectedProjectURL = nil
                self.projectDisplayName = "Selected Project"
                self.currentRuleSetStatus = .notInstalled
                self.ruleSetStatusMessage = "Select a project to install."
            }
            return
        }

        logger.info("Attempting to install Terminator Rule Set to: \(url.path)")
        if mcpConfigManager.installTerminatorRuleSet(to: url) {
            logger.info("Terminator Rule Set installed successfully to \(url.lastPathComponent).")
            AlertPresenter.shared.showInfo(title: "Installation Successful", message: "Terminator Rule Set installed successfully in \(url.lastPathComponent).")
        } else {
            logger.error("Failed to install Terminator Rule Set to \(url.lastPathComponent).")
            AlertPresenter.shared.showAlert(title: "Installation Failed", message: "Could not install Terminator Rule Set in \(url.lastPathComponent). Check application logs for details.", style: .critical)
        }
        // After attempting installation, always re-verify the status for the affected URL.
        verifyTerminatorRuleSetStatus(projectURL: url)
    }

    // Helper to prompt for directory (could be in a utility class too)
    @MainActor // NSOpenPanel must be used on the main actor
    private func promptForProjectDirectory(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = title
        
        // Running modal synchronously is fine here as it's a user-driven action.
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
