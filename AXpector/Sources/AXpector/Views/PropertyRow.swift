import DesignSystem
import SwiftUI

struct PropertyRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
            Text(label)
                .font(Typography.caption1(.medium))
                .foregroundColor(ColorPalette.textSecondary)

            Text(value)
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)
                .textSelection(.enabled)
        }
    }
}
