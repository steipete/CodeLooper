import DesignSystem
import SwiftUI

struct ProgressBar: View {
    // MARK: Internal

    let currentStep: WelcomeStep

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorPalette.backgroundSecondary)
                    .frame(height: 8)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ColorPalette.primary,
                                ColorPalette.primaryLight,
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth(in: geometry.size.width), height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 8)
    }

    // MARK: Private

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let steps = WelcomeStep.allCases.count
        let currentIndex = CGFloat(currentStep.rawValue + 1)
        return (currentIndex / CGFloat(steps)) * totalWidth
    }
}
