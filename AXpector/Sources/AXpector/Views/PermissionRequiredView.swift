import AXorcist
import DesignSystem
import SwiftUI

struct PermissionRequiredView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "lock.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(ColorPalette.error)

            Text("Accessibility Permissions Required")
                .font(Typography.title3(.semibold))
                .foregroundColor(ColorPalette.text)

            Text(
                "AXpector needs Accessibility permissions to inspect other applications. Please enable it for CodeLooper in System Settings."
            )
            .font(Typography.body())
            .foregroundColor(ColorPalette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 400)

            DSButton("Open Privacy & Security Settings", style: .primary) {
                if let url =
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                {
                    NSWorkspace.shared.open(url)
                }
                // Also request access to trigger the system prompt
                Task {
                    _ = await AXPermissionHelpers.requestPermissions()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}