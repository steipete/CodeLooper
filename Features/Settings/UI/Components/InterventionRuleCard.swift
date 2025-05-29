import Defaults
import DesignSystem
import SwiftUI

/// Card view for displaying and configuring individual intervention rules.
///
/// InterventionRuleCard provides:
/// - Rule status visualization (enabled/disabled, execution count)
/// - Rule name and description display
/// - Toggle control for enabling/disabling rules
/// - Info popover with detailed rule information
/// - Trigger → Action flow visualization
/// - Sound picker and notification settings
///
/// The card uses a responsive layout that adapts to different screen sizes
/// while maintaining consistent spacing and alignment.
struct InterventionRuleCard: View {
    // MARK: Lifecycle

    init(
        rule: InterventionRule,
        isSelected: Bool,
        executionCount: Int,
        onSelect: @escaping () -> Void,
        onToggle: @escaping () -> Void
    ) {
        self.rule = rule
        self.isSelected = isSelected
        self.executionCount = executionCount
        self.onSelect = onSelect
        self.onToggle = onToggle
    }

    // MARK: Internal

    let rule: InterventionRule
    let isSelected: Bool
    let executionCount: Int
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        DSCard(style: .filled) {
            VStack(spacing: Spacing.small) {
                // Row 1: Main rule header with consistent alignment
                HStack(alignment: .top, spacing: Spacing.medium) {
                    // Column 1: Status indicators (fixed width)
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        HStack(spacing: Spacing.small) {
                            Circle()
                                .fill(rule.enabled ? ColorPalette.success : ColorPalette.textTertiary)
                                .frame(width: 8, height: 8)

                            Text("\(executionCount)")
                                .font(Typography.caption1(.semibold))
                                .foregroundColor(ColorPalette.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorPalette.accent.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .frame(width: 60, alignment: .leading)

                    // Column 2: Rule content (flexible width)
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text(rule.name)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(rule.description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)

                    // Column 3: Actions (fixed width)
                    HStack(spacing: Spacing.small) {
                        if isHovered {
                            Button(action: {
                                showPopover = true
                            }, label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ColorPalette.textSecondary)
                                    .frame(width: 20, height: 20)
                            })
                            .buttonStyle(.plain)
                            .popover(isPresented: $showPopover) {
                                RuleInfoPopover(rule: rule)
                            }
                        }

                        Toggle("", isOn: .constant(rule.enabled))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onTapGesture { onToggle() }
                    }
                    .frame(width: 80, alignment: .trailing)
                }

                // Row 2: Trigger -> Action flow (centered with consistent spacing)
                HStack(spacing: Spacing.medium) {
                    Spacer()
                    DSBadge(rule.trigger.displayName, style: .info)
                        .frame(width: 140)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textTertiary)
                        .frame(width: 20)
                    DSBadge(rule.action.displayName, style: .primary)
                        .frame(width: 140)
                    Spacer()
                }

                // Row 3: Sound and notification controls (bottom left)
                HStack(spacing: Spacing.medium) {
                    // Sound picker
                    CompactSoundPicker(ruleName: rule.name)

                    // Notification checkbox
                    HStack(spacing: Spacing.xSmall) {
                        Button(action: {
                            toggleNotification(for: rule.name)
                        }, label: {
                            Image(systemName: getNotificationEnabled(for: rule.name) ? "checkmark.square.fill" :
                                "square")
                                .foregroundColor(getNotificationEnabled(for: rule.name) ? ColorPalette
                                    .accent : ColorPalette.textSecondary)
                                .font(.system(size: 16))
                        })
                        .buttonStyle(.plain)

                        Text("Notification")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.text)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
        }
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: Private

    @State private var isHovered = false
    @State private var showPopover = false

    // Per-rule notification settings
    @Default(.stopAfter25LoopsRuleNotification) private var stopAfter25LoopsNotification
    @Default(.plainStopRuleNotification) private var plainStopNotification
    @Default(.connectionIssuesRuleNotification) private var connectionIssuesNotification
    @Default(.editedInAnotherChatRuleNotification) private var editedInAnotherChatNotification

    private func toggleNotification(for ruleName: String) {
        switch ruleName {
        case "Stop after 25 loops":
            Defaults[.stopAfter25LoopsRuleNotification].toggle()
        case "Plain Stop":
            Defaults[.plainStopRuleNotification].toggle()
        case "Connection Issues":
            Defaults[.connectionIssuesRuleNotification].toggle()
        case "Edited in another chat":
            Defaults[.editedInAnotherChatRuleNotification].toggle()
        default:
            break
        }
    }

    private func getNotificationEnabled(for ruleName: String) -> Bool {
        switch ruleName {
        case "Stop after 25 loops":
            stopAfter25LoopsNotification
        case "Plain Stop":
            plainStopNotification
        case "Connection Issues":
            connectionIssuesNotification
        case "Edited in another chat":
            editedInAnotherChatNotification
        default:
            false
        }
    }
}

// MARK: - Supporting Types

/// Data model representing an intervention rule configuration.
struct InterventionRule: Identifiable, Hashable {
    let id: UUID
    var name: String
    var enabled: Bool
    var description: String
    var trigger: RuleTrigger
    var action: RuleAction
    var technicalDetails: String

    var imageURL: URL? {
        let baseURL = "https://raw.githubusercontent.com/steipete/CodeLooper/main/assets/"
        switch name {
        case "Stop after 25 loops":
            return URL(string: "\(baseURL)default-stop-25.png")
        case "Plain Stop":
            return URL(string: "\(baseURL)cursor-stopped.png")
        case "Connection Issues":
            return URL(string: "\(baseURL)trouble.png")
        case "Edited in another chat":
            return URL(string: "\(baseURL)edited-another-chat.png")
        default:
            return nil
        }
    }
}

enum RuleTrigger: String, CaseIterable, Hashable {
    case connectionError = "connection_error"
    case stuckState = "stuck_state"
    case generationTimeout = "generation_timeout"
    case sidebarInactive = "sidebar_inactive"

    // MARK: Internal

    var displayName: String {
        switch self {
        case .connectionError: "Connection Error"
        case .stuckState: "Stuck State"
        case .generationTimeout: "Generation Timeout"
        case .sidebarInactive: "Sidebar Inactive"
        }
    }
}

enum RuleAction: String, CaseIterable, Hashable {
    case clickResumeButton = "click_resume"
    case forceRefresh = "force_refresh"
    case stopGeneration = "stop_generation"
    case restartCursor = "restart_cursor"
    case sendNotification = "send_notification"

    // MARK: Internal

    var displayName: String {
        switch self {
        case .clickResumeButton: "Click Resume"
        case .forceRefresh: "Force Refresh"
        case .stopGeneration: "Stop Generation"
        case .restartCursor: "Restart Cursor"
        case .sendNotification: "Send Notification"
        }
    }
}
