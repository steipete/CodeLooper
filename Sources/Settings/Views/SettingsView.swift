import AppKit
import Defaults
import SwiftUI

struct SettingsView: View {
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
            
            CursorRuleSetsSettingsView()
                .tabItem {
                    Label("Rule Sets", systemImage: "list.star")
                }
            
            ExternalMCPsSettingsView()
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
    var sendNotificationOnPersistentError
    @Default(.textForCursorStopsRecovery)
    var textForCursorStopsRecovery
    @Default(.monitorSidebarActivity)
    var monitorSidebarActivity
    @Default(.postInterventionObservationWindowSeconds)
    var postInterventionObservationWindowSeconds
    @Default(.stuckDetectionTimeoutSeconds)
    var stuckDetectionTimeoutSeconds
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

enum RuleSetStatus: Equatable {
    case notInstalled
    case installed
    case checking
    case error(String)
}

struct CursorRuleSetsSettingsView: View {
    @State private var terminatorRuleSetStatus: RuleSetStatus = .checking
    @State private var terminatorButtonText: String = "Select Project Directory..."
    @State private var isShowingDirectoryPicker: Bool = false
    @State private var selectedProjectDirectory: URL?
    @State private var lastCheckedProjectDirectory: URL?
    @State private var installErrorMessage: String?

    private let terminatorScriptName = "terminator.scpt"
    private let terminatorRuleName = "codelooper_terminator_rule.mdc"
    private let cursorSubDir = ".cursor"
    private let scriptsSubDir = "scripts"
    private let rulesSubDir = "rules"

    var body: some View {
        Form {
            Section(header: Text("Terminator Terminal Controller Rule Set")) {
                Text(
                    "This rule set allows Cursor to open and control a specific terminal window using " +
                    "AppleScript, useful for tasks requiring persistent terminal sessions managed by " +
                    "an AI agent."
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Status: \(statusText(for: terminatorRuleSetStatus))")
                        if let dir = lastCheckedProjectDirectory {
                            Text("Checked in: \(dir.lastPathComponent)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Button(terminatorButtonText) {
                        handleTerminatorButtonAction()
                    }
                }
                
                if let errorMsg = installErrorMessage {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isShowingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedProjectDirectory = url
                    lastCheckedProjectDirectory = url // Update for display immediately
                    installErrorMessage = nil // Clear previous errors
                    checkTerminatorInstallation(at: url)
                }
            case .failure(let error):
                terminatorRuleSetStatus = .error("Failed to select directory: \(error.localizedDescription)")
                installErrorMessage = "Failed to select directory: \(error.localizedDescription)"
                updateButtonText()
            }
        }
        .onAppear {
            // Initial check if a directory was previously selected or use a default heuristic
            // For V1, require manual selection first.
            updateButtonText() // Set initial button text based on status
        }
    }

    private func statusText(for status: RuleSetStatus) -> String {
        switch status {
        case .notInstalled: return "Not Installed"
        case .installed: return "Installed"
        case .checking: return "Checking..."
        case .error(let msg): return "Error"
        }
    }
    
    private func updateButtonText() {
        switch terminatorRuleSetStatus {
        case .notInstalled:
            terminatorButtonText = selectedProjectDirectory == nil ? "Select Project Directory..." : "Install"
        case .installed:
            terminatorButtonText = "Verify Installation"
        case .checking:
            terminatorButtonText = "Checking..."
        case .error:
            terminatorButtonText = selectedProjectDirectory == nil ? 
                "Select Project Directory..." : "Retry Install/Check"
        }
    }

    private func handleTerminatorButtonAction() {
        installErrorMessage = nil // Clear previous errors
        guard let projectDir = selectedProjectDirectory else {
            isShowingDirectoryPicker = true
            return
        }

        switch terminatorRuleSetStatus {
        case .notInstalled, .error: // If not installed or error, try to install/reinstall
            installTerminatorRuleSet(to: projectDir)
        case .installed: // If installed, verify again
            checkTerminatorInstallation(at: projectDir)
        case .checking:
            break // Do nothing if already checking
        }
    }

    private func checkTerminatorInstallation(at projectPath: URL?) {
        guard let projectPath = projectPath else {
            terminatorRuleSetStatus = .notInstalled // Or some other appropriate default if no path
            updateButtonText()
            return
        }

        terminatorRuleSetStatus = .checking
        updateButtonText()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptURL = projectPath.appendingPathComponent(cursorSubDir)
                .appendingPathComponent(scriptsSubDir)
                .appendingPathComponent(terminatorScriptName)
            let ruleURL = projectPath.appendingPathComponent(cursorSubDir)
                .appendingPathComponent(rulesSubDir)
                .appendingPathComponent(terminatorRuleName)

            let scriptExists = FileManager.default.fileExists(atPath: scriptURL.path)
            let ruleExists = FileManager.default.fileExists(atPath: ruleURL.path)
            
            // Simulate a small delay for checking
            Thread.sleep(forTimeInterval: 0.5)

            DispatchQueue.main.async {
                if scriptExists && ruleExists {
                    terminatorRuleSetStatus = .installed
                } else {
                    terminatorRuleSetStatus = .notInstalled
                    if !scriptExists {
                        print("Terminator script not found at \(scriptURL.path)")
                    }
                    if !ruleExists {
                        print("Terminator rule not found at \(ruleURL.path)")
                    }
                }
                updateButtonText()
            }
        }
    }
    
