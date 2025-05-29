import DesignSystem
import SwiftUI

struct ModernFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                iconColor.opacity(0.15),
                                iconColor.opacity(0.05),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(title)
                    .font(Typography.body(.semibold))
                    .foregroundColor(ColorPalette.text)

                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(Spacing.medium)
        .background(ColorPalette.background)
        .cornerRadius(Layout.CornerRadius.medium)
        .shadow(color: ColorPalette.shadowLight, radius: 5, y: 2)
    }
}
