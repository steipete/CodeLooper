import DesignSystem
import SwiftUI

struct AccessibilityStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                // Header
                VStack(spacing: Spacing.large) {
                    // Icon with gradient background
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
                            .frame(width: 90, height: 90)

                        Image(systemName: "shield.checkered")
                            .font(.system(size: 45))
                            .foregroundColor(ColorPalette.primary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .shadow(color: ColorPalette.primary.opacity(0.2), radius: 15, y: 5)

                    VStack(spacing: Spacing.small) {
                        Text("Grant Required Permissions")
                            .font(Typography.title2(.bold))
                            .foregroundColor(ColorPalette.text)

                        Text("CodeLooper needs these permissions to monitor and assist with Cursor IDE")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, Spacing.large)
                    }
                }
                .padding(.top, Spacing.large)

                // Permissions cards
                VStack(spacing: Spacing.large) {
                    // Accessibility Permission
                    PermissionCard(
                        icon: "hand.tap.fill",
                        iconColor: ColorPalette.primary,
                        title: "Accessibility Access",
                        description: "Required to detect and interact with Cursor's UI elements"
                    ) {
                        PermissionsView(showTitle: false, compact: false)
                    }

                    // Automation Permission
                    PermissionCard(
                        icon: "gearshape.2.fill",
                        iconColor: ColorPalette.success,
                        title: "Automation Permission",
                        description: "Enables JavaScript injection and advanced Cursor control"
                    ) {
                        AutomationPermissionsView(showTitle: false, compact: false)
                    }

                    // Screen Recording Permission
                    PermissionCard(
                        icon: "rectangle.dashed.badge.record",
                        iconColor: ColorPalette.info,
                        title: "Screen Recording",
                        description: "Allows AI analysis of Cursor windows for intelligent assistance"
                    ) {
                        ScreenRecordingPermissionsView(showTitle: false, compact: false)
                    }

                    // Notification Permission
                    PermissionCard(
                        icon: "bell.badge.fill",
                        iconColor: ColorPalette.warning,
                        title: "Notifications",
                        description: "Get notified about important events and task completions"
                    ) {
                        NotificationPermissionsView(showTitle: false, compact: false)
                    }
                }
                .padding(.horizontal, Spacing.large)

                // Info box
                DSCard(style: .filled) {
                    HStack(spacing: Spacing.medium) {
                        Image(systemName: "info.circle.fill")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.info)

                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Privacy First")
                                .font(Typography.caption1(.medium))
                                .foregroundColor(ColorPalette.text)

                            Text("All permissions are used locally. No data leaves your Mac.")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.textSecondary)
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .frame(maxWidth: 700)
    }
}