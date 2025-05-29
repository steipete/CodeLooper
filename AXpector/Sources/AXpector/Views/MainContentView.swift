import DesignSystem
import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $viewModel.currentMode) {
                ForEach(AXpectorMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .top])
            .background(ColorPalette.background)

            switch viewModel.currentMode {
            case .inspector:
                NavigationView {
                    // Tree View
                    TreeSidebarView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
                        .frame(minWidth: 350)

                    // Details View
                    if let selectedNode = viewModel.selectedNode, !viewModel.isHoverModeActive {
                        NodeDetailsView(viewModel: viewModel, node: selectedNode)
                            .frame(minWidth: 400, maxWidth: .infinity)
                    } else {
                        EmptyStateView(
                            isHoverMode: viewModel.isHoverModeActive,
                            hasSelectedApp: viewModel.selectedApplicationPID != nil
                        )
                    }
                }
            case .observer:
                ObserverView(viewModel: viewModel)
            }
        }
        .frame(minHeight: 600, idealHeight: 800)
        .background(ColorPalette.background)
    }
}