    // Installation logic will go here
    private func installTerminatorRuleSet(to projectPath: URL) {
        terminatorRuleSetStatus = .checking
        updateButtonText()
        installErrorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            guard let scriptSourceURL = Bundle.main.url(
                    forResource: terminatorScriptName,
                    withExtension: nil,
                    subdirectory: "RuleSets/Terminator"
                ),
                let ruleSourceURL = Bundle.main.url(
                    forResource: terminatorRuleName,
                    withExtension: nil,
                    subdirectory: "RuleSets/Terminator"
                ) else {
                DispatchQueue.main.async {
                    self.installErrorMessage = "Error: Bundled rule set files not found."
                    self.terminatorRuleSetStatus = .error("Bundle integrity issue")
                    self.updateButtonText()
                }
                return
            }

            let cursorDir = projectPath.appendingPathComponent(self.cursorSubDir)
            let scriptsDir = cursorDir.appendingPathComponent(self.scriptsSubDir)
            let rulesDir = cursorDir.appendingPathComponent(self.rulesSubDir)

            let scriptDestURL = scriptsDir.appendingPathComponent(self.terminatorScriptName)
            let ruleDestURL = rulesDir.appendingPathComponent(self.terminatorRuleName)

            do {
                try FileManager.default.createDirectory(
                    at: scriptsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try FileManager.default.createDirectory(
                    at: rulesDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                // Copy script (overwrite if exists as per spec for "Install/Update")
                if FileManager.default.fileExists(atPath: scriptDestURL.path) {
                    try FileManager.default.removeItem(at: scriptDestURL)
                }
                try FileManager.default.copyItem(at: scriptSourceURL, to: scriptDestURL)
                print("Copied script to \(scriptDestURL.path)")

                // Copy rule (overwrite if exists)
                if FileManager.default.fileExists(atPath: ruleDestURL.path) {
                    try FileManager.default.removeItem(at: ruleDestURL)
                }
                try FileManager.default.copyItem(at: ruleSourceURL, to: ruleDestURL)
                print("Copied rule to \(ruleDestURL.path)")
                
                DispatchQueue.main.async {
                    // Re-check installation after attempting to copy
                    self.checkTerminatorInstallation(at: projectPath)
                }

            } catch {
                DispatchQueue.main.async {
                    self.installErrorMessage = "Installation failed: \(error.localizedDescription)"
                    self.terminatorRuleSetStatus = .error("File operation failed")
                    self.updateButtonText()
                }
            }
        }
    }
}

struct ExternalMCPsSettingsView: View {
    @State private var mcpServers: [MCPServerEntry] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    // For sheet presentation
    @State private var selectedMCPForConfig: MCPServerEntry? = nil
    @State private var isShowingMCPConfigSheet: Bool = false
    
    // For warning alerts
    @State private var mcpToWarnAbout: MCPServerEntry? = nil
    @State private var isShowingEnableWarning: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Manage External Model Context Protocol (MCP) Servers")
                .font(.title2)
                .padding(.bottom)
            
