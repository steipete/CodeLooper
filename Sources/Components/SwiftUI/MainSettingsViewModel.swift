import Combine
import Defaults
import Diagnostics
import Foundation
import Observation
import OSLog
import SwiftUI

/// ViewModel for the Settings view - simplified for CodeLooper
@MainActor
@Observable
public final class MainSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Initialize with required services
    public init(loginItemManager: LoginItemManager, updaterViewModel: UpdaterViewModel) {
        self.loginItemManager = loginItemManager
        self.updaterViewModel = updaterViewModel

        // Load initial MCP statuses
        refreshAllMCPStatusMessages()

        logger.info("MainSettingsViewModel initialized")

        // Load Defaults safely after initialization
        Task { @MainActor in
            await self.refreshSettings()
        }
    }

    // MARK: Public

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
        self.showCopyCounter = Defaults[.showCopyCounter]
        self.showPasteCounter = Defaults[.showPasteCounter]
        self.showTotalInterventions = Defaults[.showTotalInterventions]
        self.isGlobalMonitoringEnabled = Defaults[.isGlobalMonitoringEnabled]
        self.playSoundOnIntervention = Defaults[.playSoundOnIntervention]
        self.flashIconOnIntervention = Defaults[.flashIconOnIntervention]

        logger.info("Settings refreshed")
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

    // MARK: Internal

    // Selected Tab for the TabView
    var selectedTab: SettingsTab = .general

    let mcpConfigManager = MCPConfigManager
        .shared // Made public for access from previews if needed, but primarily internal
    let updaterViewModel: UpdaterViewModel // Modified: Changed to internal (default access level)
    private(set) var startAtLogin: Bool = false // Don't read Defaults during init
    private(set) var showInMenuBar: Bool = true // Safe default
    private(set) var showWelcomeScreen: Bool = false // Safe default
    private(set) var showCopyCounter: Bool = false // Safe default
    private(set) var showPasteCounter: Bool = false // Safe default
    private(set) var showTotalInterventions: Bool = true // Safe default
    var isGlobalMonitoringEnabled: Bool = true // Safe default
    var playSoundOnIntervention: Bool = true // Safe default
    var flashIconOnIntervention: Bool = true // Safe default

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

    var defaultsObservations = Set<AnyCancellable>()

    // Global Shortcut

    // Computed property for showDebugMenu
    var showDebugMenu: Bool {
        get { Defaults[.showDebugMenu] }
        set { Defaults[.showDebugMenu] = newValue }
    }

    // Rule Set Properties - @Observable handles changes - These will be removed.
    // var projectDisplayName: String = "Selected Project"
    // var ruleSetStatusMessage: String = "Verify or Install Rule Set"
    // var selectedProjectURL: URL?
    // var currentRuleSetStatus: MCPConfigManager.RuleSetStatus = .notInstalled

    // Status for individual MCPs (raw boolean enabled/disabled)
    // These are now computed properties based on mcpConfigManager
    var isClaudeCodeEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "claude-code").enabled }
        set {
            mcpConfigManager.setMCPEnabled(
                mcpIdentifier: "claude-code",
                nameForEntry: "Claude Code",
                enabled: newValue,
                defaultCommand: ["claude-code"]
            )
            refreshMCPStatusMessage(for: "claude-code")
        }
    }

    var isMacOSAutomatorEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "macos-automator").enabled }
        set {
            mcpConfigManager.setMCPEnabled(
                mcpIdentifier: "macos-automator",
                nameForEntry: "macOS Automator",
                enabled: newValue,
                defaultCommand: ["macos-automator"]
            )
            refreshMCPStatusMessage(for: "macos-automator")
        }
    }

    var isXcodeBuildEnabled: Bool {
        get { mcpConfigManager.getMCPStatus(mcpIdentifier: "XcodeBuildMCP").enabled }
        set {
            mcpConfigManager.setMCPEnabled(
                mcpIdentifier: "XcodeBuildMCP",
                nameForEntry: "XcodeBuildMCP",
                enabled: newValue,
                defaultCommand: ["XcodeBuildMCP"]
            )
            refreshMCPStatusMessage(for: "XcodeBuildMCP")
        }
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
        logger.info("""
            Claude: \(self.claudeCodeStatusMessage), Automator: \(self.macOSAutomatorStatusMessage), \
            Xcode: \(self.xcodeBuildStatusMessage)
            """)
    }

    func refreshMCPStatusMessage(for _: String) {
        // Implementation of refreshMCPStatusMessage method
    }

    // MARK: Private

    // Logger instance
    private let logger = Logger(category: .settings)

    // Dependencies
    private let loginItemManager: LoginItemManager

    // MARK: - Rule Set Management - This section will be removed.

    // public func verifyTerminatorRuleSetStatus(projectURL: URL?) { ... }
    // public func installTerminatorRuleSet(forProject projectURL: URL?) { ... }

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
