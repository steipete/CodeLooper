import DesignSystem
import SwiftUI

struct TreeContentView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?

    var body: some View {
        Group {
            if viewModel.isLoadingTree {
                LoadingView(message: "Loading Accessibility Tree...")
            } else if let errorMessage = viewModel.treeLoadingError {
                ErrorStateView(message: errorMessage)
            } else if viewModel.filteredAccessibilityTree.isEmpty {
                EmptyTreeView(
                    hasFilter: !viewModel.filterText.isEmpty,
                    filterText: viewModel.filterText,
                    hasSelectedApp: viewModel.selectedApplicationPID != nil
                )
            } else {
                ScrollViewReader { scrollViewProxy in
                    List(selection: $selectedNodeID) {
                        ForEach(viewModel.filteredAccessibilityTree) { rootNode in
                            RecursiveNodeView(
                                node: rootNode,
                                selectedNodeID: $selectedNodeID,
                                viewModel: viewModel
                            )
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: selectedNodeID) { _, newValue in
                        if viewModel.currentMode == .inspector, !viewModel.isHoverModeActive, let newID = newValue {
                            viewModel.selectedNode = viewModel.findNode(
                                by: newID,
                                in: viewModel.filteredAccessibilityTree
                            )
                        }
                    }
                    .onChange(of: viewModel.temporarilySelectedNodeIDByHover) { _, newValue in
                        if let idToScrollTo = newValue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollViewProxy.scrollTo(idToScrollTo, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}