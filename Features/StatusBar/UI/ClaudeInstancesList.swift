import AppKit
import AXorcist
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct ClaudeInstancesList: View {
    // MARK: Internal
    
    @Default(.showDebugTab) private var showDebugInfo

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
                    ClaudeInstanceRow(instance: instance, showDebugInfo: showDebugInfo)
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
    let showDebugInfo: Bool

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
                    
                    // Status with icon
                    HStack(spacing: Spacing.xxSmall) {
                        Image(systemName: instance.status.icon)
                            .font(.caption2)
                            .foregroundColor(ColorPalette.textTertiary)
                        
                        Text(instance.status.displayName)
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textTertiary)
                            .lineLimit(1)
                    }
                    
                    // Current activity with enhanced visual design
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: instance.currentActivity.type.icon)
                                .font(.caption2)
                                .foregroundColor(activityColor(for: instance.currentActivity.type))
                            
                            Text("Activity:")
                                .font(Typography.caption2(.semibold))
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            // Show duration if available
                            if let duration = instance.currentActivity.duration {
                                Text("(\(Int(duration))s)")
                                    .font(Typography.caption2())
                                    .foregroundColor(ColorPalette.textTertiary)
                            }
                        }
                        
                        HStack(spacing: Spacing.xxSmall) {
                            Text(instance.currentActivity.text)
                                .font(Typography.caption1(.medium))
                                .foregroundColor(activityColor(for: instance.currentActivity.type))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            // Show token count if available
                            if let tokenCount = instance.currentActivity.tokenCount {
                                Text("\(formatTokenCount(tokenCount))")
                                    .font(Typography.caption2())
                                    .foregroundColor(ColorPalette.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(ColorPalette.backgroundTertiary)
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.leading, 16)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("PID: \(instance.pid)")
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    if !instance.ttyPath.isEmpty {
                        if showDebugInfo {
                            // Show full TTY path in debug mode
                            Text("TTY: \(instance.ttyPath)")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.textTertiary)
                        } else {
                            // Show just the TTY name normally
                            Text("TTY: \(URL(fileURLWithPath: instance.ttyPath).lastPathComponent)")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.textTertiary)
                        }
                    }
                    
                    // Show instance ID in debug mode
                    if showDebugInfo {
                        Text("ID: \(instance.id)")
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textTertiary)
                            .italic()
                    }
                }
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
            raiseTerminalWindow()
        }
    }
    
    // MARK: - Private
    
    private static let logger = Logger(category: .ui)
    @State private var isHovering = false
    
    // MARK: - Helper Functions
    
    private func activityColor(for type: ClaudeActivity.ActivityType) -> Color {
        switch type {
        case .idle:
            return ColorPalette.textTertiary
        case .working:
            return ColorPalette.loopTint
        case .generating:
            return ColorPalette.accent
        case .syncing:
            return .blue
        case .thinking:
            return .purple
        case .resolving:
            return .purple
        case .branching:
            return .orange
        case .compacting:
            return .green
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let kCount = Double(count) / 1000.0
            return String(format: "%.1fk", kCount)
        } else {
            return "\(count)"
        }
    }
    
    private func raiseTerminalWindow() {
        Self.logger.info("Attempting to raise terminal window for Claude instance PID: \(instance.pid), TTY: \(instance.ttyPath)")
        
        // If we have a TTY path, use the shared service to find the owning terminal window
        if !instance.ttyPath.isEmpty {
            if let window = TTYWindowMappingService.shared.findWindowForTTY(instance.ttyPath) {
                Self.logger.info("Found window for TTY \(instance.ttyPath), raising it")
                do {
                    try window.performAction(.raise)
                    
                    // Also activate the application
                    if let pid = window.pid() {
                        if let runningApp = NSRunningApplication(processIdentifier: pid) {
                            _ = runningApp.activate(options: .activateAllWindows)
                        }
                    }
                    
                    Self.logger.info("Successfully raised terminal window")
                    return
                } catch {
                    Self.logger.warning("Failed to raise window: \(error)")
                }
            }
        }
        
        // Fallback: Search by window title (less reliable)
        Self.logger.info("TTY-based search failed, falling back to title search")
        raiseTerminalWindowByTitle()
    }
    
    private func raiseTerminalWindowByTitle() {
        // Original title-based search as fallback
        let runningApps = NSWorkspace.shared.runningApplications
        
        
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            
            // Check if this is a terminal app using the list from shared service
            let terminalBundleIDs = [
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.github.wez.wezterm",
                "dev.warp.Warp-Stable",
                "net.kovidgoyal.kitty",
                "co.zeit.hyper",
                "com.mitchellh.ghostty",
                "com.brave.Browser",
                "com.google.Chrome",
                "org.mozilla.firefox"
            ]
            
            guard terminalBundleIDs.contains(bundleID) else { continue }
            
            guard let appElement = Element.application(for: app.processIdentifier) else { continue }
            guard let windows = appElement.windows() else { continue }
            
            for window in windows {
                if let title = window.title() {
                    if title.lowercased().contains(instance.folderName.lowercased()) ||
                       title.lowercased().contains("claude") ||
                       title.contains(instance.workingDirectory) {
                        Self.logger.info("Found matching terminal window by title: '\(title)'")
                        
                        do {
                            try window.performAction(.raise)
                            _ = app.activate(options: .activateAllWindows)
                            return
                        } catch {
                            Self.logger.warning("Failed to raise window: \(error)")
                        }
                    }
                }
            }
        }
        
        // Final fallback: Open the working directory in Finder
        Self.logger.info("Could not find terminal window, opening folder in Finder: \(instance.workingDirectory)")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: instance.workingDirectory)
    }
}
