import DesignSystem
import SwiftUI
@preconcurrency import UserNotifications

/// A view that displays notification permission status and allows granting permissions
public struct NotificationPermissionsView: View {
    // MARK: Lifecycle

    public init(showTitle: Bool = true, compact: Bool = false) {
        self.showTitle = showTitle
        self.compact = compact
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? Spacing.small : Spacing.medium) {
            if showTitle {
                Text("Notification Permissions")
                    .font(Typography.title3(.semibold))
                    .foregroundColor(ColorPalette.text)
            }

            HStack(spacing: Spacing.medium) {
                // Icon
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: compact ? 24 : 28))
                    .foregroundColor(permissionsManager.hasNotificationPermissions ? ColorPalette.success : ColorPalette
                        .warning)
                    .symbolRenderingMode(.hierarchical)

                // Text content
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(permissionsManager
                        .hasNotificationPermissions ? "Notifications Enabled" : "Notifications Not Enabled")
                        .font(Typography.body(.medium))
                        .foregroundColor(ColorPalette.text)

                    if !compact {
                        Text(permissionsManager.hasNotificationPermissions
                            ? "You'll receive notifications about important events"
                            : "Enable notifications to stay informed about CodeLooper's activities")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                // Action button
                if !permissionsManager.hasNotificationPermissions {
                    DSButton("Enable", style: .primary, size: compact ? .small : .medium) {
                        Task {
                            await permissionsManager.requestNotificationPermissions()
                        }
                    }
                } else if !compact {
                    // Show checkmark for granted permission
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ColorPalette.success)
                }
            }

            if !permissionsManager.hasNotificationPermissions, !compact {
                // Additional help text
                DSCard(style: .filled) {
                    HStack(spacing: Spacing.small) {
                        Image(systemName: "info.circle")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.info)

                        Text("Notifications help you stay informed when tasks complete or when intervention is needed.")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Private

    @StateObject private var permissionsManager = PermissionsManager.shared

    private let showTitle: Bool
    private let compact: Bool
}

// MARK: - Preview

#if DEBUG
    struct NotificationPermissionsView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: Spacing.large) {
                NotificationPermissionsView(showTitle: true, compact: false)
                    .padding()
                    .background(ColorPalette.background)

                Divider()

                NotificationPermissionsView(showTitle: false, compact: true)
                    .padding()
                    .background(ColorPalette.background)
            }
            .frame(width: 500)
            .withDesignSystem()
        }
    }
#endif
