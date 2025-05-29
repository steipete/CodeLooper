import DesignSystem
import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.error)
            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}
