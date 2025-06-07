import AXorcist
import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct CursorSupervisionSettingsView: View {
    // MARK: Internal

    @Default(.aiGlobalAnalysisIntervalSeconds)
    var aiGlobalAnalysisIntervalSeconds
    @Default(.isGlobalMonitoringEnabled)
    var isGlobalMonitoringEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // Input Watcher Section
            DSSettingsSection("Input Monitoring & AI Diagnostics") {
                DSToggle(
                    "Enable Cursor Supervision",
                    isOn: $isGlobalMonitoringEnabled,
                    description: "Master switch to enable/disable all CodeLooper supervision features for Cursor, " +
                        "including JS hooks and AI diagnostics.",
                    descriptionLineSpacing: 4
                )
                .onChange(of: isGlobalMonitoringEnabled) { _, newValue in
                    if newValue {
                        diagnosticsManager.enableLiveWatchingForAllWindows()
                    } else {
                        diagnosticsManager.disableLiveWatchingForAllWindows()
                    }
                }

                if !inputWatcherViewModel.statusMessage.isEmpty, isGlobalMonitoringEnabled {
                    Text(inputWatcherViewModel.statusMessage)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.top, Spacing.xxSmall)
                }

                cursorWindowsView

                // Update Interval
                if inputWatcherViewModel.isWatchingEnabled, !inputWatcherViewModel.cursorWindows.isEmpty {
                    DSDivider()
                        .padding(.vertical, Spacing.small)
                    DSSlider(
                        value: Binding(
                            get: { Double(aiGlobalAnalysisIntervalSeconds) },
                            set: { aiGlobalAnalysisIntervalSeconds = Int($0) }
                        ),
                        in: 5 ... 60,
                        step: 5,
                        label: "Update Interval",
                        showValue: true
                    ) { "\(Int($0))s" }

                    Text("Choosing a too quick interval might increase CPU load or token cost.")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.top, Spacing.xxSmall)
                }
            }

            // Claude Monitoring Section
            DSSettingsSection("Claude Instances") {
                Text("Monitor running Claude CLI instances and their current status")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)

                claudeInstancesView
            }

            Spacer()
        }
    }

    // MARK: Private

    @StateObject private var inputWatcherViewModel = CursorInputWatcherViewModel()
    @StateObject private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    @ObservedObject private var claudeMonitor = ClaudeMonitorService.shared

    @ViewBuilder
    private var cursorWindowsView: some View {
        if !inputWatcherViewModel.cursorWindows.isEmpty {
            DSDivider()
                .padding(.vertical, Spacing.small)

            CursorWindowsList(style: .settings)
        }
    }

    @ViewBuilder
    private var claudeInstancesView: some View {
        if !claudeMonitor.instances.isEmpty {
            DSDivider()
                .padding(.vertical, Spacing.small)

            ClaudeInstancesList()
        } else {
            Text("No Claude instances running")
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textTertiary)
                .padding(.top, Spacing.small)
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct CursorSupervisionSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            CursorSupervisionSettingsView()
                .frame(width: 550, height: 700)
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .withDesignSystem()
        }
    }
#endif
