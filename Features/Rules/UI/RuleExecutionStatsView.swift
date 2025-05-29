import Defaults
import DesignSystem
import SwiftUI

struct RuleExecutionStatsView: View {
    // MARK: Internal

    var body: some View {
        if showCounters, ruleCounter.totalRuleExecutions > 0 {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(ColorPalette.accent)
                        .font(.system(size: 16, weight: .semibold))

                    Text("Automation Rules")
                        .font(Typography.callout(.semibold))
                        .foregroundColor(ColorPalette.text)

                    Spacer()

                    Text("\(ruleCounter.totalRuleExecutions)")
                        .font(Typography.callout(.semibold))
                        .foregroundColor(ColorPalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ColorPalette.accent.opacity(0.1))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    ForEach(ruleCounter.executedRuleNames, id: \.self) { ruleName in
                        RuleStatsRow(ruleName: ruleName, count: ruleCounter.getCount(for: ruleName))
                    }
                }
            }
            .padding(Spacing.medium)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorPalette.accent.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: Private

    @StateObject private var ruleCounter = RuleCounterManager.shared

    @Default(.showRuleExecutionCounters) private var showCounters
}

struct RuleStatsRow: View {
    // MARK: Internal

    let ruleName: String
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: ruleIcon)
                .foregroundColor(ColorPalette.success)
                .font(.system(size: 14))
                .frame(width: 16)

            Text(displayName)
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)

            Spacer()

            HStack(spacing: 4) {
                Text("\(count)")
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.accent)

                Text("executions")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
    }

    // MARK: Private

    private var displayName: String {
        switch ruleName {
        case "StopAfter25LoopsRule":
            "Stop after 25 loops"
        case "ResumeAfter25":
            "Resume After 25s"
        default:
            ruleName
        }
    }

    private var ruleIcon: String {
        switch ruleName {
        case "StopAfter25LoopsRule":
            "stop.circle.fill"
        case "ResumeAfter25":
            "play.circle.fill"
        default:
            "gearshape.fill"
        }
    }
}

// MARK: - Compact version for status bar / menu

struct CompactRuleStatsView: View {
    // MARK: Internal

    var body: some View {
        if showCounters, ruleCounter.totalRuleExecutions > 0 {
            HStack(spacing: Spacing.xxSmall) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 12, weight: .semibold))

                Text("\(ruleCounter.totalRuleExecutions)")
                    .font(Typography.caption1(.semibold))
                    .foregroundColor(ColorPalette.accent)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ColorPalette.accent.opacity(0.1))
            .cornerRadius(6)
        }
    }

    // MARK: Private

    @StateObject private var ruleCounter = RuleCounterManager.shared

    @Default(.showRuleExecutionCounters) private var showCounters
}

// MARK: - Preview

#if DEBUG
    struct RuleExecutionStatsView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Main stats view
                RuleExecutionStatsView()
                    .padding()
                    .background(ColorPalette.backgroundTertiary)
                    .previewDisplayName("Rule Stats")
                    .onAppear {
                        // Add some test data
                        RuleCounterManager.shared.incrementCounter(for: "ResumeAfter25")
                        RuleCounterManager.shared.incrementCounter(for: "ResumeAfter25")
                        RuleCounterManager.shared.incrementCounter(for: "ResumeAfter25")
                    }

                // Compact version
                CompactRuleStatsView()
                    .padding()
                    .background(ColorPalette.backgroundTertiary)
                    .previewDisplayName("Compact Stats")
            }
            .withDesignSystem()
        }
    }
#endif