            Text("Enable and configure MCP servers that CodeLooper can utilize to extend AI agent capabilities within Cursor. Changes here directly modify your `~/.cursor/mcp.json` file.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            if isLoading {
                ProgressView("Loading MCP Configuration...")
            } else if let errorMsg = errorMessage {
                Text("Error loading MCP configuration: \(errorMsg)")
                    .foregroundColor(.red)
            } else {
                List {
                    ForEach($mcpServers, id: \.id) { $mcpEntry in
                        MCPRowView(mcpEntry: $mcpEntry,
                                   onToggle: { wolltenabled in
                                        if wolltenabled && (mcpEntry.id == "claude-code" || mcpEntry.id == "macos-automator") {
                                            mcpToWarnAbout = mcpEntry
                                            isShowingEnableWarning = true
                                        } else {
                                            toggleMCPServer(mcpEntry, enabled: wolltenabled)
                                        }
                                   },
                                   onConfigure: { selectedMCPForConfig = mcpEntry; isShowingMCPConfigSheet = true }
                        )
                    }
                }
            }
            Spacer()
            Text("MCP Configuration File: ~/.cursor/mcp.json")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadMCPServers)
        .sheet(isPresented: $isShowingMCPConfigSheet, onDismiss: loadMCPServers) {
            if let mcp = selectedMCPForConfig {
                MCPConfigSheetView(mcpEntry: mcp)
            }
        }
        .alert(isPresented: $isShowingEnableWarning) {
            guard let mcpToEnable = mcpToWarnAbout else { return Alert(title: Text("Error")) } // Should not happen
            return Alert(
                title: Text("Enable \(mcpToEnable.name)?"),
                message: Text("Enabling powerful MCPs like \(mcpToEnable.name) can execute arbitrary code or commands on your system. Ensure you trust the source and understand the risks before proceeding."),
                primaryButton: .destructive(Text("Enable \(mcpToEnable.name)")) { 
                    toggleMCPServer(mcpToEnable, enabled: true)
                    mcpToWarnAbout = nil
                },
                secondaryButton: .cancel { mcpToWarnAbout = nil }
            )
        }
    }

    private func loadMCPServers() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let servers = try await MCPConfigManager.shared.getConfiguredMCPServers()
                DispatchQueue.main.async {
                    self.mcpServers = servers
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleMCPServer(_ mcp: MCPServerEntry, enabled: Bool) {
        Task {
            do {
                // Create default details if enabling for the first time
                // These would be specific to each MCP type
                var details: MCPServerDetailsCodable? = nil
                if enabled {
                    details = MCPServerDetailsCodable(name: mcp.name, path: mcp.path, version: mcp.version, environment: mcp.environment)
                    // For XcodeBuildMCP, name might be "Xcode Build Service" in mcp.json
                    // For Claude Code, name might be "Claude Code CLI"
                    // For macOS Automator, name might be "macOS Automator"
                    // These are often hardcoded by Cursor when it creates them.
                    // We should try to match Cursor's naming or provide a reasonable default.
                    // For V1, we will use the mcpEntry.name as the name in mcp.json if no other details exist.
                    
                    // Fetch existing details to preserve them if they exist.
                    let currentServers = try await MCPConfigManager.shared.getConfiguredMCPServers()
                    if let currentDetail = currentServers.first(where: { $0.id == mcp.id }) {
                        details = MCPServerDetailsCodable(name: currentDetail.name, path: currentDetail.path, version: currentDetail.version, environment: currentDetail.environment)
                    }
                    if details?.name.isEmpty ?? true { details?.name = mcp.name } // Ensure name is set
                }
                
                try await MCPConfigManager.shared.updateMCPServer(id: mcp.id, nameForNew: mcp.name, enabled: enabled, details: details)
                loadMCPServers() // Refresh list
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update MCP server: \(error.localizedDescription)"
                    // Optionally revert toggle state here if needed
                    loadMCPServers() // Refresh to show actual state
                }
            }
        }
    }
}

struct MCPRowView: View {
    @Binding var mcpEntry: MCPServerEntry
    var onToggle: (Bool) -> Void
    var onConfigure: () -> Void
    
