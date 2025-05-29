import DesignSystem
import SwiftUI

/// Popover that displays detailed information about an intervention rule.
///
/// RuleInfoPopover provides:
/// - Technical details about how the rule works
/// - Trigger conditions and action descriptions
/// - Implementation status and notes
/// - Links to documentation or related settings
struct RuleInfoPopover: View {
    let rule: InterventionRule

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(rule.name)
                    .font(Typography.headline())
                    .foregroundColor(ColorPalette.text)

                Text(rule.description)
                    .font(Typography.body())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            DSDivider()

            // Technical Details
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("How it works")
                    .font(Typography.body(.semibold))
                    .foregroundColor(ColorPalette.text)

                Text(rule.technicalDetails)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DSDivider()

            // Trigger and Action details
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    Text("Trigger:")
                        .font(Typography.caption1(.semibold))
                        .foregroundColor(ColorPalette.text)

                    DSBadge(rule.trigger.displayName, style: .info)
                }

                HStack {
                    Text("Action:")
                        .font(Typography.caption1(.semibold))
                        .foregroundColor(ColorPalette.text)

                    DSBadge(rule.action.displayName, style: .primary)
                }
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: 300)
    }
}

#if DEBUG
    struct RuleInfoPopover_Previews: PreviewProvider {
        static var previews: some View {
            RuleInfoPopover(
                rule: InterventionRule(
                    id: UUID(),
                    name: "Stop after 25 loops",
                    enabled: true,
                    description: "It automatically presses resume. Note: By default, we stop the agent after 25 tool calls.",
                    trigger: .generationTimeout,
                    action: .clickResumeButton,
                    technicalDetails: "Monitors tool call count and automatically intervenes when the limit " +
                        "is reached to prevent infinite loops."
                )
            )
            .withDesignSystem()
        }
    }
#endif
