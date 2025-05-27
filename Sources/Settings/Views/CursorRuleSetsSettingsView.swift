import Defaults
import DesignSystem
import SwiftUI

struct CursorRuleSetsSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text("Intervention Rules")
                        .font(Typography.headline())
                    Text("Define how CodeLooper should respond to different Cursor states")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Spacer()

                DSButton("Add Rule", icon: Image(systemName: "plus"), style: .primary, size: .small) {
                    showAddRule = true
                }
            }

            // Rules List
            ScrollView {
                VStack(spacing: Spacing.small) {
                    ForEach(rules) { rule in
                        RuleCard(rule: rule, isSelected: selectedRule?.id == rule.id) {
                            selectedRule = rule
                        } onToggle: {
                            toggleRule(rule)
                        } onDelete: {
                            deleteRule(rule)
                        }
                    }
                }
            }

            // Info
            DSCard(style: .filled) {
                HStack(spacing: Spacing.small) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(ColorPalette.warning)

                    Text("Rules are evaluated in order. The first matching rule will be applied.")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet(onAdd: { rule in
                rules.append(rule)
            })
        }
    }

    // MARK: Private

    @State private var rules: [InterventionRule] = [
        InterventionRule(
            id: UUID(),
            name: "Connection Error Recovery",
            enabled: true,
            description: "Automatically recover from connection errors",
            trigger: .connectionError,
            action: .clickResumeButton
        ),
        InterventionRule(
            id: UUID(),
            name: "Stuck State Detection",
            enabled: true,
            description: "Detect and resolve when Cursor becomes unresponsive",
            trigger: .stuckState,
            action: .forceRefresh
        ),
        InterventionRule(
            id: UUID(),
            name: "Long Generation Timeout",
            enabled: false,
            description: "Stop generations that take too long",
            trigger: .generationTimeout,
            action: .stopGeneration
        ),
    ]

    @State private var selectedRule: InterventionRule?
    @State private var showAddRule = false

    private func toggleRule(_ rule: InterventionRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled.toggle()
        }
    }

    private func deleteRule(_ rule: InterventionRule) {
        rules.removeAll { $0.id == rule.id }
        if selectedRule?.id == rule.id {
            selectedRule = nil
        }
    }
}

// MARK: - Rule Card

private struct RuleCard: View {
    // MARK: Internal

    let rule: InterventionRule
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        DSCard(style: isSelected ? .elevated : .outlined) {
            HStack(spacing: Spacing.medium) {
                // Status indicator
                Circle()
                    .fill(rule.enabled ? ColorPalette.success : ColorPalette.textTertiary)
                    .frame(width: 8, height: 8)

                // Rule info
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(rule.name)
                        .font(Typography.body(.medium))
                        .foregroundColor(ColorPalette.text)

                    Text(rule.description)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    HStack(spacing: Spacing.small) {
                        DSBadge(rule.trigger.displayName, style: .info)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.textTertiary)
                        DSBadge(rule.action.displayName, style: .primary)
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: Spacing.small) {
                    Toggle("", isOn: .constant(rule.enabled))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onTapGesture { onToggle() }

                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(ColorPalette.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: Private

    @State private var isHovered = false
}

// MARK: - Add Rule Sheet

private struct AddRuleSheet: View {
    // MARK: Internal

    @Environment(\.dismiss) var dismiss

    let onAdd: (InterventionRule) -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            // Header
            HStack {
                Text("New Intervention Rule")
                    .font(Typography.title3())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Form
            VStack(alignment: .leading, spacing: Spacing.medium) {
                DSTextField("Rule Name", text: $ruleName)
                DSTextField("Description", text: $ruleDescription)

                DSPicker(
                    "Trigger",
                    selection: $selectedTrigger,
                    options: RuleTrigger.allCases.map { ($0, $0.displayName) }
                )

                DSPicker(
                    "Action",
                    selection: $selectedAction,
                    options: RuleAction.allCases.map { ($0, $0.displayName) }
                )
            }

            Spacer()

            // Actions
            HStack {
                DSButton("Cancel", style: .secondary) {
                    dismiss()
                }

                DSButton("Add Rule", style: .primary) {
                    let rule = InterventionRule(
                        id: UUID(),
                        name: ruleName,
                        enabled: true,
                        description: ruleDescription,
                        trigger: selectedTrigger,
                        action: selectedAction
                    )
                    onAdd(rule)
                    dismiss()
                }
                .disabled(ruleName.isEmpty || ruleDescription.isEmpty)
            }
        }
        .padding(Spacing.large)
        .frame(width: 400, height: 350)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @State private var ruleName = ""
    @State private var ruleDescription = ""
    @State private var selectedTrigger: RuleTrigger = .connectionError
    @State private var selectedAction: RuleAction = .clickResumeButton
}

// MARK: - Models

private struct InterventionRule: Identifiable {
    let id: UUID
    var name: String
    var enabled: Bool
    var description: String
    var trigger: RuleTrigger
    var action: RuleAction
}

private enum RuleTrigger: String, CaseIterable {
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

private enum RuleAction: String, CaseIterable {
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

// MARK: - Preview

#if DEBUG
    struct CursorRuleSetsSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            CursorRuleSetsSettingsView()
                .frame(width: 600, height: 700)
                .padding()
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
