import Defaults
import DesignSystem
import SwiftUI

struct CursorRuleSetsSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text("Intervention Rules")
                    .font(Typography.headline())
                Text("Define how CodeLooper should respond to different Cursor states")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            // Rules List
            ScrollView {
                VStack(spacing: Spacing.small) {
                    ForEach(rules) { rule in
                        RuleCard(rule: rule, isSelected: selectedRule?.id == rule.id) {
                            selectedRule = rule
                        } onToggle: {
                            toggleRule(rule)
                        }
                    }
                }
            }

            // Info
            HStack {
                Spacer()
                Text("Rules are evaluated in order. The first matching rule will be applied.")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.top, Spacing.small)
        }
        .alert("Coming Soon", isPresented: $showNotImplementedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This feature is coming soon.")
        }
    }

    // MARK: Private

    @State private var rules: [InterventionRule] = [
        InterventionRule(
            id: UUID(),
            name: "Stop after 25 loops",
            enabled: true,
            description: "It automatically presses resume. Note: By default, we stop the agent after 25 tool calls.",
            trigger: .generationTimeout,
            action: .clickResumeButton
        ),
        InterventionRule(
            id: UUID(),
            name: "Plain Stop",
            enabled: false,
            description: "Cursor just stops, even though the text indicates that there's more to do.",
            trigger: .stuckState,
            action: .clickResumeButton
        ),
        InterventionRule(
            id: UUID(),
            name: "Connection Issues",
            enabled: false,
            description: "\"We're having trouble connecting to the model provider.\"",
            trigger: .connectionError,
            action: .clickResumeButton
        ),
        InterventionRule(
            id: UUID(),
            name: "Edited in another chat",
            enabled: false,
            description: "Automatically accepts if another tab edited a file.",
            trigger: .sidebarInactive,
            action: .forceRefresh
        ),
    ]

    @State private var selectedRule: InterventionRule?
    @State private var showNotImplementedAlert = false
    @State private var attemptedRuleName = ""

    private func toggleRule(_ rule: InterventionRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            // Check if trying to enable an unimplemented rule
            if !rules[index].enabled, rule.name != "Stop after 25 loops" {
                attemptedRuleName = rule.name
                showNotImplementedAlert = true
                return
            }
            rules[index].enabled.toggle()
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

    var body: some View {
        DSCard(style: .filled) {
            HStack(spacing: Spacing.medium) {
                // Status indicator
                Circle()
                    .fill(rule.enabled ? ColorPalette.success : ColorPalette.textTertiary)
                    .frame(width: 8, height: 8)

                // Rule info
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(rule.name)
                        .font(Typography.body(.medium))
                        .foregroundColor(ColorPalette.text)

                    Text(rule.description)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.bottom, Spacing.xxSmall)

                    HStack(spacing: Spacing.small) {
                        DSBadge(rule.trigger.displayName, style: .info)
                            .frame(width: 120, alignment: .center)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.textTertiary)
                        DSBadge(rule.action.displayName, style: .primary)
                            .frame(width: 120, alignment: .center)
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: Spacing.small) {
                    // Info button
                    if isHovered {
                        Button(action: {
                            showPopover = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(ColorPalette.textSecondary)
                        }
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
    @State private var showPopover = false
}

// MARK: - Rule Info Popover

private struct RuleInfoPopover: View {
    let rule: InterventionRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(rule.name)
                .font(Typography.headline())
                .padding(.bottom, Spacing.small)
            
            if let imageURL = rule.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 450)
                        .cornerRadius(8)
                } placeholder: {
                    ProgressView()
                        .frame(width: 450, height: 300)
                }
            }
            
            Text(rule.description)
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.top, Spacing.small)
        }
        .padding(Spacing.large)
        .frame(minWidth: 450, maxWidth: 675)
        .background(ColorPalette.background)
    }
}

// MARK: - Add Rule Sheet

private struct AddRuleSheet: View {
    // MARK: Internal

    @Environment(\.dismiss)
    var dismiss

    let onAdd: (InterventionRule) -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            // Header
            HStack {
                Text("New Intervention Rule")
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
    
    var imageURL: URL? {
        // Images from https://github.com/steipete/CodeLooper
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
