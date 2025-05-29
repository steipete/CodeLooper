import DesignSystem
import SwiftUI

struct EmptyStateView: View {
    var message: String? // Optional message for observer mode
    var isHoverMode: Bool = false
    var hasSelectedApp: Bool = false

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "sidebar.squares.left") // Generic icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(ColorPalette.textTertiary)

            if let message {
                Text(message)
                    .font(Typography.title3(.regular))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Original EmptyStateView logic
                if isHoverMode {
                    Text("Hover Inspecting Active")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Tree selection and details are disabled during hover inspect.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                } else if !hasSelectedApp {
                    Text("No Application Selected")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Select an application from the picker above to view its accessibility tree.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                } else {
                    Text("No Element Selected")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Select an element from the tree on the left to see its details.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}
