import AppKit
import Defaults
import SwiftUI

// MARK: - MCP Identifier Enum
enum MCPIdentifier: String, CaseIterable {
    case claudeCode = "claude-code"
    case macOSAutomator = "macos-automator"
    case xcodeBuild = "XcodeBuildMCP"
}

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
    @EnvironmentObject var viewModel: MainSettingsViewModel // Assuming viewModel is passed as EnvironmentObject

    @State private var showClaudeCodeConfigSheet = false
    @State private var showMacAutomatorConfigSheet = false
    @State private var showXcodeBuildConfigSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Multi-Cog Powers (MCPs)")
                .font(.title2)
                .padding(.bottom, 10)

            Text("Enable and configure integrations that extend CodeLooper's capabilities. MCPs can perform advanced actions and may require separate installations or permissions.")
                .font(.callout)
                .foregroundColor(.gray)
                .padding(.bottom, 10)

            // Claude Code Agent MCP
            MCPConfigurationEntryView(
                mcpName: "Claude Code Agent",
                mcpDescription: "Enables advanced code generation, refactoring, and terminal operations via the Claude Code CLI. Requires separate installation and configuration of the claude-code CLI tool.",
                isEnabled: $viewModel.isClaudeCodeEnabled,
                statusMessageBinding: $viewModel.claudeCodeStatusMessage,
                detailsAction: { showClaudeCodeConfigSheet = true },
                warningTitle: "Enable Claude Code Agent?",
                warningMessage: "Enabling Claude Code allows CodeLooper to trigger a powerful command-line tool that can modify files, execute terminal commands, and interact with your system. Ensure you trust the source and understand the capabilities of the claude-code CLI before enabling. You are responsible for its installation and any actions it performs."
            )                { viewModel.enableMCP(MCPIdentifier.claudeCode.rawValue) }
            .sheet(isPresented: $showClaudeCodeConfigSheet) {
                ClaudeCodeConfigView( // Corrected call
                    isPresented: $showClaudeCodeConfigSheet,
                    customCliName: $viewModel.claudeCodeCustomCliName
                ) // Bind to viewModel property
                    { cliName in
                        _ = viewModel.mcpConfigManager.updateMCPConfiguration(
                            mcpIdentifier: MCPIdentifier.claudeCode.rawValue,
                            params: ["customCliName": cliName]
                        )
                        viewModel.refreshAllMCPStatusMessages()
                    }
            }

            // macOS Automator MCP
            MCPConfigurationEntryView(
                mcpName: "macOS Automator",
                mcpDescription: "Allows AI agents to execute AppleScripts and JXA (JavaScript for Automation) scripts to control macOS applications and system functions. Useful for automating repetitive tasks.",
                isEnabled: $viewModel.isMacOSAutomatorEnabled,
                statusMessageBinding: $viewModel.macOSAutomatorStatusMessage,
                detailsAction: { showMacAutomatorConfigSheet = true },
                warningTitle: "Enable macOS Automator MCP?",
                warningMessage: "Enabling the macOS Automator MCP allows CodeLooper to execute arbitrary AppleScripts or JavaScript for Automation (JXA) scripts. These scripts can control applications, access data, and perform a wide range of actions on your Mac. Only enable this if you understand the security implications and trust the scripts that will be executed."
            )                { viewModel.enableMCP(MCPIdentifier.macOSAutomator.rawValue) }
            .sheet(isPresented: $showMacAutomatorConfigSheet) {
                // Assuming a similar config view exists or will be created
                MacAutomatorConfigView(isPresented: $showMacAutomatorConfigSheet) // Placeholder
            }
            
            // XcodeBuild Integration MCP
            MCPConfigurationEntryView(
                mcpName: "XcodeBuild Integration",
                mcpDescription: "Provides capabilities to build, test, and analyze Xcode projects using xcodebuild commands. Useful for CI/CD-like tasks or automated project checks.",
                isEnabled: $viewModel.isXcodeBuildEnabled,
                statusMessageBinding: $viewModel.xcodeBuildStatusMessage,
                detailsAction: { showXcodeBuildConfigSheet = true },
                warningTitle: "Enable XcodeBuild MCP?",
                warningMessage: "Enabling the XcodeBuild MCP allows CodeLooper to execute xcodebuild commands. These commands can compile code, run tests, and interact with your Xcode projects. Ensure you understand the commands that will be run and their potential impact on your projects and system."
            )                { viewModel.enableMCP(MCPIdentifier.xcodeBuild.rawValue) }
            .sheet(isPresented: $showXcodeBuildConfigSheet) {
                // Assuming a similar config view exists or will be created
                XcodeBuildConfigView(isPresented: $showXcodeBuildConfigSheet) // Placeholder
            }

            Spacer()

            Divider()

            HStack {
                Button("View mcp.json File") {
                    let filePath = viewModel.mcpConfigManager.getMCPFilePath().path
                    if let url = URL(string: "file://" + filePath.replacingOccurrences(of: "~", with: NSHomeDirectory())) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("Reset All MCPs to Default") {
                    _ = viewModel.mcpConfigManager.clearMCPFile()
                    viewModel.refreshAllMCPStatusMessages()
                }
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            viewModel.refreshAllMCPStatusMessages()
        }
    }
}
