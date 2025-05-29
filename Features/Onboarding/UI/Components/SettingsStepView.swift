import DesignSystem
import SwiftUI

struct SettingsStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()

            // Header
            VStack(spacing: Spacing.large) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorPalette.success.opacity(0.2),
                                    ColorPalette.success.opacity(0.1),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 45))
                        .foregroundColor(ColorPalette.success)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: ColorPalette.success.opacity(0.2), radius: 15, y: 5)

                VStack(spacing: Spacing.small) {
                    Text("Initial Setup")
                        .font(Typography.title2(.bold))
                        .foregroundColor(ColorPalette.text)

                    Text("Configure your preferences. You can change these anytime in settings.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.large)
                }
            }

            // Settings cards
            VStack(spacing: Spacing.medium) {
                // Launch at login
                DSCard(style: .outlined) {
                    HStack(spacing: Spacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                                .fill(ColorPalette.loopTint.opacity(0.1))
                                .frame(width: 40, height: 40)

                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(ColorPalette.loopTint)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Launch at Login")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.text)

                            Text("Start CodeLooper automatically when you log in")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                        }

                        Spacer()

                        DSToggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.startAtLogin },
                                set: { viewModel.updateStartAtLogin($0) }
                            )
                        )
                    }
                }

                // Menu bar icon
                DSCard(style: .outlined) {
                    HStack(spacing: Spacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                                .fill(ColorPalette.info.opacity(0.1))
                                .frame(width: 40, height: 40)

                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(ColorPalette.info)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Menu Bar Access")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.text)

                            Text("Access CodeLooper from your menu bar")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ColorPalette.success)
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, Spacing.large)

            // Keyboard shortcut info
            DSCard(style: .filled) {
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "keyboard")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.loopTint)

                    Text("You can set up keyboard shortcuts in the settings after setup")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Spacer()
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, Spacing.large)

            Spacer()
        }
        .frame(maxWidth: 700)
    }
}
