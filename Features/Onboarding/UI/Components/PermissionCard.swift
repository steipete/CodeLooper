import DesignSystem
import SwiftUI

struct PermissionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let content: () -> Content

    var body: some View {
        DSCard(style: .outlined) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                            .fill(iconColor.opacity(0.1))
                            .frame(width: 45, height: 45)

                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(iconColor)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text(title)
                            .font(Typography.body(.semibold))
                            .foregroundColor(ColorPalette.text)

                        Text(description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    Spacer()
                }

                content()
            }
        }
    }
}