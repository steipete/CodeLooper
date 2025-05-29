import DesignSystem
import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}