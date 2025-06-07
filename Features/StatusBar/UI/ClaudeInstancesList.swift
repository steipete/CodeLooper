import DesignSystem
import Diagnostics
import SwiftUI

struct ClaudeInstancesList: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)

                Text("Claude Instances (\(claudeMonitor.instances.count))")
                    .font(Typography.caption1(.semibold))
                    .foregroundColor(ColorPalette.text)
            }

            if claudeMonitor.instances.isEmpty {
                Text("No Claude instances detected")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.leading, 10)
            } else {
                ForEach(claudeMonitor.instances) { instance in
                    ClaudeInstanceRow(instance: instance)
                }
            }
        }
    }

    // MARK: Private

    @ObservedObject private var claudeMonitor = ClaudeMonitorService.shared
}

private struct ClaudeInstanceRow: View {
    // MARK: Internal

    let instance: ClaudeInstance

    var body: some View {
        DSCard {
            HStack(spacing: Spacing.small) {
                // Terminal icon
                Image(systemName: "terminal")
                    .foregroundColor(ColorPalette.loopTint)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    // Folder name
                    Text(instance.folderName)
                        .font(Typography.body(.medium))
                        .foregroundColor(ColorPalette.text)
                        .lineLimit(1)

                    // Working directory path
                    HStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "folder")
                            .font(.caption2)
                            .foregroundColor(isHovering ? ColorPalette.accent : ColorPalette.textSecondary)

                        Text(instance.workingDirectory)
                            .font(Typography.caption2())
                            .foregroundColor(isHovering ? ColorPalette.accent : ColorPalette.textSecondary)
                            .underline(isHovering, color: ColorPalette.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    // Status if available
                    if let status = instance.status {
                        Text(status)
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textTertiary)
                            .lineLimit(1)
                    }

                    // Current activity - always show since we now default to "idle"
                    if let activity = instance.currentActivity {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xxSmall) {
                                let statusIcon = activity == "idle" ? "zzz" : "dot.radiowaves.left.and.right"
                                let statusColor = activity == "idle" ? ColorPalette.textTertiary : ColorPalette.accent

                                Image(systemName: statusIcon)
                                    .font(.caption2)
                                    .foregroundColor(statusColor)

                                Text("Current Status:")
                                    .font(Typography.caption2(.semibold))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }

                            Text(activity)
                                .font(Typography.caption1(.medium))
                                .foregroundColor(activity == "idle" ? ColorPalette.textTertiary : ColorPalette.accent)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 16)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // PID
                Text("PID: \(instance.pid)")
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .opacity(isHovering ? 1.0 : 0.95)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            Self.logger.info("Opening Claude folder in Finder: \(instance.workingDirectory)")
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: instance.workingDirectory)
        }
    }

    // MARK: Private

    private static let logger = Logger(category: .ui)

    @State private var isHovering = false
}
