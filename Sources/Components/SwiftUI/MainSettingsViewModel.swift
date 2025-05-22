import Defaults
import Foundation
import Observation
import OSLog
import SwiftUI

/// ViewModel for the Settings view - simplified for CodeLooper
@MainActor
@Observable
public final class MainSettingsViewModel {
    // MARK: - Properties

    // Logger instance
    private let logger = Logger(subsystem: "ai.amantusmachina.codelooper", category: "MainSettingsViewModel")

    // Dependencies
    private let loginItemManager: LoginItemManager
    let mcpConfigManager = MCPConfigManager.shared // Made public for access from previews if needed, but primarily internal

    // Using stored properties instead of computed properties to ensure SwiftUI observes changes
    private(set) var startAtLogin: Bool = Defaults[.startAtLogin]
    private(set) var showInMenuBar: Bool = Defaults[.showInMenuBar]
    private(set) var showWelcomeScreen: Bool = Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen]

    // Global Shortcut
    @State var globalShortcutString: String = ""

    // Published properties for MCP status messages
    @Published var claudeCodeStatusMessage: String = "Loading..."
    @Published var macOSAutomatorStatusMessage: String = "Loading..."
    @Published var xcodeBuildStatusMessage: String = "Loading..."

    // Explicit setter methods that update both the stored property and UserDefaults
    func setStartAtLogin(_ newValue: Bool) {
        startAtLogin = newValue
        Defaults[.startAtLogin] = newValue
    }

    func setShowInMenuBar(_ newValue: Bool) {
        showInMenuBar = newValue
        Defaults[.showInMenuBar] = newValue
    }

    func setShowWelcomeScreen(_ newValue: Bool) {
        showWelcomeScreen = newValue
        if newValue {
            Defaults[.isFirstLaunch] = true
            Defaults[.showWelcomeScreen] = true
        } else {
            // When toggled off, only update showWelcomeScreen, keep isFirstLaunch
            Defaults[.showWelcomeScreen] = false
        }
    }

    var showDebugMenu: Bool {
        get { Defaults[.showDebugMenu] }
        set { Defaults[.showDebugMenu] = newValue }
    }

    // MARK: - MCP and Rule Set Properties and Methods

    // Sheet presentation state
    @State var showingClaudeConfigSheet = false
    @State var showingXcodeConfigSheet = false
    @State var showingAutomatorConfigSheet = false

    // Properties to hold MCP configuration values, to be bound to config views
    // These should be initialized from mcpConfigManager on ViewModel init or view appear
    var claudeCodeCustomCliName: String = ""
    var xcodeBuildVersionString: String = ""
    var xcodeBuildIncrementalBuilds: Bool = false
    var xcodeBuildSentryDisabled: Bool = false

    var isClaudeCodeEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "claude-code", nameForEntry: "Claude Code Agent", enabled: newValue, defaultCommand: ["claude-code"])
            refreshAllMCPStatusMessages() // Refresh status after changing enabled state
        }
    }
    var isMacOSAutomatorEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "macos-automator").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "macos-automator", nameForEntry: "macOS Automator", enabled: newValue) 
            refreshAllMCPStatusMessages()
        }
    }
    var isXcodeBuildEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP").enabled }
        set { 
            mcpConfigManager.setMCPEnabled(mcpIdentifier: "XcodeBuildMCP", nameForEntry: "Xcode Build Service", enabled: newValue, defaultCommand: ["xcodebuildmcp"]) 
            refreshAllMCPStatusMessages()
        }
    }

    func configureClaudeCode() {
        logger.info("Configure Claude Code MCP clicked")
        let status = mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code")
        self.claudeCodeCustomCliName = status.customCliName ?? ""
        showingClaudeConfigSheet = true
    }

    func configureMacOSAutomator() {
        logger.info("Configure macOS Automator MCP clicked")
        showingAutomatorConfigSheet = true
    }

    func configureXcodeBuild() {
        logger.info("Configure XcodeBuild MCP clicked")
        let status = mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP")
        self.xcodeBuildVersionString = status.version ?? ""
        self.xcodeBuildIncrementalBuilds = status.incrementalBuildsEnabled ?? false
        self.xcodeBuildSentryDisabled = status.sentryDisabled ?? false
        showingXcodeConfigSheet = true
    }

    func saveClaudeCodeConfiguration(newCliName: String) {
        logger.info("Saving Claude Code custom CLI name: \(newCliName)")
        if mcpConfigManager.updateMCPConfiguration(mcpIdentifier: "claude-code", params: ["customCliName": newCliName]) {
            AlertPresenter.shared.showInfo(title: "Configuration Saved", message: "Claude Code CLI name updated.")
        } else {
            AlertPresenter.shared.showAlert(title: "Save Failed", message: "Could not save Claude Code configuration. Check logs.", style: .critical)
        }
        // Optionally, refresh related status messages if they depend on the CLI name
        refreshAllMCPStatusMessages()
    }

    func saveXcodeBuildConfiguration(version: String, incrementalBuilds: Bool, sentryDisabled: Bool) {
        logger.info("Saving XcodeBuild MCP configuration: Version=\(version), Incremental=\(incrementalBuilds), SentryDisabled=\(sentryDisabled)")
        var params: [String: Any] = ["version": version]
        params["incrementalBuildsEnabled"] = incrementalBuilds
        params["sentryDisabled"] = sentryDisabled
        
        if mcpConfigManager.updateMCPConfiguration(mcpIdentifier: "XcodeBuildMCP", params: params) {
            AlertPresenter.shared.showInfo(title: "Configuration Saved", message: "XcodeBuild MCP settings updated.")
        } else {
            AlertPresenter.shared.showAlert(title: "Save Failed", message: "Could not save XcodeBuild MCP configuration. Check logs.", style: .critical)
        }
        // Optionally, refresh related status messages
        refreshAllMCPStatusMessages()
    }

    func saveGlobalShortcut() {
        logger.info("Saving global shortcut: \(self.globalShortcutString)")
        if mcpConfigManager.setGlobalShortcut(self.globalShortcutString.isEmpty ? nil : self.globalShortcutString) {
            AlertPresenter.shared.showInfo(title: "Shortcut Saved", message: "Global MCP shortcut updated.")
        } else {
            AlertPresenter.shared.showAlert(title: "Save Failed", message: "Could not save global MCP shortcut. Check logs.", style: .critical)
        }
        // Potentially notify other parts of the app if the shortcut changes and is actively used.
    }

    func installTerminatorRuleSet(forProject projectURL: URL? = nil) {
        logger.info("Install/Update Terminator Rule Set called. Project URL: \(projectURL?.path ?? "Not specified, will prompt")")
        Task {
            var targetURL: URL?

            if let providedURL = projectURL {
                targetURL = providedURL
            } else {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.message = "Select the root directory of your project to install/update the Terminator Rule Set."

                if await panel.runModal() == .OK {
                    targetURL = panel.url
                } else {
                    logger.info("Project selection cancelled by user.")
                    // Post notification or update state if needed to inform UI about cancellation
                    return // Exit if user cancelled panel and no URL was provided
                }
            }

            guard let finalURL = targetURL else {
                logger.warning("No project directory selected or provided for rule set installation.")
                // Update UI or show alert if no URL could be determined
                return
            }
            
            logger.info("Proceeding with rule set installation/update for: \(finalURL.path)")
            if mcpConfigManager.installTerminatorRuleSet(to: finalURL) {
                AlertPresenter.shared.showInfo(title: "Rule Set Processed", message: "The Terminator Rule Set was successfully processed for \(finalURL.lastPathComponent).")
                // Notify the CursorRuleSetsSettingsTab to re-verify and update its status display
                // This could be done via a Notification or by having the tab observe a property that changes.
                // For now, manual re-verification by the user is implied after this alert.
            } else {
                AlertPresenter.shared.showAlert(title: "Operation Failed", message: "Could not install/update the Terminator Rule Set for \(finalURL.lastPathComponent). Check logs for details.", style: .critical)
            }
        }
    }

    func verifyTerminatorRuleSetStatus(projectURL: URL) -> MCPConfigManager.RuleSetStatus {
        logger.info("Verifying Terminator Rule Set status for project: \(projectURL.path)")
        let status = mcpConfigManager.verifyTerminatorRuleSet(at: projectURL)
        // No need to update UI here, the caller (CursorRuleSetsSettingsTab) will use the status directly.
        return status
    }

    // MARK: - MCP File Operations (Spec 7.A.3)
    func viewMCPFile() {
        let path = mcpConfigManager.getMCPFilePath()
        NSWorkspace.shared.open(path)
        logger.info("Attempting to open mcp.json at: \(path.path)")
    }

    func clearMCPFile() {
        if mcpConfigManager.clearMCPFile() {
            // Refresh UI state that depends on mcp.json
            // This includes MCP enabled states and global shortcut
            self.isClaudeCodeEnabled = mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code").enabled
            self.isMacOSAutomatorEnabled = mcpConfigManager.getMCPStatus(mcpIdentifier: "macos-automator").enabled
            self.isXcodeBuildEnabled = mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP").enabled
            self.claudeCodeCustomCliName = mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code").customCliName ?? ""
            self.xcodeBuildVersionString = mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP").version ?? ""
            self.xcodeBuildIncrementalBuilds = mcpConfigManager.getXcodeBuildIncrementalBuildsFlag()
            self.xcodeBuildSentryDisabled = mcpConfigManager.getXcodeBuildSentryDisabledFlag()
            self.globalShortcutString = mcpConfigManager.getGlobalShortcut() ?? ""
            
            AlertPresenter.shared.showInfo(title: "MCP File Cleared", message: "~/.cursor/mcp.json has been reset to its default empty state.")
            logger.info("mcp.json cleared successfully and UI state refreshed.")
        } else {
            AlertPresenter.shared.showAlert(title: "Error Clearing MCP File", message: "Could not clear ~/.cursor/mcp.json. Check logs for details.", style: .critical)
            logger.error("Failed to clear mcp.json.")
        }
    }

    // MARK: - Initialization

    /// Initialize with required services
    public init(loginItemManager: LoginItemManager) {
        self.loginItemManager = loginItemManager
        // Load initial global shortcut string
        self.globalShortcutString = mcpConfigManager.getGlobalShortcut() ?? ""
        
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
        // No need to explicitly set Defaults since showDebugMenu is a computed property
        // that will handle the UserDefaults update
        showDebugMenu.toggle()
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
        setStartAtLogin(Defaults[.startAtLogin])
        setShowInMenuBar(Defaults[.showInMenuBar])
        setShowWelcomeScreen(Defaults[.isFirstLaunch] || Defaults[.showWelcomeScreen])

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
}
