import DesignSystem
import SwiftUI

struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.error)

            Text("Error Loading Tree")
                .font(Typography.headline())
                .foregroundColor(ColorPalette.text)

            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
