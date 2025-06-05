import SwiftUI
import DesignSystem
import Diagnostics

struct ClaudeInstancesList: View {
    @ObservedObject private var claudeMonitor = ClaudeMonitorService.shared
    
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
}

private struct ClaudeInstanceRow: View {
    let instance: ClaudeInstance
    @State private var isHovering = false
    
    private static let logger = Logger(category: .ui)
    
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
                    
                    // Current activity if available
                    if let activity = instance.currentActivity {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundColor(ColorPalette.success)
                            
                            Text(activity)
                                .font(Typography.caption2(.medium))
                                .foregroundColor(ColorPalette.success)
                                .lineLimit(2)
                        }
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
}