import DesignSystem
import SwiftUI

struct WelcomeStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()

            // Logo and header area
            VStack(spacing: Spacing.large) {
                // Animated logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorPalette.primary.opacity(0.2),
                                    ColorPalette.primaryLight.opacity(0.1),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                }
                .shadow(color: ColorPalette.primary.opacity(0.3), radius: 20, y: 10)

                VStack(spacing: Spacing.small) {
                    Text("Welcome to CodeLooper")
                        .font(Typography.largeTitle(.bold))
                        .foregroundColor(ColorPalette.text)

                    Text("Your intelligent AI assistant for Cursor IDE supervision")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.xLarge)
                }
            }

            // Features in cards
            VStack(spacing: Spacing.medium) {
                ModernFeatureCard(
                    icon: "brain.filled.head.profile",
                    iconColor: ColorPalette.primary,
                    title: "AI-Powered Monitoring",
                    description: "Advanced detection and automatic recovery from stuck states"
                )

                ModernFeatureCard(
                    icon: "wand.and.rays",
                    iconColor: ColorPalette.success,
                    title: "Intelligent Automation",
                    description: "Handles connection errors and UI conflicts automatically"
                )

                ModernFeatureCard(
                    icon: "lock.shield.fill",
                    iconColor: ColorPalette.info,
                    title: "Privacy-First Design",
                    description: "All processing happens locally on your Mac"
                )
            }
            .padding(.horizontal, Spacing.medium)

            Spacer()

            // Help link
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "questionmark.circle")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textTertiary)

                Link("Learn more", destination: URL(string: Constants.githubRepositoryURL)!)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.primary)
            }
            .padding(.bottom, Spacing.medium)
        }
        .frame(maxWidth: 600)
        .padding(.horizontal, Spacing.xLarge)
    }
}
