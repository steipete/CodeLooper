import DesignSystem
import SwiftUI

struct ExternalMCPsSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text("MCP Extensions")
                        .font(Typography.headline())
                    Text("Manage Model Context Protocol extensions for enhanced Cursor capabilities")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Spacer()

                DSButton("Browse MCPs", icon: Image(systemName: "plus.app"), style: .primary, size: .small) {
                    showAddMCP = true
                }
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
                    Text("~/.cursor/mcp/")
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
        .sheet(isPresented: $showAddMCP) {
            MCPBrowserSheet()
        }
    }

    // MARK: Private

    @State private var installedMCPs: [MCPExtension] = [
        MCPExtension(
            id: UUID(),
            name: "Git MCP",
            version: "1.2.0",
            description: "Provides git operations directly in Cursor",
            enabled: true,
            icon: "git"
        ),
        MCPExtension(
            id: UUID(),
            name: "Database MCP",
            version: "0.9.1",
            description: "Query and manage databases from Cursor",
            enabled: true,
            icon: "database"
        ),
        MCPExtension(
            id: UUID(),
            name: "AWS MCP",
            version: "2.0.0",
            description: "Interact with AWS services",
            enabled: false,
            icon: "cloud"
        )
    ]

    @State private var showAddMCP = false
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
        let mcpPath = NSHomeDirectory() + "/.cursor/mcp/"
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

// MARK: - MCP Browser Sheet

private struct MCPBrowserSheet: View {
    @Environment(\.dismiss)
    var dismiss

    var body: some View {
        VStack(spacing: Spacing.large) {
            // Header
            HStack {
                Text("Browse MCP Extensions")
                    .font(Typography.title3())
                Spacer()
                Button(
                    action: { dismiss() },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                )
                .buttonStyle(.plain)
            }

            // Content placeholder
            VStack {
                Spacer()
                Text("MCP Browser coming soon...")
                    .font(Typography.body())
                    .foregroundColor(ColorPalette.textSecondary)
                Spacer()
            }

            // Actions
            HStack {
                DSButton("Close", style: .secondary) {
                    dismiss()
                }
            }
        }
        .padding(Spacing.large)
        .frame(width: 600, height: 400)
        .background(ColorPalette.background)
        .withDesignSystem()
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
