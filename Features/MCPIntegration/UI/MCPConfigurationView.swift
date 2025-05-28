import Defaults
import DesignSystem
import SwiftUI

struct ExternalMCPsSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text("MCP Extensions")
                    .font(Typography.headline())
                Text("Manage Model Context Protocol extensions for enhanced Cursor capabilities")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineSpacing(3)
            }

            // Installed MCPs
            if installedMCPs.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    VStack(spacing: Spacing.small) {
                        ForEach(installedMCPs) { mcp in
                            MCPCard(
                                mcp: mcp,
                                isSelected: selectedMCP?.id == mcp.id,
                                onToggle: { toggleMCP(mcp) },
                                onConfigure: { configureMCP(mcp) },
                                onRemove: { removeMCP(mcp) }
                            )
                        }
                    }
                }
            }

            // Info Section
            DSSettingsSection("Configuration") {
                HStack {
                    Text("MCP Config Path")
                        .font(Typography.body())
                    Spacer()
                    Text("/Users/steipete/.cursor/mcp.json")
                        .font(Typography.monospaced(.small))
                        .foregroundColor(ColorPalette.textSecondary)

                    DSButton("Open", style: .tertiary, size: .small) {
                        openMCPConfigFolder()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            Task {
                await mcpVersionService.checkAllVersions()
                updateMCPVersions()
            }
        }
    }

    // MARK: Private
    
    @StateObject private var mcpVersionService = MCPVersionService.shared

    @State private var installedMCPs: [MCPExtension] = [
        MCPExtension(
            id: UUID(),
            name: "👻 Peekaboo",
            version: "1.0.0",
            description: "Enables your IDE to make screenshots and ask questions about images",
            enabled: true,
            icon: "camera.viewfinder",
            githubURL: "https://github.com/steipete/Peekaboo"
        ),
        MCPExtension(
            id: UUID(),
            name: "🤖 Terminator",
            version: "1.0.0",
            description: "Manages a Terminal outside of the loop, so processes that might get stuck don't break the loop",
            enabled: true,
            icon: "terminal",
            githubURL: "https://github.com/steipete/Terminator"
        ),
        MCPExtension(
            id: UUID(),
            name: "🧠 Claude Code",
            version: "1.0.0",
            description: "A buddy for your IDE that your agent can ask if he's stuck. Can do coding task and offer \"a pair of fresh eyes\" that often un-stucks the loop",
            enabled: true,
            icon: "brain",
            githubURL: "https://github.com/steipete/claude-code-mcp"
        ),
        MCPExtension(
            id: UUID(),
            name: "🐱 Conduit",
            version: "1.0.0",
            description: "Advanced file manipulation for faster refactoring",
            enabled: true,
            icon: "doc.text.magnifyingglass",
            githubURL: "https://github.com/steipete/conduit-mcp"
        ),
        MCPExtension(
            id: UUID(),
            name: "🎯 Automator",
            version: "1.0.0",
            description: "AppleScript for your IDE",
            enabled: true,
            icon: "applescript",
            githubURL: "https://github.com/steipete/macos-automator-mcp"
        ),
    ]

    @State private var selectedMCP: MCPExtension?

    private func toggleMCP(_ mcp: MCPExtension) {
        if let index = installedMCPs.firstIndex(where: { $0.id == mcp.id }) {
            installedMCPs[index].enabled.toggle()
        }
    }

    private func configureMCP(_ mcp: MCPExtension) {
        selectedMCP = mcp
        // Show configuration sheet
    }

    private func removeMCP(_ mcp: MCPExtension) {
        installedMCPs.removeAll { $0.id == mcp.id }
    }

    private func openMCPConfigFolder() {
        let mcpPath = "/Users/steipete/.cursor/mcp.json"
        if let url = URL(string: "file://" + mcpPath) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func updateMCPVersions() {
        for (index, mcp) in installedMCPs.enumerated() {
            if let extensionType = mapMCPToExtensionType(mcp) {
                let latestVersion = mcpVersionService.getLatestVersion(for: extensionType)
                installedMCPs[index].version = latestVersion.hasPrefix("v") ? String(latestVersion.dropFirst()) : latestVersion
            }
        }
    }
    
    private func mapMCPToExtensionType(_ mcp: MCPExtension) -> MCPExtensionType? {
        switch mcp.name {
        case let name where name.contains("Peekaboo"):
            return .peekaboo
        case let name where name.contains("Terminator"):
            return .terminator
        case let name where name.contains("Claude Code"):
            return .claudeCode
        case let name where name.contains("Conduit"):
            return .conduit
        case let name where name.contains("Automator"):
            return .automator
        default:
            return nil
        }
    }
}

// MARK: - MCP Card

private struct MCPCard: View {
    // MARK: Internal

    let mcp: MCPExtension
    let isSelected: Bool
    let onToggle: () -> Void
    let onConfigure: () -> Void
    let onRemove: () -> Void
    
    @StateObject private var mcpVersionService = MCPVersionService.shared

    var body: some View {
        Group {
            if let githubURL = mcp.githubURL, let url = URL(string: githubURL) {
                Link(destination: url) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(mcp.enabled ? 1.0 : 0.8)
    }

    // MARK: Private

    @State private var isHovered = false
    
    @ViewBuilder
    private var versionBadge: some View {
        if mcpVersionService.isChecking {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("...")
                    .font(Typography.caption2())
            }
            .frame(width: 60, alignment: .center)
        } else {
            let displayVersion = getDisplayVersion()
            let hasUpdate = checkForUpdate()
            
            DSBadge("v\(displayVersion)", style: hasUpdate ? .warning : .default)
                .frame(width: 60, alignment: .center)
        }
    }
    
    private func getDisplayVersion() -> String {
        guard let extensionType = mapMCPToExtensionType(mcp) else {
            return mcp.version
        }
        
        let latestVersion = mcpVersionService.getLatestVersion(for: extensionType)
        let cleanVersion = latestVersion.hasPrefix("v") ? String(latestVersion.dropFirst()) : latestVersion
        return cleanVersion.isEmpty ? mcp.version : cleanVersion
    }
    
    private func checkForUpdate() -> Bool {
        guard let extensionType = mapMCPToExtensionType(mcp) else {
            return false
        }
        return mcpVersionService.hasUpdate(for: extensionType)
    }
    
    private func mapMCPToExtensionType(_ mcp: MCPExtension) -> MCPExtensionType? {
        switch mcp.name {
        case let name where name.contains("Peekaboo"):
            return .peekaboo
        case let name where name.contains("Terminator"):
            return .terminator
        case let name where name.contains("Claude Code"):
            return .claudeCode
        case let name where name.contains("Conduit"):
            return .conduit
        case let name where name.contains("Automator"):
            return .automator
        default:
            return nil
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        DSCard(style: .filled) {
            HStack(spacing: Spacing.medium) {
                // Icon
                Image(systemName: mcp.icon)
                    .font(.system(size: 24))
                    .foregroundColor(mcp.enabled ? ColorPalette.primary : ColorPalette.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(ColorPalette.backgroundSecondary)
                    .cornerRadiusDS(Layout.CornerRadius.medium)

                // Info
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack(spacing: Spacing.xSmall) {
                        Text(mcp.name)
                            .font(Typography.body(.medium))
                            .foregroundColor(mcp.githubURL != nil ? ColorPalette.primary : ColorPalette.text)

                        Spacer()

                        if !mcp.enabled {
                            DSBadge("Disabled", style: .warning)
                        }

                        versionBadge
                    }

                    Text(mcp.description)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .lineSpacing(4)
                        .lineLimit(2)
                }

                Spacer()

                // Actions
                HStack(spacing: Spacing.small) {
                    // Reserved space for settings and delete buttons (shown on hover)
                    HStack(spacing: Spacing.small) {
                        Button(action: onConfigure) {
                            Image(systemName: "gearshape")
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .frame(width: 20, height: 20)

                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .foregroundColor(ColorPalette.error)
                        }
                        .buttonStyle(.plain)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .frame(width: 20, height: 20)
                    }
                    .frame(width: 48) // Fixed width to reserve space

                    Toggle("", isOn: .constant(mcp.enabled))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onTapGesture { onToggle() }
                }
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()

            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 64))
                .foregroundColor(ColorPalette.textTertiary)

            VStack(spacing: Spacing.xSmall) {
                Text("No MCP Extensions Installed")
                    .font(Typography.headline())
                    .foregroundColor(ColorPalette.text)

                Text("Browse and install Model Context Protocol extensions to enhance Cursor")
                    .font(Typography.body())
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Models

private struct MCPExtension: Identifiable {
    let id: UUID
    var name: String
    var version: String
    var description: String
    var enabled: Bool
    var icon: String
    var githubURL: String?
}

// MARK: - Preview

#if DEBUG
    struct ExternalMCPsSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            ExternalMCPsSettingsView()
                .frame(width: 600, height: 700)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
