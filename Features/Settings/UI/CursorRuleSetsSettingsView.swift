import Defaults
import DesignSystem
import SwiftUI

/// Settings view for configuring intervention rules and automation behavior.
///
/// CursorRuleSetsSettingsView provides a clean interface for:
/// - Viewing and managing intervention rules
/// - Configuring rule triggers and actions
/// - Setting notification preferences per rule
/// - Viewing rule execution statistics
///
/// The view has been refactored to use extracted components for better
/// maintainability and reusability of UI elements.
struct CursorRuleSetsSettingsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            // Header section
            headerSection
            
            // Rules list
            rulesListSection
            
            // Info footer
            infoSection
        }
        .alert("Coming Soon", isPresented: $showNotImplementedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This feature is coming soon.")
        }
    }

    // MARK: Private

    @StateObject private var ruleCounter = RuleCounterManager.shared
    @State private var rules: [InterventionRule] = Self.defaultRules
    @State private var selectedRule: InterventionRule?
    @State private var showNotImplementedAlert = false
    @State private var attemptedRuleName = ""

    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
            Text("Intervention Rules")
                .font(Typography.headline())
                .foregroundColor(ColorPalette.text)
            
            Text("Define how CodeLooper should respond to different Cursor states")
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textSecondary)
        }
    }
    
    private var rulesListSection: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                ForEach(rules) { rule in
                    InterventionRuleCard(
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
    }
    
    private var infoSection: some View {
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

    // MARK: - Business Logic

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

// MARK: - Default Rules Configuration

private extension CursorRuleSetsSettingsView {
    static var defaultRules: [InterventionRule] {
        [
            InterventionRule(
                id: UUID(),
                name: "Stop after 25 loops",
                enabled: true,
                description: "It automatically presses resume. Note: By default, we stop the agent after 25 tool calls.",
                trigger: .generationTimeout,
                action: .clickResumeButton,
                technicalDetails: "Monitors tool call count and automatically intervenes when the limit is reached to prevent infinite loops."
            ),
            InterventionRule(
                id: UUID(),
                name: "Plain Stop",
                enabled: false,
                description: "Cursor just stops, even though the text indicates that there's more to do.",
                trigger: .stuckState,
                action: .clickResumeButton,
                technicalDetails: "Detects when generation unexpectedly stops despite incomplete work and resumes the process."
            ),
            InterventionRule(
                id: UUID(),
                name: "Connection Issues",
                enabled: false,
                description: "\"We're having trouble connecting to the model provider.\"",
                trigger: .connectionError,
                action: .clickResumeButton,
                technicalDetails: "Monitors for connection error messages and automatically attempts to resume the connection."
            ),
            InterventionRule(
                id: UUID(),
                name: "Edited in another chat",
                enabled: false,
                description: "Automatically accepts if another tab edited a file.",
                trigger: .sidebarInactive,
                action: .forceRefresh,
                technicalDetails: "Detects file conflicts from other tabs and automatically resolves them to maintain workflow continuity."
            ),
        ]
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