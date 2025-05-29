import DesignSystem
import SwiftUI

struct FilterHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("• Key-Value: key:value (e.g., role:button)")
                .font(Typography.caption2())
            Text("• Keys: role, title, value, desc, path, id")
                .font(Typography.caption2())
            Text("• Negation: !key:value or -key:value")
                .font(Typography.caption2())
            Text("• Regex: key:regex:pattern")
                .font(Typography.caption2())
            Text("• All criteria are ANDed")
                .font(Typography.caption2())
        }
        .foregroundColor(ColorPalette.textSecondary)
        .padding(.leading, Spacing.small)
    }
}