import AppKit
import AXorcist
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct CursorWindowsList: View {
    enum Style {
        case popover
        case settings
    }

    let style: Style
    @Default(.isGlobalMonitoringEnabled) private var isGlobalMonitoringEnabled
    @StateObject private var inputWatcherViewModel = CursorInputWatcherViewModel()
    @StateObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared

    private static let logger = Logger(category: .ui)

    var body: some View {
        VStack(alignment: .leading, spacing: style == .popover ? Spacing.small : Spacing.medium) {
            if style == .settings {
                Text("Active Cursor Windows")
                    .font(Typography.callout(.semibold))
                    .foregroundColor(ColorPalette.text)
            }

            if inputWatcherViewModel.cursorWindows.isEmpty {
                emptyStateView
            } else {
                ForEach(inputWatcherViewModel.cursorWindows) { window in
                    if let windowState = diagnosticsManager.windowStates[window.id] {
                        WindowRow(
                            windowState: windowState,
                            style: style,
                            isGlobalMonitoringEnabled: isGlobalMonitoringEnabled,
                            inputWatcherViewModel: inputWatcherViewModel
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        Text("No windows detected or ready for AI diagnostics.")
            .font(style == .popover ? Typography.caption1() : Typography.body())
            .foregroundColor(ColorPalette.textSecondary)
            .padding(.leading, style == .popover ? 10 : 0)
    }
}

// MARK: - Window Row Component

private struct WindowRow: View {
    let windowState: MonitoredWindowInfo
    let style: CursorWindowsList.Style
    let isGlobalMonitoringEnabled: Bool
    @ObservedObject var inputWatcherViewModel: CursorInputWatcherViewModel
    @ObservedObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared

    @State private var isHoveringFolderIcon = false
    @State private var isHoveringFolderName = false
    @State private var isHoveringDocument = false
    @State private var isHoveringCard = false
    @State private var isHoveringGitStatus = false
    @State private var showDebugPopover = false
    @State private var showMarkdownPopover = false

    private static let logger = Logger(category: .ui)

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: Spacing.small) {
                // Header row
                HStack(alignment: .top) {
                    windowIcon
                    windowInfo
                    Spacer()
                    jsHookStatus
                }

                // AI Status row
                if isGlobalMonitoringEnabled {
                    aiStatusRow
                }

                // AI Analysis details are now merged into aiStatusRow

                // Git repository info
                if let gitRepo = windowState.gitRepository {
                    gitRepositoryInfo(gitRepo)
                }
            }
        }
        .opacity(isGlobalMonitoringEnabled ? (isHoveringCard ? 1.0 : 0.95) : 0.6)
        .disabled(!isGlobalMonitoringEnabled)
        .contentShape(Rectangle())
        .scaleEffect(isHoveringCard ? 1.01 : 1.0)
        .shadow(
            color: isHoveringCard ? Color.black.opacity(0.08) : Color.black.opacity(0.04),
            radius: isHoveringCard ? 4 : 2,
            x: 0,
            y: isHoveringCard ? 1 : 1
        )
        .animation(.smooth(duration: 0.2), value: isHoveringCard)
        .onHover { hovering in
            isHoveringCard = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            raiseWindow()
        }
    }

    @ViewBuilder
    private var windowIcon: some View {
        Image(systemName: "window.ceiling")
            .foregroundColor(aiStatusColor(windowState.lastAIAnalysisStatus))
            .font(.system(size: style == .popover ? 14 : 16))
    }

    @ViewBuilder
    private var windowInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(windowState.windowTitle ?? "Untitled Window")
                .font(style == .popover ? Typography.body(.medium) : Typography.callout(.semibold))
                .foregroundColor(ColorPalette.text)
                .lineLimit(1)

            if let docPath = windowState.documentPath, !docPath.isEmpty {
                let pathExists = diagnosticsManager.documentPathExists(docPath)

                HStack(spacing: Spacing.xxSmall) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundColor(pathExists && isHoveringDocument ? ColorPalette.accent : ColorPalette
                            .textSecondary)

                    Text(docPath)
                        .font(Typography.caption2())
                        .foregroundColor(pathExists && isHoveringDocument ? ColorPalette.accent : ColorPalette
                            .textSecondary)
                        .underline(pathExists && isHoveringDocument, color: ColorPalette.accent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .scaleEffect(pathExists && isHoveringDocument ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringDocument)
                .if(pathExists) { view in
                    view
                        .onTapGesture {
                            openDocumentInFinder(path: docPath)
                        }
                        .onHover { isHovering in
                            isHoveringDocument = isHovering
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .help("Open in Finder")
                }
            }

            // Screen location with state (always show)
            Text(windowState.screenDescription)
                .font(Typography.caption2())
                .foregroundColor(ColorPalette.textTertiary)
        }
    }

    @ViewBuilder
    private var jsHookStatus: some View {
        let heartbeatStatus = inputWatcherViewModel.getHeartbeatStatus(for: windowState.id)
        let port = inputWatcherViewModel.getPort(for: windowState.id)
        let hasActiveHook = heartbeatStatus?.isAlive == true || port != nil

        HStack(spacing: Spacing.xxSmall) {
            if hasActiveHook {
                HStack(spacing: 2) {
                    if heartbeatStatus?.isAlive == true {
                        Image(systemName: "heart.fill")
                            .foregroundColor(ColorPalette.success)
                            .font(.system(size: 10))
                    }
                    if let port {
                        Text(":\(port)")
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                .help("JS Hook \(heartbeatStatus?.isAlive == true ? "active" : "installed") on port \(port ?? 0)")
            }

            if style == .settings {
                let injectionState = inputWatcherViewModel.getInjectionState(for: windowState.id)

                if hasActiveHook {
                    // Show debug icon when hooked and debug mode is on
                    if Defaults[.showDebugTab] {
                        Button(action: {
                            showDebugPopover = true
                        }) {
                            Image(systemName: "ladybug")
                                .font(.system(size: 12))
                                .foregroundColor(ColorPalette.primary)
                        }
                        .buttonStyle(.plain)
                        .help("Debug JavaScript Functions")
                        .popover(isPresented: $showDebugPopover) {
                            DebugJSPopover(window: windowState, viewModel: inputWatcherViewModel)
                        }
                    }

                    // Show markdown content viewer
                    Button(action: {
                        showMarkdownPopover = true
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(ColorPalette.primary)
                    }
                    .buttonStyle(.plain)
                    .help("View Sidebar Content")
                    .popover(isPresented: $showMarkdownPopover) {
                        MarkdownContentPopover(window: windowState, viewModel: inputWatcherViewModel)
                    }
                } else {
                    // Show inject button when not hooked
                    DSButton(
                        injectionState.isWorking ? injectionState.displayText : "Inject JS",
                        style: .secondary,
                        size: .small
                    ) {
                        Task {
                            await inputWatcherViewModel.injectJSHook(into: windowState)
                        }
                    }
                    .disabled(injectionState.isWorking)
                }
            }
        }
    }

    @ViewBuilder
    private var aiStatusRow: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundColor(aiStatusColor(windowState.lastAIAnalysisStatus))
                .help(windowState.lastAIAnalysisStatus.displayName)

            // Combine AI status and message in one line
            if let message = windowState.lastAIAnalysisResponseMessage, !message.isEmpty {
                Text("AI: \(message)")
                    .font(Typography.caption1())
                    .foregroundColor(windowState.lastAIAnalysisStatus == .error ? ColorPalette.error :
                        windowState.lastAIAnalysisStatus == .notWorking ? ColorPalette.warning :
                        ColorPalette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("AI: \(windowState.lastAIAnalysisStatus.displayName)")
                    .font(Typography.caption1())
                    .foregroundColor(windowState.lastAIAnalysisStatus != .off ? ColorPalette.text : ColorPalette
                        .textSecondary)
            }

            Spacer()

            if let timestamp = windowState.lastAIAnalysisTimestamp {
                Text(timestamp, style: .relative)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(.top, Spacing.xxSmall)
    }

    @ViewBuilder
    private var aiAnalysisDetails: some View {
        // Details are now merged into aiStatusRow
        EmptyView()
    }

    @ViewBuilder
    private func gitRepositoryInfo(_ gitRepo: GitRepository) -> some View {
        let repoPathExists = diagnosticsManager.documentPathExists(gitRepo.path)

        HStack(spacing: Spacing.xxSmall) {
            Image(systemName: style == .popover ? "folder" : "folder.badge.gearshape")
                .font(.caption)
                .foregroundColor(repoPathExists && isHoveringFolderIcon ? ColorPalette.accent : ColorPalette
                    .textSecondary)
                .scaleEffect(repoPathExists && isHoveringFolderIcon ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringFolderIcon)
                .if(repoPathExists) { view in
                    view
                        .onTapGesture {
                            openInFinder(path: gitRepo.path)
                        }
                        .onHover { isHovering in
                            isHoveringFolderIcon = isHovering
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }

            if style == .settings {
                Text(URL(fileURLWithPath: gitRepo.path).lastPathComponent)
                    .font(Typography.caption2())
                    .foregroundColor(repoPathExists && isHoveringFolderName ? ColorPalette.accent : ColorPalette
                        .textSecondary)
                    .underline(repoPathExists && isHoveringFolderName, color: ColorPalette.accent)
                    .scaleEffect(repoPathExists && isHoveringFolderName ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringFolderName)
                    .if(repoPathExists) { view in
                        view
                            .onTapGesture {
                                openInFinder(path: gitRepo.path)
                            }
                            .onHover { isHovering in
                                isHoveringFolderName = isHovering
                                if isHovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }
            }

            // Show project name in popover, branch in settings
            if style == .popover {
                Text(URL(fileURLWithPath: gitRepo.path).lastPathComponent)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)

                if let branch = gitRepo.currentBranch {
                    Text("•")
                        .foregroundColor(ColorPalette.textTertiary)
                    Text(branch)
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.primary)
                }
            } else if let branch = gitRepo.currentBranch {
                Text("•")
                    .foregroundColor(ColorPalette.textTertiary)
                Text(branch)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.primary)
            }

            if gitRepo.totalChangedFiles > 0 {
                Text("•")
                    .foregroundColor(ColorPalette.textTertiary)

                HStack(spacing: 2) {
                    Text("\(gitRepo.totalChangedFiles) changed")
                        .font(Typography.caption2())
                        .foregroundColor(isHoveringGitStatus ? ColorPalette.accent : ColorPalette.warning)
                        .underline(isHoveringGitStatus, color: ColorPalette.accent)

                    if style == .settings, gitRepo.dirtyFileCount > 0, gitRepo.untrackedFileCount > 0 {
                        Text("(\(gitRepo.dirtyFileCount)M, \(gitRepo.untrackedFileCount)U)")
                            .font(Typography.caption2())
                            .foregroundColor(isHoveringGitStatus ? ColorPalette.accent : ColorPalette.textSecondary)
                    }
                }
                .scaleEffect(isHoveringGitStatus ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringGitStatus)
                .onTapGesture {
                    openInGitClient(path: gitRepo.path)
                }
                .onHover { isHovering in
                    isHoveringGitStatus = isHovering
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .help("Open in Git client")
            } else if style == .popover {
                Text("• clean")
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.success)
            }
        }
        .padding(.top, 2)
    }

    private func aiStatusColor(_ status: AIAnalysisStatus) -> Color {
        switch status {
        case .working:
            ColorPalette.success
        case .notWorking:
            ColorPalette.error
        case .pending:
            ColorPalette.info
        case .error:
            ColorPalette.error
        case .off:
            ColorPalette.textTertiary
        case .unknown:
            ColorPalette.warning
        }
    }

    private func raiseWindow() {
        Self.logger.info("Tapped on window: \(windowState.windowTitle ?? windowState.id). Attempting to raise.")
        if let axElement = windowState.windowAXElement {
            do {
                try axElement.performAction(.raise)
                Self.logger.info("Successfully raised window: \(windowState.windowTitle ?? windowState.id)")
            } catch {
                Self.logger.warning("Failed to raise window: \(windowState.windowTitle ?? windowState.id): \(error)")
            }
        } else {
            Self.logger
                .warning("Cannot raise window: AXElement is nil for \(windowState.windowTitle ?? windowState.id)")
        }
    }

    private func openInFinder(path: String) {
        Self.logger.info("Opening folder in Finder: \(path)")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func openDocumentInFinder(path: String) {
        Self.logger.info("Opening document in Finder: \(path)")
        // For documents, we want to select the file itself in Finder
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func openInGitClient(path: String) {
        Self.logger.info("Opening repository in Git client: \(path)")
        if !GitClientLauncher.launchGitClient(for: path) {
            Self.logger.error("Failed to open Git client for repository: \(path)")
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct CursorWindowsList_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Popover style
                CursorWindowsList(style: .popover)
                    .frame(width: 400)
                    .padding()
                    .background(ColorPalette.background)
                    .previewDisplayName("Popover Style")

                // Settings style
                CursorWindowsList(style: .settings)
                    .frame(width: 600)
                    .padding()
                    .background(ColorPalette.background)
                    .previewDisplayName("Settings Style")
            }
            .withDesignSystem()
        }
    }
#endif
