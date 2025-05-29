import DesignSystem
import SwiftUI

struct EmptyTreeView: View {
    // MARK: Internal

    let hasFilter: Bool
    let filterText: String
    let hasSelectedApp: Bool

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: hasFilter ? "magnifyingglass" : "tree")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.textTertiary)

            Text(emptyMessage)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Private

    private var emptyMessage: String {
        if hasFilter {
            "No elements match your filter: \"\(filterText)\""
        } else if !hasSelectedApp {
            "Select an application to inspect"
        } else {
            "Accessibility tree is empty or not available"
        }
    }
}