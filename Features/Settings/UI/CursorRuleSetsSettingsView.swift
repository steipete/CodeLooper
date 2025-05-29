import Defaults
import DesignSystem
import SwiftUI

struct CursorRuleSetsSettingsView: View {
    // MARK: Internal

    @StateObject private var ruleCounter = RuleCounterManager.shared

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
                VStack(spacing: Spacing.medium) {
                    ForEach(rules) { rule in
                        RuleCard(
                            rule: rule, 
                            isSelected: selectedRule?.id == rule.id,
                            executionCount: ruleCounter.getCount(for: ruleKeyForRule(rule.name))
                        ) {
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
    
    private func ruleKeyForRule(_ ruleName: String) -> String {
        switch ruleName {
        case "Stop after 25 loops":
            return "StopAfter25LoopsRule"
        default:
            return ruleName
        }
    }
}

// MARK: - Rule Card

private struct RuleCard: View {
    // MARK: Internal

    let rule: InterventionRule
    let isSelected: Bool
    let executionCount: Int
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        DSCard(style: .filled) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // Main rule header
                HStack(spacing: Spacing.medium) {
                    // Status indicator with execution count
                    HStack(spacing: Spacing.small) {
                        Circle()
                            .fill(rule.enabled ? ColorPalette.success : ColorPalette.textTertiary)
                            .frame(width: 8, height: 8)
                        
                        // Execution counter badge
                        Text("\(executionCount)")
                            .font(Typography.caption1(.semibold))
                            .foregroundColor(ColorPalette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorPalette.accent.opacity(0.1))
                            .cornerRadius(4)
                    }

                    // Rule info
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text(rule.name)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)

                        Text(rule.description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
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
                
                // Trigger -> Action flow
                HStack(spacing: Spacing.small) {
                    DSBadge(rule.trigger.displayName, style: .info)
                        .frame(width: 140, alignment: .center)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textTertiary)
                    DSBadge(rule.action.displayName, style: .primary)
                        .frame(width: 140, alignment: .center)
                }
                
                // On execution settings (always show)
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("On execution")
                        .font(Typography.caption2(.medium))
                        .foregroundColor(ColorPalette.textSecondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: Spacing.medium) {
                        // Sound picker
                        CompactSoundPicker(ruleName: rule.name)
                        
                        Spacer()
                        
                        // Notification checkbox
                        HStack(spacing: Spacing.xSmall) {
                            Button(action: {
                                toggleNotification(for: rule.name)
                            }) {
                                Image(systemName: getNotificationEnabled(for: rule.name) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(getNotificationEnabled(for: rule.name) ? ColorPalette.accent : ColorPalette.textSecondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            
                            Text("Notify")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.text)
                        }
                    }
                }
                .padding(.top, Spacing.xSmall)
            }
        }
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: Private

    @State private var isHovered = false
    @State private var showPopover = false
    @Default(.enableRuleNotifications) private var enableRuleNotifications
    
    private func toggleNotification(for ruleName: String) {
        // For now, toggle global setting. In the future, this could be per-rule
        enableRuleNotifications.toggle()
    }
    
    private func getNotificationEnabled(for ruleName: String) -> Bool {
        // For now, use global setting. In the future, this could be per-rule
        return enableRuleNotifications
    }
}

// MARK: - Compact Sound Picker

private struct CompactSoundPicker: View {
    // MARK: Internal

    let ruleName: String

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            // Sound icon and picker button
            Button(action: {
                isShowingPicker.toggle()
            }) {
                HStack(spacing: Spacing.xSmall) {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(currentSound.isEmpty ? ColorPalette.textSecondary : ColorPalette.accent)
                        .font(.system(size: 14))
                    
                    Text(currentSound.isEmpty ? "None" : currentSound)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.text)
                }
                .padding(.horizontal, Spacing.xSmall)
                .padding(.vertical, 2)
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
                CompactSoundPickerPopover(
                    selectedSound: Binding(
                        get: { currentSound },
                        set: { newValue in setSound(newValue) }
                    ),
                    isPresented: $isShowingPicker
                )
            }
            
            // Play button (only show if sound is selected)
            if !currentSound.isEmpty {
                Button(action: {
                    playSound()
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(ColorPalette.accent)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Private

    @State private var isShowingPicker = false
    @Default(.stopAfter25LoopsRuleSound) private var stopAfter25Sound
    @Default(.plainStopRuleSound) private var plainStopSound
    @Default(.connectionIssuesRuleSound) private var connectionIssuesSound
    @Default(.editedInAnotherChatRuleSound) private var editedInAnotherChatSound
    
    private var currentSound: String {
        switch ruleName {
        case "Stop after 25 loops":
            return stopAfter25Sound
        case "Plain Stop":
            return plainStopSound
        case "Connection Issues":
            return connectionIssuesSound
        case "Edited in another chat":
            return editedInAnotherChatSound
        default:
            return ""
        }
    }
    
    private func setSound(_ sound: String) {
        switch ruleName {
        case "Stop after 25 loops":
            Defaults[.stopAfter25LoopsRuleSound] = sound
        case "Plain Stop":
            Defaults[.plainStopRuleSound] = sound
        case "Connection Issues":
            Defaults[.connectionIssuesRuleSound] = sound
        case "Edited in another chat":
            Defaults[.editedInAnotherChatRuleSound] = sound
        default:
            break
        }
    }
    
    private func playSound() {
        guard !currentSound.isEmpty else { return }
        SoundEngine.playSystemSound(named: currentSound)
    }
}

// MARK: - Compact Sound Picker Popover

private struct CompactSoundPickerPopover: View {
    // MARK: Internal
    
    @Binding var selectedSound: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Select Alert Sound")
                .font(Typography.callout(.semibold))
                .foregroundColor(ColorPalette.text)

            ScrollView {
                LazyVStack(spacing: Spacing.xxSmall) {
                    // None option
                    SoundOptionRow(
                        soundName: "",
                        displayName: "None",
                        isSelected: selectedSound.isEmpty
                    ) {
                        selectedSound = ""
                        isPresented = false
                    }
                    
                    // System sounds
                    ForEach(popularSounds) { sound in
                        SoundOptionRow(
                            soundName: sound.name,
                            displayName: sound.displayName,
                            isSelected: selectedSound == sound.name
                        ) {
                            selectedSound = sound.name
                            SoundEngine.playSystemSound(named: sound.name)
                            isPresented = false
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(Spacing.medium)
        .frame(width: 200)
    }
}

// MARK: - Sound Option Row

private struct SoundOptionRow: View {
    let soundName: String
    let displayName: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: soundName.isEmpty ? "speaker.slash" : "speaker.wave.2")
                    .foregroundColor(soundName.isEmpty ? ColorPalette.textSecondary : ColorPalette.accent)
                    .font(.system(size: 12))
                    .frame(width: 16)

                Text(displayName)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ColorPalette.accent)
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? ColorPalette.accent.opacity(0.1) : Color.clear)
        )
    }
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
