import DesignSystem
import SwiftUI

struct ModernFooterView: View {
    // MARK: Internal

    var viewModel: WelcomeViewModel

    var body: some View {
        HStack {
            // Back button
            if viewModel.currentStep != .welcome {
                DSButton("Back", style: .secondary) {
                    viewModel.goToPreviousStep()
                }
                .frame(width: 100)
            }

            Spacer()

            // Step indicator
            HStack(spacing: Spacing.small) {
                ForEach(WelcomeStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step == viewModel.currentStep ? ColorPalette.loopTint : ColorPalette.backgroundTertiary)
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: viewModel.currentStep)
                }
            }

            Spacer()

            // Continue button
            DSButton(continueButtonText(), style: .primary) {
                viewModel.goToNextStep()
            }
            .frame(width: viewModel.currentStep == .settings ? 150 : 130)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Private

    private func continueButtonText() -> String {
        switch viewModel.currentStep {
        case .welcome:
            "Get Started"
        case .settings:
            "Complete Setup"
        default:
            "Continue"
        }
    }
}
