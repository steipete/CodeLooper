import AppKit
import Defaults
import SwiftUI

struct SettingsView: View {
    @State private var mainSettingsViewModel = MainSettingsViewModel(loginItemManager: LoginItemManager.shared)

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            CursorSupervisionSettingsView()
                .tabItem {
                    Label("Supervision", systemImage: "eye.fill")
                }
            
            CursorRuleSetsSettingsTab(viewModel: mainSettingsViewModel)
                .tabItem {
                    Label("Rule Sets", systemImage: "list.star")
                }
            
            ExternalMCPsSettingsTab(viewModel: mainSettingsViewModel)
                .tabItem {
                    Label("External MCPs", systemImage: "server.rack")
                }
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
            
            LogSettingsView()
                .tabItem {
                    Label("Log", systemImage: "doc.text.fill")
                }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .padding()
    }
}

// Placeholder Views for each tab

struct GeneralSettingsView: View {
    @Default(.startAtLogin)
    var startAtLogin
    @Default(.showInMenuBar)
    var showInMenuBar
    @Default(.automaticallyCheckForUpdates)
    var automaticallyCheckForUpdates
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled
    @Default(.monitoringIntervalSeconds)
    var monitoringIntervalSeconds
    @Default(.maxInterventionsBeforePause)
    var maxInterventionsBeforePause
    @Default(.maxConnectionIssueRetries)
    var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures)
    var maxConsecutiveRecoveryFailures
    @Default(.playSoundOnIntervention)
    var playSoundOnIntervention
    @Default(.sendNotificationOnPersistentError)
    var sendNotificationOnPersistentError: Bool
    @Default(.textForCursorStopsRecovery)
    var textForCursorStopsRecovery
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.postInterventionObservationWindowSeconds)
    var postInterventionObservationWindowSeconds
    @Default(.stuckDetectionTimeoutSeconds)
    var stuckDetectionTimeoutSeconds: TimeInterval
    @Default(.showDebugMenu)
    var showDebugMenu

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    var body: some View {
        Form {
            Section(header: Text("General Application Behavior")) {
                Toggle("Launch CodeLooper at Login", isOn: $startAtLogin)
                Toggle("Show Icon in Menu Bar", isOn: $showInMenuBar)
                    .onChange(of: showInMenuBar) { newValue in
                        NotificationCenter.default.post(
                            name: .menuBarVisibilityChanged,
                            object: nil,
                            userInfo: ["visible": newValue]
                        )
                    }
            }

            Section(header: Text("Supervision Core Settings")) {
                Toggle("Enable Global Monitoring", isOn: $isGlobalMonitoringEnabled)
                TextField(
                    "Monitoring Interval (seconds)",
                    value: $monitoringIntervalSeconds,
                    formatter: NumberFormatter.timeIntervalFormatter
                )
                    .frame(maxWidth: 150)
                Stepper(
                    "Max Auto-Interventions Per Instance: \\(maxInterventionsBeforePause)",
                    value: $maxInterventionsBeforePause,
                    in: 1...25
                )
                Toggle("Play Sound on Intervention", isOn: $playSoundOnIntervention)

                TextEditor(text: $textForCursorStopsRecovery)
                    .frame(height: 80)
                    .border(Color.gray.opacity(0.5), width: 1)
                Text("Text for 'Cursor Stops' Recovery (when CodeLooper nudges Cursor):")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Updates (Powered by Sparkle)")) {
                Toggle("Automatically Check for Updates", isOn: $automaticallyCheckForUpdates)
                Button("Check for Updates Now") {
                    print("Check for Updates Now button clicked - Sparkle action needed")
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.checkForUpdates()
                    }
                }
                Text("CodeLooper Version: \\(appVersion) (Build \\(appBuild))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Troubleshooting & Reset")) {
                Button("Reset Welcome Guide") {
                    Defaults[.hasShownWelcomeGuide] = false
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showWelcomeWindow()
                    }
                }
                .foregroundColor(.orange)

                Button("Reset All User Settings to Default") {
                    Defaults.reset(
                        .startAtLogin,
                        .showInMenuBar,
                        .automaticallyCheckForUpdates,
                        .isGlobalMonitoringEnabled,
                        .monitoringIntervalSeconds,
                        .maxInterventionsBeforePause,
                        .maxConnectionIssueRetries,
                        .maxConsecutiveRecoveryFailures,
                        .playSoundOnIntervention,
                        .sendNotificationOnPersistentError,
                        .textForCursorStopsRecovery,
                        .monitorSidebarActivity,
                        .postInterventionObservationWindowSeconds,
                        .stuckDetectionTimeoutSeconds,
                        .showDebugMenu
                    )
                    NotificationCenter.default.post(
                        name: .menuBarVisibilityChanged,
                        object: nil,
                        userInfo: ["visible": Defaults[.showInMenuBar]]
                    )
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension NumberFormatter {
    static var timeIntervalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0.5
        formatter.maximum = 5.0
        formatter.maximumFractionDigits = 1
        return formatter
    }
}

struct CursorSupervisionSettingsView: View {
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.enableConnectionIssuesRecovery)
    var enableConnectionIssuesRecovery
    @Default(.enableCursorForceStoppedRecovery)
    var enableCursorForceStoppedRecovery
    @Default(.enableCursorStopsRecovery)
    var enableCursorStopsRecovery

    var body: some View {
        Form {
            Section(header: Text("Automated Recovery Behaviors")) {
                Text(
                    "Enable specific automatic recovery mechanisms CodeLooper should attempt when " +
                    "Cursor appears to be stuck or encounters issues."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Toggle("Enable \"Connection Issues\" Recovery", isOn: $enableConnectionIssuesRecovery)
                Toggle(
                    "Enable \"Cursor Force-Stopped (Loop Limit)\" Recovery",
                    isOn: $enableCursorForceStoppedRecovery
                )
                Toggle("Enable \"Cursor Stops\" (Nudge with Custom Text) Recovery", isOn: $enableCursorStopsRecovery)
            }
            
            Section(header: Text("Activity Monitoring")) {
                Toggle(
                    "Monitor Sidebar Activity as Positive Work Indicator",
                    isOn: $monitorSidebarActivity
                )
                Text(
                    "If enabled, changes detected in Cursor's sidebar will be considered a sign of " +
                    "active use, resetting intervention counters."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cursor Rule Sets Tab (Integrated from Sources/Components/SwiftUI/SettingsTabs/CursorRuleSetsSettingsTab.swift)
struct CursorRuleSetsSettingsTab: View {
    @Bindable var viewModel: MainSettingsViewModel
    @State private var selectedProjectURL: URL? 
    @State private var ruleSetStatus: MCPConfigManager.RuleSetStatus = .notInstalled 
    @State private var projectDisplayName: String = "Selected Project"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Manage Cursor Project Rule Sets")
                    .font(.title2)
                Text("Install, update, or verify rule sets for your Cursor projects. These rules can help Cursor understand specific project contexts better.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)

                // Terminator Terminal Controller Rule Set (Spec 3.3.C)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Terminator Terminal Controller")
                        .font(.headline)
                    Text("Provides rules for interacting with the macOS Terminal via AppleScript, allowing Cursor to execute commands or manage terminal windows as part of its workflows.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Verify in Project...") {
                        Task {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the project root directory to verify the Terminator Rule Set."
                            
                            if await panel.runModal() == .OK {
                                if let url = panel.url {
                                    self.selectedProjectURL = url
                                    // Update ruleSetStatus and projectDisplayName based on verification
                                    let statusResult = viewModel.verifyTerminatorRuleSetStatus(projectURL: url)
                                    self.ruleSetStatus = statusResult
                                    self.projectDisplayName = url.lastPathComponent
                                } else {
                                    // Handle case where user cancels or no URL is selected
                                    self.ruleSetStatus = .notInstalled // Reset or set to an appropriate default
                                    self.projectDisplayName = "Selected Project"
                                    self.selectedProjectURL = nil
                                }
                            } else {
                                // User cancelled panel - do nothing, keep existing state
                            }
                        }
                    }

                    // Display Rule Set Status
                    if selectedProjectURL != nil {
                        HStack {
                            Text("Status for \\\\(projectDisplayName):")
                                .font(.headline)
                            Text(ruleSetStatus.displayName)
                                .foregroundColor(statusColor(for: ruleSetStatus))
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    } else {
                        Text("Select a project directory to verify or install the rule set.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 5)
                    }
                    
                    // Action buttons based on status
                    HStack {
                        Button(action: {
                            viewModel.installTerminatorRuleSet(forProject: selectedProjectURL)
                            // After action, re-verify status if a project is selected
                            if let url = selectedProjectURL {
                                self.ruleSetStatus = viewModel.verifyTerminatorRuleSetStatus(projectURL: url)
                            } else {
                                // If no project was selected, installTerminatorRuleSet would have prompted.
                                // We don't have a URL to immediately verify here, so we reset the view.
                                self.ruleSetStatus = .notInstalled
                                self.projectDisplayName = "Selected Project"
                            }
                        }) {
                            Text(buttonText(for: ruleSetStatus, projectSelected: selectedProjectURL != nil))
                        }

                        if case .updateAvailable(_, let newVersion) = ruleSetStatus, selectedProjectURL != nil {
                            Button("Update to v\\\\(newVersion)") {
                                if let url = selectedProjectURL {
                                    if viewModel.mcpConfigManager.installTerminatorRuleSet(to: url) {
                                        self.ruleSetStatus = viewModel.verifyTerminatorRuleSetStatus(projectURL: url)
                                        AlertPresenter.shared.showInfo(title: "Rule Set Updated", message: "Terminator Rule Set updated successfully in \\\\(url.lastPathComponent).")
                                    } else {
                                        AlertPresenter.shared.showAlert(title: "Update Failed", message: "Could not update Terminator Rule Set in \\\\(url.lastPathComponent). Check logs.", style: .critical)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Spacer()
            }
            .padding()
        }
    }

    private func statusColor(for status: MCPConfigManager.RuleSetStatus) -> Color {
        switch status {
        case .notInstalled, .bundleResourceMissing:
            return .orange // More of a neutral "action needed" or app setup issue
        case .corrupted:
            return .red // Data integrity issue
        case .installed:
            return .green
        case .updateAvailable:
            return .blue // Informational, positive action available
        }
    }

    private func buttonText(for status: MCPConfigManager.RuleSetStatus, projectSelected: Bool) -> String {
        if !projectSelected {
            return "Select Project & Install/Verify Rule Set"
        }
        switch status {
        case .notInstalled, .corrupted, .bundleResourceMissing:
            return "Install Rule Set to \\\\(projectDisplayName)"
        case .installed(let version):
            return "Re-install v\\\\(version) to \\\\(projectDisplayName)"
        case .updateAvailable(let installedVersion, _):
            // The main button serves as re-install for the current (older) version if an update is also separately offered
            return "Re-install v\\\\(installedVersion) to \\\\(projectDisplayName)"
        }
    }
}

// MARK: - External MCPs Tab (Integrated from Sources/Components/SwiftUI/SettingsTabs/ExternalMCPsSettingsTab.swift)
struct ExternalMCPsSettingsTab: View {
    @Bindable var viewModel: MainSettingsViewModel
    
    // State for warning alerts (Spec 3.3.D)
    @State private var showClaudeCodeEnableWarning = false
    @State private var showMacOSAutomatorEnableWarning = false
    @State private var showClearMCPFileConfirmation = false

    // Local @State for status messages (e.g. claudeCodeStatus) are removed.
    // They are now obtained directly from viewModel.claudeCodeStatusMessage etc.

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                Text("External Model Context Protocol (MCP) Servers")
                    .font(.title2)
                Text("Enable and configure MCP servers to extend CodeLooper\\'s capabilities with AI agents like Cursor. Changes here will update your `~/.cursor/mcp.json` file.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)

                // Display mcp.json path (Spec 3.3.D)
                HStack {
                    Text("MCP Configuration File:")
                        .font(.headline)
                    Text("~/.cursor/mcp.json")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button {
                        viewModel.viewMCPFile()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View File")
                    }
                    Button(role: .destructive) {
                        showClearMCPFileConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                        Text("Clear File")
                    }
                }
                .padding(.bottom)
                .alert("Clear MCP Configuration File?", isPresented: $showClearMCPFileConfirmation) {
                    Button("Clear File", role: .destructive) { viewModel.clearMCPFile() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to clear the MCP configuration file (~/.cursor/mcp.json)? This will reset all MCP server settings and the global shortcut to their defaults. This action cannot be undone.")
                }

                // Claude Code MCP (Spec 3.3.D)
                mcpConfigurationView(
                    mcpName: "Claude Code",
                    mcpDescription: "Integrates with Anthropic\\'s Claude Code for advanced code generation and understanding tasks.",
                    isEnabled: Binding(
                        get: { viewModel.isClaudeCodeEnabled },
                        set: { newValue in
                            if newValue { // Enabling
                                showClaudeCodeEnableWarning = true
                            } else { // Disabling
                                viewModel.isClaudeCodeEnabled = false
                            }
                        }
                    ),
                    statusMessageBinding: Binding( // Changed from statusMessage to statusMessageBinding
                        get: { viewModel.claudeCodeStatusMessage },
                        set: { _ in /* Read-only from view model */ }
                    ),
                    detailsAction: { viewModel.configureClaudeCode() }
                )
                .alert("Enable Claude Code MCP?", isPresented: $showClaudeCodeEnableWarning) {
                    Button("Enable", role: .destructive) { viewModel.isClaudeCodeEnabled = true }
                    Button("Cancel", role: .cancel) { /* Toggle will remain false implicitly */ }
                } message: {
                    Text("Enabling the Claude Code MCP allows external tools to execute commands with broad system access. Ensure you trust the source and understand the potential risks before proceeding.")
                }

                // macOS Automator MCP (Spec 3.3.D)
                mcpConfigurationView(
                    mcpName: "macOS Automator",
                    mcpDescription: "Allows AI agents to run AppleScripts and JXA scripts to automate macOS applications and system tasks.",
                    isEnabled: Binding(
                        get: { viewModel.isMacOSAutomatorEnabled },
                        set: { newValue in
                            if newValue { // Enabling
                                showMacOSAutomatorEnableWarning = true
                            } else { // Disabling
                                viewModel.isMacOSAutomatorEnabled = false
                            }
                        }
                    ),
                    statusMessageBinding: Binding( // Changed
                        get: { viewModel.macOSAutomatorStatusMessage },
                        set: { _ in /* Read-only from view model */ }
                    ),
                    detailsAction: { viewModel.configureMacOSAutomator() }
                )
                .alert("Enable macOS Automator MCP?", isPresented: $showMacOSAutomatorEnableWarning) {
                    Button("Enable", role: .destructive) { viewModel.isMacOSAutomatorEnabled = true }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enabling the macOS Automator MCP allows AI agents to execute arbitrary AppleScripts and JavaScript for Automation (JXA) scripts. This provides powerful control over your Mac but also carries significant security risks if misused. Only enable this if you fully understand and accept these risks.")
                }
                
                // XcodeBuild MCP (Spec 3.3.D)
                mcpConfigurationView(
                    mcpName: "XcodeBuild",
                    mcpDescription: "Enables interaction with Xcode projects for building, testing, and querying project information.",
                    isEnabled: $viewModel.isXcodeBuildEnabled, // Direct binding
                    statusMessageBinding: Binding( // Changed
                        get: { viewModel.xcodeBuildStatusMessage },
                        set: { _ in /* Read-only from view model */ }
                    ),
                    detailsAction: { viewModel.configureXcodeBuild() }
                )

                Divider().padding(.vertical)

                // Global Shortcut Configuration (Spec 7.A.2)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Global MCP Shortcut")
                        .font(.headline)
                    Text("Define a system-wide shortcut to trigger the primary MCP action (e.g., from Cursor). This requires an external tool or script listening for this shortcut. Example: \\\"Command+Shift+L\\\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Global Shortcut String", text: $viewModel.globalShortcutString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Save Shortcut") {
                            viewModel.saveGlobalShortcut()
                        }
                    }
                    Text("Note: CodeLooper itself does not register this shortcut. Ensure your designated MCP or a helper tool handles it.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Spacer()
            }
            .padding()
            .onAppear {
                viewModel.refreshAllMCPStatusMessages() // Refresh statuses on appear
            }
            .onChange(of: viewModel.isClaudeCodeEnabled) { _, _ in viewModel.refreshAllMCPStatusMessages() }
            .onChange(of: viewModel.isMacOSAutomatorEnabled) { _, _ in viewModel.refreshAllMCPStatusMessages() }
            .onChange(of: viewModel.isXcodeBuildEnabled) { _, _ in viewModel.refreshAllMCPStatusMessages() }
            // Sheet presentations for MCP configurations
            .sheet(isPresented: $viewModel.showingClaudeConfigSheet) {
                ClaudeCodeConfigView(
                    isPresented: $viewModel.showingClaudeConfigSheet,
                    customCliName: $viewModel.claudeCodeCustomCliName,
                    onSave: { newName in
                        viewModel.saveClaudeCodeConfiguration(newCliName: newName)
                        // Status will be refreshed by the onChange of isClaudeCodeEnabled or on next appear
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingXcodeConfigSheet) {
                XcodeBuildConfigView(
                    isPresented: $viewModel.showingXcodeConfigSheet,
                    versionString: $viewModel.xcodeBuildVersionString,
                    isIncrementalBuildsEnabled: $viewModel.xcodeBuildIncrementalBuilds,
                    isSentryDisabled: $viewModel.xcodeBuildSentryDisabled,
                    onSave: { version, incremental, sentry in
                        viewModel.saveXcodeBuildConfiguration(version: version, incrementalBuilds: incremental, sentryDisabled: sentry)
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingAutomatorConfigSheet) {
                MacOSAutomatorConfigView(isPresented: $viewModel.showingAutomatorConfigSheet)
            }
        }
    }

    @ViewBuilder
    private func mcpConfigurationView(mcpName: String, mcpDescription: String, isEnabled: Binding<Bool>, statusMessageBinding: Binding<String>, detailsAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill") // Generic icon
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(mcpName)
                    .font(.headline)
                Spacer()
                Toggle("Enabled", isOn: isEnabled)
                    .labelsHidden()
            }
            Text(mcpDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(statusMessageBinding.wrappedValue) // Display the status message from ViewModel
                .font(.caption)
                .foregroundColor(determineStatusColor(forMessage: statusMessageBinding.wrappedValue))
                .padding(.vertical, 2)

            Button("Configure / Details...") {
                detailsAction()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func determineStatusColor(forMessage message: String) -> Color {
        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.contains("error") || lowercasedMessage.contains("failed") || lowercasedMessage.contains("not found") {
            return .red
        } else if lowercasedMessage.contains("enabled") || lowercasedMessage.contains("active") || lowercasedMessage.contains("configured") {
            return .green
        } else if lowercasedMessage.contains("disabled") || lowercasedMessage.contains("unknown") || lowercasedMessage.contains("loading") {
            return .gray
        } else if lowercasedMessage.contains("update available") || lowercasedMessage.contains("warning") {
            return .orange
        }
        return .secondary // Default color
    }
}

struct AdvancedSettingsView: View {
    // Supervision Tuning Defaults
    @Default(.maxConnectionIssueRetries) var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures) var maxConsecutiveRecoveryFailures
    @Default(.postInterventionObservationWindowSeconds) var postInterventionObservationWindowSeconds
    @Default(.sendNotificationOnPersistentError) var sendNotificationOnPersistentError: Bool
    @Default(.stuckDetectionTimeoutSeconds) var stuckDetectionTimeoutSeconds: TimeInterval

    // Custom Locator Defaults
    @Default(.locatorJSONGeneratingIndicatorText) var locatorGeneratingIndicatorText: String
    @Default(.locatorJSONSidebarActivityArea) var locatorSidebarActivityArea: String
    @Default(.locatorJSONErrorMessagePopup) var locatorErrorMessagePopup: String
    @Default(.locatorJSONStopGeneratingButton) var locatorStopGeneratingButton: String
    @Default(.locatorJSONConnectionErrorIndicator) var locatorConnectionErrorIndicator: String
    @Default(.locatorJSONResumeConnectionButton) var locatorResumeConnectionButton: String
    @Default(.locatorJSONForceStopResumeLink) var locatorForceStopResumeLink: String
    @Default(.locatorJSONMainInputField) var locatorMainInputField: String

    private let locatorPlaceholders: [String: String] = [
        "generatingIndicatorText": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"Generating...\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "sidebarActivityArea": "e.g., {\"criteria\":[{\"key\":\"AXIdentifier\",\"value\":\"sidebar_main\",\"match_type\":\"exact\"}]}",
        "errorMessagePopup": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXWindow\"},{\"key\":\"AXTitle\",\"value\":\"Error\",\"match_type\":\"contains\"}]}",
        "stopGeneratingButton": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXButton\"},{\"key\":\"AXTitle\",\"value\":\"Stop\",\"match_type\":\"exact\"}]}",
        "connectionErrorIndicator": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"We\'re having trouble connecting\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "resumeConnectionButton": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXButton\"},{\"key\":\"AXTitle\",\"value\":\"Resume\",\"match_type\":\"exact\"}]}",
        "forceStopResumeLink": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"resume the conversation\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "mainInputField": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXTextArea\"},{\"key\":\"AXIdentifier\",\"value\":\"chat_input\"}]}"
    ]

    var body: some View {
        Form {
            Section(header: Text("Supervision Tuning")) {
                Stepper("Max 'Resume' clicks (Connection Issue): \(maxConnectionIssueRetries)", value: $maxConnectionIssueRetries, in: 1...5)
                Stepper("Max Recovery Cycles (Persistent Error): \(maxConsecutiveRecoveryFailures)", value: $maxConsecutiveRecoveryFailures, in: 1...5)
                TextField("Observation Window Post-Intervention (s)", value: $postInterventionObservationWindowSeconds, formatter: NumberFormatter.timeIntervalFormatter)
                    .frame(maxWidth: 150)
                TextField("Stuck Detection Timeout (s)", value: $stuckDetectionTimeoutSeconds, formatter: NumberFormatter.generalSecondsFormatter)
                     .frame(maxWidth: 150)
                Toggle("Send Notification on Persistent Error", isOn: $sendNotificationOnPersistentError)
            }

            Section(header: Text("Custom Element Locators (JSON - Advanced)")) {
                Text("Override default AXorcist.Locator JSON definitions. Invalid JSON or locators may break functionality. Leave blank to use app default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Group {
                    locatorEditor(title: "Generating Indicator Text", textBinding: $locatorGeneratingIndicatorText, key: .locatorJSONGeneratingIndicatorText, placeholder: locatorPlaceholders["generatingIndicatorText"] ?? "")
                    locatorEditor(title: "Sidebar Activity Area", textBinding: $locatorSidebarActivityArea, key: .locatorJSONSidebarActivityArea, placeholder: locatorPlaceholders["sidebarActivityArea"] ?? "")
                    locatorEditor(title: "Error Message Popup", textBinding: $locatorErrorMessagePopup, key: .locatorJSONErrorMessagePopup, placeholder: locatorPlaceholders["errorMessagePopup"] ?? "")
                    locatorEditor(title: "Stop Generating Button", textBinding: $locatorStopGeneratingButton, key: .locatorJSONStopGeneratingButton, placeholder: locatorPlaceholders["stopGeneratingButton"] ?? "")
                }
                Group {
                    locatorEditor(title: "Connection Error Indicator", textBinding: $locatorConnectionErrorIndicator, key: .locatorJSONConnectionErrorIndicator, placeholder: locatorPlaceholders["connectionErrorIndicator"] ?? "")
                    locatorEditor(title: "Resume Connection Button", textBinding: $locatorResumeConnectionButton, key: .locatorJSONResumeConnectionButton, placeholder: locatorPlaceholders["resumeConnectionButton"] ?? "")
                    locatorEditor(title: "Force-Stop Resume Link", textBinding: $locatorForceStopResumeLink, key: .locatorJSONForceStopResumeLink, placeholder: locatorPlaceholders["forceStopResumeLink"] ?? "")
                    locatorEditor(title: "Main Input Field", textBinding: $locatorMainInputField, key: .locatorJSONMainInputField, placeholder: locatorPlaceholders["mainInputField"] ?? "")
                }

                Button("Reset All Locators to Defaults") {
                    Defaults.reset(
                        .locatorJSONGeneratingIndicatorText,
                        .locatorJSONSidebarActivityArea,
                        .locatorJSONErrorMessagePopup,
                        .locatorJSONStopGeneratingButton,
                        .locatorJSONConnectionErrorIndicator,
                        .locatorJSONResumeConnectionButton,
                        .locatorJSONForceStopResumeLink,
                        .locatorJSONMainInputField
                    )
                }
                .foregroundColor(.orange)
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func locatorEditor(title: String, textBinding: Binding<String>, key: Defaults.Key<String>, placeholder: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Button("Reset") {
                    Defaults.reset(key)
                }.font(.caption)
            }
            TextEditor(text: textBinding)
                .font(.system(.body, design: .monospaced))
                .frame(height: 80)
                .border(Color.gray.opacity(0.5), width: 1)
                .overlay(alignment: .topLeading) {
                    if textBinding.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }
            Text("Enter valid AXorcist.Locator JSON. Blank uses app default.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 3)
    }
}

extension NumberFormatter {
    static var generalSecondsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1.0 // Example, adjust as needed
        formatter.maximum = 300.0 // Example, adjust as needed
        formatter.maximumFractionDigits = 1
        return formatter
    }
}

struct LogSettingsView: View {
    @ObservedObject var sessionLogger = SessionLogger.shared
    var body: some View {
        VStack {
            Text("Session Activity Log").font(.title2).padding(.bottom)
            List {
                ForEach(sessionLogger.entries) { entry in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(entry.timestamp, style: .time)
                            Text("PID: \(entry.instancePID.map(String.init) ?? "N/A")")
                            Text(entry.level.rawValue.capitalized)
                                .foregroundColor(logLevelColor(entry.level))
                        }
                        Text(entry.message)
                            .font(.caption)
                    }
                }
            }
            HStack {
                Button("Clear Log") {
                    sessionLogger.clearLog()
                }
                Button("Copy Log to Clipboard") {
                    let logText = sessionLogger.entries.map { entry -> String in
                        let pidString = entry.instancePID.map { String($0) } ?? "N/A"
                        return "[\\(entry.timestamp.formatted(date: .omitted, time: .standard))] PID: \\(pidString) [\\(entry.level.rawValue.uppercased())] \\(entry.message)"
                    }.joined(separator: "\n")
                    
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(logText, forType: .string)
                }
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .notice: return .purple
        case .critical: return .pink
        case .fault: return .black
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 