    // TODO: Add icons for each MCP
    private var mcpIconName: String {
        switch mcpEntry.id {
        case "claude-code": return "c.square.fill" // Placeholder
        case "macos-automator": return "hammer.fill" // Placeholder
        case "XcodeBuildMCP": return "hammer.circle.fill" // Placeholder
        default: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: mcpIconName)
                .font(.title2)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(mcpEntry.name).font(.headline)
                Text(statusText())
                    .font(.caption)
                    .foregroundColor(mcpEntry.enabled ? .green : .gray)
                if let path = mcpEntry.path, !path.isEmpty {
                    Text("Path: \(path)").font(.caption2).foregroundColor(.secondary)
                }
                if let version = mcpEntry.version, !version.isEmpty {
                    Text("Version: \(version)").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Configure...") {
                onConfigure()
            }
            .disabled(!mcpEntry.enabled) // Only allow configure if enabled
            
            Toggle("", isOn: Binding(get: {mcpEntry.enabled}, set: { newValue, _ in onToggle(newValue) }))
                .labelsHidden()
        }
    }
    
    private func statusText() -> String {
        mcpEntry.enabled ? "Enabled" : "Disabled"
    }
}

// Placeholder for configuration sheet
struct MCPConfigSheetView: View {
    @Environment(\.dismiss) var dismiss
    let mcpEntry: MCPServerEntry // Passed in
    
    // State for editable fields, initialized from mcpEntry
    @State private var path: String
    @State private var version: String
    @State private var environmentEntries: [EnvVarEntry]
    
