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
                    .onChange(of: showInMenuBar) { oldValue, newValue in
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
                            
                            if panel.runModal() == .OK {
                                if let url = panel.url {
                                    viewModel.verifyTerminatorRuleSetStatus(projectURL: url)
                                } else {
                                    viewModel.verifyTerminatorRuleSetStatus(projectURL: nil)
                                }
                            } else {
                                // User cancelled panel - do nothing, ViewModel's state remains as is
                            }
                        }
                    }

                    // Display Rule Set Status
                    if viewModel.selectedProjectURL != nil {
                        HStack {
                            Text("Status for \\(viewModel.projectDisplayName):")
                                .font(.headline)
                            Text(viewModel.currentRuleSetStatus.displayName)
                                .foregroundColor(statusColor(for: viewModel.currentRuleSetStatus))
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
                            viewModel.installTerminatorRuleSet(forProject: viewModel.selectedProjectURL)
                        }) {
                            Text(buttonText(for: viewModel.currentRuleSetStatus, projectSelected: viewModel.selectedProjectURL != nil, projectDisplayName: viewModel.projectDisplayName))
                        }

                        if case .updateAvailable(_, let newVersionString) = viewModel.currentRuleSetStatus, viewModel.selectedProjectURL != nil {
                            Button("Update to v\(newVersionString)") {
                                if let url = viewModel.selectedProjectURL {
                                    viewModel.installTerminatorRuleSet(forProject: url)
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

    private func buttonText(for status: MCPConfigManager.RuleSetStatus, projectSelected: Bool, projectDisplayName: String) -> String {
        if !projectSelected {
            return "Select Project & Install/Verify Rule Set"
        }
        switch status {
        case .notInstalled, .corrupted, .bundleResourceMissing:
            return "Install Rule Set to \(projectDisplayName)"
        case .installed(let versionString):
            return "Re-install v\(versionString) to \(projectDisplayName)"
        case .updateAvailable(let installedVersionString, _ /* newVersionString (unused) */):
            return "Re-install v\(installedVersionString) to \(projectDisplayName)"
        }
    }
}

// MARK: - External MCPs Tab (Integrated from Sources/Components/SwiftUI/SettingsTabs/ExternalMCPsSettingsTab.swift)

// Extracted View for individual MCP Configuration sections
struct MCPConfigurationEntryView: View {
    let mcpName: String
    let mcpDescription: String
    @Binding var isEnabled: Bool
    @Binding var statusMessageBinding: String // Renamed from statusMessage for clarity with @Binding
    let detailsAction: () -> Void
    
    // For warning alert related to this specific MCP entry
    @State private var showEnableWarning = false
    let warningTitle: String
    let warningMessage: String
    var onConfirmEnable: () -> Void // Closure to call when user confirms enabling

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(mcpName)
                    .font(.headline)
                Spacer()
                Toggle("Enabled", isOn: Binding( // Custom binding to show warning
                    get: { isEnabled },
                    set: { newValue in
                        if newValue { // Enabling
                            showEnableWarning = true
                        } else { // Disabling
                            isEnabled = false // Directly set if disabling
                        }
                    }
                ))
                .labelsHidden()
            }
            Text(mcpDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(statusMessageBinding)
                .font(.caption)
                .foregroundColor(determineStatusColor(forMessage: statusMessageBinding))
                .padding(.vertical, 2)

            Button("Configure / Details...") {
                detailsAction()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .alert(warningTitle, isPresented: $showEnableWarning) {
            Button("Enable", role: .destructive) {
                onConfirmEnable() // Call the closure that will set isEnabled = true
            }
            Button("Cancel", role: .cancel) { /* isEnabled remains false */ }
        } message: {
            Text(warningMessage)
        }
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

struct ExternalMCPsSettingsTab: View {
    @Bindable var viewModel: MainSettingsViewModel
    @State private var showClaudeCodeConfigSheet = false
    @State private var showXcodeBuildConfigSheet = false
    @State private var showMacAutomatorConfigSheet = false
    @State private var showClearMCPFileConfirmation = false

    var body: some View {
        Text("External MCPs Settings (Temporarily Simplified)") // Placeholder
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
        Text("Log View (Temporarily Simplified)") // Placeholder
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 