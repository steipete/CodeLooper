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

                DSDivider()

                DSToggle(
                    "Auto-reload MCPs on changes",
                    isOn: .constant(true),
                    description: "Automatically reload extensions when configuration changes"
                )
            }

            Spacer()
        }
    }

    // MARK: Private

    @State private var installedMCPs: [MCPExtension] = [
        MCPExtension(
            id: UUID(),
            name: "👻 Peekaboo",
            version: "1.0.0",
            description: "Enables your IDE to make screenshots and ask questions about images",
            enabled: true,
            icon: "camera.viewfinder"
        ),
        MCPExtension(
            id: UUID(),
            name: "🤖 Terminator",
            version: "1.0.0",
            description: "Manages a Terminal outside of the loop, so processes that might get stuck don't break the loop",
            enabled: true,
            icon: "terminal"
        ),
        MCPExtension(
            id: UUID(),
            name: "🧠 Claude Code",
            version: "1.0.0",
            description: "A buddy for your IDE that your agent can ask if he's stuck. Can do coding task and offer \"a pair of fresh eyes\" that often un-stucks the loop",
            enabled: true,
            icon: "brain"
        ),
        MCPExtension(
            id: UUID(),
            name: "🐱 Conduit",
            version: "1.0.0",
            description: "Advanced file manipulation for faster refactoring",
            enabled: true,
            icon: "doc.text.magnifyingglass"
        ),
        MCPExtension(
            id: UUID(),
            name: "🎯 Automator",
            version: "1.0.0",
            description: "AppleScript for your IDE",
            enabled: true,
            icon: "applescript"
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
}

// MARK: - MCP Card

private struct MCPCard: View {
    // MARK: Internal

    let mcp: MCPExtension
    let isSelected: Bool
    let onToggle: () -> Void
    let onConfigure: () -> Void
    let onRemove: () -> Void

    var body: some View {
        DSCard(style: .outlined) {
            HStack(spacing: Spacing.medium) {
                // Icon
                Image(systemName: mcp.icon)
                    .font(.system(size: 24))
                    .foregroundColor(mcp.enabled ? ColorPalette.primary : ColorPalette.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(ColorPalette.backgroundSecondary)
                    .cornerRadiusDS(Layout.CornerRadius.medium)

                // Info
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    HStack(spacing: Spacing.xSmall) {
                        Text(mcp.name)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)

                        DSBadge("v\(mcp.version)", style: .default)

                        if !mcp.enabled {
                            DSBadge("Disabled", style: .warning)
                        }
                    }

                    Text(mcp.description)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Actions
                HStack(spacing: Spacing.small) {
                    Toggle("", isOn: .constant(mcp.enabled))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onTapGesture { onToggle() }

                    if isHovered {
                        Button(action: onConfigure) {
                            Image(systemName: "gearshape")
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .foregroundColor(ColorPalette.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(mcp.enabled ? 1.0 : 0.8)
    }

    // MARK: Private

    @State private var isHovered = false
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
