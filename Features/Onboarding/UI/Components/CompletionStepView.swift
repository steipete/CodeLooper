import DesignSystem
import SwiftUI

struct CompletionStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()

            // Success animation
            VStack(spacing: Spacing.large) {
                ZStack {
                    // Animated circles
                    Circle()
                        .fill(ColorPalette.success.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)

                    Circle()
                        .fill(ColorPalette.success.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)

                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorPalette.success,
                                    ColorPalette.success.opacity(0.8),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)

                    Image(systemName: "checkmark")
                        .font(.system(size: 45, weight: .bold))
                        .foregroundColor(.white)
                }
                .onAppear {
                    // Trigger animations
                }

                VStack(spacing: Spacing.small) {
                    Text("You're All Set!")
                        .font(Typography.largeTitle(.bold))
                        .foregroundColor(ColorPalette.text)

                    Text("CodeLooper is ready to supercharge your Cursor experience")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.large)
                }
            }

            // Summary cards
            VStack(spacing: Spacing.medium) {
                // Permissions granted
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20))
                        .foregroundColor(ColorPalette.success)

                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("All Permissions Granted")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)

                        Text("CodeLooper has the access it needs to assist you")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    Spacer()
                }
                .padding(Spacing.medium)
                .background(ColorPalette.success.opacity(0.1))
                .cornerRadius(Layout.CornerRadius.medium)

                // Menu bar access
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(ColorPalette.primary)

                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("Access from Menu Bar")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)

                        Text("Click the chain link icon in your menu bar anytime")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    Spacer()
                }
                .padding(Spacing.medium)
                .background(ColorPalette.primary.opacity(0.1))
                .cornerRadius(Layout.CornerRadius.medium)

                // Auto start reminder if enabled
                if viewModel.startAtLogin {
                    HStack(spacing: Spacing.medium) {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ColorPalette.info)

                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Auto-Start Enabled")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.text)

                            Text("CodeLooper will start automatically at login")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(Spacing.medium)
                    .background(ColorPalette.info.opacity(0.1))
                    .cornerRadius(Layout.CornerRadius.medium)
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, Spacing.large)

            Spacer()

            // Finish button
            DSButton("Start Using CodeLooper", style: .primary) {
                viewModel.finishOnboarding()
            }
            .frame(width: 250)

            // Pro tip
            Text("💡 Pro tip: Use ⌘+⇧+L to quickly toggle monitoring")
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textTertiary)
                .padding(.bottom, Spacing.large)
        }
        .frame(maxWidth: 700)
    }
}