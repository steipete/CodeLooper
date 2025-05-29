import DesignSystem
import SwiftUI

struct TreeSidebarView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?

    var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            VStack(spacing: Spacing.medium) {
                // Application Picker
                ApplicationPickerView(viewModel: viewModel)

                // Refresh Button
                if viewModel.selectedApplicationPID != nil {
                    DSButton("Refresh Tree", style: .secondary, size: .small) {
                        Task {
                            await viewModel.fetchAccessibilityTreeForSelectedApp()
                        }
                    }
                    .disabled(viewModel.isLoadingTree)
                    .frame(maxWidth: .infinity)
                }

                // Mode Controls
                ModeControlsView(viewModel: viewModel)

                // Search Field
                DSTextField(
                    "Filter tree (e.g., role:button title:Save)",
                    text: $viewModel.filterText,
                    showClearButton: true
                )

                // Filter Help
                DisclosureGroup("Filter Syntax Help") {
                    FilterHelpView()
                }
                .font(Typography.caption1())

                // Search Fields
                DisclosureGroup("Search Fields") {
                    SearchFieldsView(viewModel: viewModel)
                }
                .font(Typography.caption1())
            }
            .padding(Spacing.medium)
            .background(ColorPalette.backgroundSecondary)

            DSDivider()

            // Tree Content
            TreeContentView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
        }
        .background(ColorPalette.background)
    }
}
