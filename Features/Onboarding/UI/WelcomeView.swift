import ApplicationServices
import AXorcist
import Defaults
import DesignSystem
import KeyboardShortcuts
import OSLog
import SwiftUI

// MARK: - Welcome View

struct WelcomeView: View {
    // Use ObservedObject instead of StateObject to allow creating a binding
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    ColorPalette.background,
                    ColorPalette.backgroundSecondary.opacity(0.3),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Progress bar at top
                ProgressBar(currentStep: viewModel.currentStep)
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.top, Spacing.large)
                    .padding(.bottom, Spacing.medium)

                // Step content
                ZStack {
                    if viewModel.currentStep == .welcome {
                        WelcomeStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .accessibility {
                        AccessibilityStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .settings {
                        SettingsStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .complete {
                        CompletionStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer with navigation
                if viewModel.currentStep != .complete {
                    ModernFooterView(viewModel: viewModel)
                        .padding(.horizontal, Spacing.xLarge)
                        .padding(.bottom, Spacing.large)
                }
            }
        }
        .withDesignSystem()
    }
}

#Preview {
    WelcomeView(viewModel: WelcomeViewModel(
        loginItemManager: LoginItemManager.shared,
        windowManager: nil // Preview doesn't need actual WindowManager
    ))
}