    struct EnvVarEntry: Identifiable, Hashable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }

    init(mcpEntry: MCPServerEntry) {
        self.mcpEntry = mcpEntry
        _path = State(initialValue: mcpEntry.path ?? "")
        _version = State(initialValue: mcpEntry.version ?? "")
        _environmentEntries = State(initialValue: (mcpEntry.environment ?? [:]).map { EnvVarEntry(key: $0.key, value: $0.value) }.sorted(by: { $0.key < $1.key }))
        if _environmentEntries.wrappedValue.isEmpty { // Ensure at least one empty row for new env vars
            _environmentEntries.wrappedValue.append(EnvVarEntry())
        }
    }

    var body: some View {
        VStack {
            Text("Configure \(mcpEntry.name)")
                .font(.title)
                .padding()
            
            Form {
                if mcpEntry.id == "claude-code" || mcpEntry.id == "macos-automator" {
                    TextField("Path to CLI/App (optional for default installs)", text: $path)
                    Text("Example for Claude Code: /usr/local/bin/claude (if installed via Homebrew). Leave blank if using 'npx @cursorfn/claude-code-cli'.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                if mcpEntry.id == "XcodeBuildMCP" {
                    TextField("Xcode Version Override (e.g., 15.3)", text: $version)
                    Text("Leave blank to use system default Xcode. Specify a version string like \"15.0\" to use a specific Xcode version if multiple are installed.")
                        .font(.caption).foregroundColor(.secondary)
                    
                    Section("Environment Variables") {
                        ForEach($environmentEntries) { $entry in
                            HStack {
                                TextField("Key", text: $entry.key)
                                TextField("Value", text: $entry.value)
                                Button(action: { if let index = environmentEntries.firstIndex(where: { $0.id == entry.id }) { environmentEntries.remove(at: index) } }) {
                                    Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        Button("Add Environment Variable") {
                            environmentEntries.append(EnvVarEntry())
                        }
                    }
                }
            }
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save Configuration") {
                    saveConfiguration()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 350, idealHeight: 450)
    }
    
    private func saveConfiguration() {
        Task {
            var updatedDetails = MCPServerDetailsCodable(name: mcpEntry.name, path: path, version: version)
            if !environmentEntries.isEmpty && !(environmentEntries.count == 1 && environmentEntries[0].key.isEmpty) {
                updatedDetails.environment = environmentEntries.reduce(into: [String:String]()) { dict, entry in
                    if !entry.key.isEmpty { dict[entry.key] = entry.value }
                }
            }
            if updatedDetails.path?.isEmpty ?? true { updatedDetails.path = nil } // Don't save empty path string
            if updatedDetails.version?.isEmpty ?? true { updatedDetails.version = nil }
            
            do {
                try await MCPConfigManager.shared.updateMCPServer(id: mcpEntry.id, nameForNew: mcpEntry.name, enabled: true, details: updatedDetails)
            } catch {
                // TODO: Show error to user in the sheet
                print("Error saving MCP config: \(error.localizedDescription)")
            }
        }
    }
}

struct AdvancedSettingsView: View {
    // Supervision Tuning Defaults
    @Default(.maxConnectionIssueRetries) var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures) var maxConsecutiveRecoveryFailures
    @Default(.postInterventionObservationWindowSeconds) var postInterventionObservationWindowSeconds
    @Default(.sendNotificationOnPersistentError) var sendNotificationOnPersistentError
    @Default(.stuckDetectionTimeoutSeconds) var stuckDetectionTimeoutSeconds // Added from spec

    // Custom Locator Defaults
    @Default(.locatorJSON_generatingIndicatorText) var locatorGeneratingIndicatorText
    @Default(.locatorJSON_sidebarActivityArea) var locatorSidebarActivityArea
    @Default(.locatorJSON_errorMessagePopup) var locatorErrorMessagePopup
    @Default(.locatorJSON_stopGeneratingButton) var locatorStopGeneratingButton
    @Default(.locatorJSON_connectionErrorIndicator) var locatorConnectionErrorIndicator
    @Default(.locatorJSON_resumeConnectionButton) var locatorResumeConnectionButton
    @Default(.locatorJSON_forceStopResumeLink) var locatorForceStopResumeLink
    @Default(.locatorJSON_mainInputField) var locatorMainInputField

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
                    locatorEditor(title: "Generating Indicator Text", textBinding: $locatorGeneratingIndicatorText, key: .locatorJSON_generatingIndicatorText, placeholder: locatorPlaceholders["generatingIndicatorText"] ?? "")
                    locatorEditor(title: "Sidebar Activity Area", textBinding: $locatorSidebarActivityArea, key: .locatorJSON_sidebarActivityArea, placeholder: locatorPlaceholders["sidebarActivityArea"] ?? "")
                    locatorEditor(title: "Error Message Popup", textBinding: $locatorErrorMessagePopup, key: .locatorJSON_errorMessagePopup, placeholder: locatorPlaceholders["errorMessagePopup"] ?? "")
                    locatorEditor(title: "Stop Generating Button", textBinding: $locatorStopGeneratingButton, key: .locatorJSON_stopGeneratingButton, placeholder: locatorPlaceholders["stopGeneratingButton"] ?? "")
                }
                Group {
                    locatorEditor(title: "Connection Error Indicator", textBinding: $locatorConnectionErrorIndicator, key: .locatorJSON_connectionErrorIndicator, placeholder: locatorPlaceholders["connectionErrorIndicator"] ?? "")
                    locatorEditor(title: "Resume Connection Button", textBinding: $locatorResumeConnectionButton, key: .locatorJSON_resumeConnectionButton, placeholder: locatorPlaceholders["resumeConnectionButton"] ?? "")
                    locatorEditor(title: "Force-Stop Resume Link", textBinding: $locatorForceStopResumeLink, key: .locatorJSON_forceStopResumeLink, placeholder: locatorPlaceholders["forceStopResumeLink"] ?? "")
                    locatorEditor(title: "Main Input Field", textBinding: $locatorMainInputField, key: .locatorJSON_mainInputField, placeholder: locatorPlaceholders["mainInputField"] ?? "")
                }

                Button("Reset All Locators to Defaults") {
                    Defaults.reset(
                        .locatorJSON_generatingIndicatorText,
                        .locatorJSON_sidebarActivityArea,
                        .locatorJSON_errorMessagePopup,
                        .locatorJSON_stopGeneratingButton,
                        .locatorJSON_connectionErrorIndicator,
                        .locatorJSON_resumeConnectionButton,
                        .locatorJSON_forceStopResumeLink,
                        .locatorJSON_mainInputField
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
        case .warn: return .orange
        case .error: return .red
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 
