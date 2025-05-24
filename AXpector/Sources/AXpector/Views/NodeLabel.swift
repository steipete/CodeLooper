import SwiftUI

@MainActor
struct NodeLabel: View {
    @ObservedObject var node: AXPropertyNode // Node might change (e.g. displayName if title updates)
    @Binding var selectedNodeID: AXPropertyNode.ID?
    @ObservedObject var viewModel: AXpectorViewModel // Observe viewModel for hover state
    
    private var isClickSelected: Bool {
        selectedNodeID == node.id
    }
    
    private var isHoverSelected: Bool {
        viewModel.isHoverModeActive && viewModel.temporarilySelectedNodeIDByHover == node.id
    }

    private var isFocusSelected: Bool {
        viewModel.isFocusTrackingModeActive && viewModel.temporarilySelectedNodeIDByFocus == node.id
    }

    var body: some View {
        HStack {
            if isFocusSelected {
                Image(systemName: "scope")
                    .foregroundColor(.green)
            } else if isHoverSelected {
                Image(systemName: "arrow.right.circle.fill") // Indicate hover selection
                    .foregroundColor(.orange)
            }
            Text(node.displayName)
        }
        .padding(.leading, CGFloat(node.depth * 10)) 
        .frame(maxWidth: .infinity, alignment: .leading) 
        .contentShape(Rectangle()) 
        .onTapGesture {
            if !viewModel.isHoverModeActive { 
                selectedNodeID = node.id
            }
            // If in hover mode, click does nothing to the main selection.
        }
        .background(
            Group {
                if isFocusSelected {
                    Color.green.opacity(0.3)
                } else if isHoverSelected {
                    Color.orange.opacity(0.3)
                } else if isClickSelected && !viewModel.isHoverModeActive && !viewModel.isFocusTrackingModeActive {
                    Color.accentColor.opacity(0.3)
                } else {
                    Color.clear
                }
            }
        )
    }
} 