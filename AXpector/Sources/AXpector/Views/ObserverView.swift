import DesignSystem
import SwiftUI

struct ObserverView: View {
    // MARK: Internal

    @ObservedObject var viewModel: AXpectorViewModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Header Controls for Observer Mode
                VStack(spacing: Spacing.medium) {
                    ApplicationPickerView(viewModel: viewModel)

                    if viewModel.selectedApplicationPID != nil {
                        DSButton("Refresh Tree", style: .secondary, size: .small) {
                            Task {
                                await viewModel.fetchAccessibilityTreeForSelectedApp()
                            }
                        }
                        .disabled(viewModel.isLoadingTree)
                        .frame(maxWidth: .infinity)
                    }
                    // Filter field for observer mode
                    DSTextField(
                        "Filter tree...",
                        text: $viewModel.filterText, // Re-use existing filterText
                        showClearButton: true
                    )
                }
                .padding(Spacing.medium)
                .background(ColorPalette.backgroundSecondary)

                DSDivider()

                // Tree Content for Observer Mode
                Group { // Group to handle conditional logic for tree display
                    if viewModel.isLoadingTree {
                        LoadingView(message: "Loading Accessibility Tree...")
                    } else if let error = viewModel.treeLoadingError {
                        ErrorView(message: "Failed to load tree: \(error)")
                    } else if viewModel.selectedApplicationPID == nil {
                        EmptyStateView(message: "Select an application to view its accessibility tree.")
                    } else if viewModel.filteredAccessibilityTree.isEmpty,
                              !viewModel.filterText.isEmpty
                    { // Use filteredAccessibilityTree
                        EmptyStateView(message: "No elements match your filter: \"\(viewModel.filterText)\"")
                    } else if viewModel.accessibilityTree.isEmpty { // Check original tree if no filter
                        EmptyStateView(
                            message: "No accessibility elements found for the selected application, or the tree is empty."
                        )
                    } else {
                        // Pass the observer-specific selectedNodeID binding
                        TreeContentView(viewModel: viewModel, selectedNodeID: $observerSelectedNodeID)
                    }
                }
                .frame(minWidth: 300) // Ensure tree has some minimum width
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorPalette.background)

            // Observer Node Details View
            if let selectedID = observerSelectedNodeID,
               let node = viewModel.findNode(
                   by: selectedID,
                   in: viewModel.filteredAccessibilityTree.isEmpty && viewModel.filterText.isEmpty ? viewModel
                       .accessibilityTree : viewModel.filteredAccessibilityTree
               )
            {
                ObserverNodeDetailsView(node: node)
                    .frame(minWidth: 300) // Ensure details view has some minimum width
            } else {
                EmptyStateView(message: "Select an element from the tree to see its details.")
                    .frame(minWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Removed redundant background from HSplitView children, HSplitView itself has no background property
    }

    // MARK: Private

    @State private var observerSelectedNodeID: AXPropertyNode.ID?
}
