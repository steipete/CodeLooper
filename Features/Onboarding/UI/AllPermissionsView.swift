import DesignSystem
import SwiftUI

/// A comprehensive view that displays all permission statuses
struct AllPermissionsView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Accessibility Permission
            PermissionRowView(
                title: "Accessibility",
                description: "Required to monitor and interact with Cursor",
                hasPermission: permissionsManager.hasAccessibilityPermissions
            ) {
                Task {
                    await permissionsManager.requestAccessibilityPermissions()
                }
            }

            DSDivider()

            // Automation Permission
            PermissionRowView(
                title: "Automation",
                description: "Required to control Cursor for advanced features",
                hasPermission: permissionsManager.hasAutomationPermissions,
                onGrantPermission: permissionsManager.openAutomationSettings
            )

            DSDivider()

            // Screen Recording Permission
            PermissionRowView(
                title: "Screen Recording",
                description: "Required to capture Cursor windows for AI analysis",
                hasPermission: permissionsManager.hasScreenRecordingPermissions,
                onGrantPermission: permissionsManager.openScreenRecordingSettings
            )

            DSDivider()

            // Notification Permission
            PermissionRowView(
                title: "Notifications",
                description: "Notify you about important events and completion of tasks",
                hasPermission: permissionsManager.hasNotificationPermissions
            ) {
                Task {
                    await permissionsManager.requestNotificationPermissions()
                }
            }
        }
    }

    // MARK: Private

    @StateObject private var permissionsManager = PermissionsManager.shared
}

// MARK: - Permission Row View

private struct PermissionRowView: View {
    let title: String
    let description: String
    let hasPermission: Bool
    let onGrantPermission: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            // Status icon
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(hasPermission ? ColorPalette.success : ColorPalette.warning)
                .font(.system(size: 20))

            // Text content
            VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                Text(title)
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.text)

                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()

            // Status or grant button
            if hasPermission {
                Text("Granted")
                    .font(Typography.caption1(.medium))
                    .foregroundColor(ColorPalette.success)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.xxSmall)
                    .background(ColorPalette.success.opacity(0.1))
                    .cornerRadiusDS(Layout.CornerRadius.small)
            } else {
                DSButton("Grant", style: .secondary, size: .small) {
                    onGrantPermission()
                }
            }
        }
        .padding(.vertical, Spacing.xxSmall)
    }
}

// MARK: - Preview

#if DEBUG
    struct AllPermissionsView_Previews: PreviewProvider {
        static var previews: some View {
            AllPermissionsView()
                .padding()
                .frame(width: 500)
                .background(Color(NSColor.windowBackgroundColor))
                .withDesignSystem()
        }
    }
#endif
