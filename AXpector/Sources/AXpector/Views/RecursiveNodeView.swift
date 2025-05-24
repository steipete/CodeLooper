import SwiftUI

@MainActor
struct RecursiveNodeView: View {
    @ObservedObject var node: AXPropertyNode // Now an ObservedObject
    @Binding var selectedNodeID: AXPropertyNode.ID?
    let viewModel: AXpectorViewModel // Pass viewModel for actions

    var body: some View {
        // Use node.hasChildrenAXProperty to determine if disclosure group should be shown
        // Children array (node.children) might be empty if not yet loaded.
        if node.hasChildrenAXProperty {
            DisclosureGroup(
                isExpanded: $node.isExpanded, // Bind to the node's own isExpanded state
                content: {
                    if node.isLoadingChildren {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading...").foregroundColor(.secondary)
                        }.padding(.leading, CGFloat((node.depth + 1) * 10))
                    } else {
                        ForEach(node.children) { childNode in
                            RecursiveNodeView(node: childNode, selectedNodeID: $selectedNodeID, viewModel: viewModel)
                        }
                    }
                },
                label: {
                    NodeLabel(node: node, selectedNodeID: $selectedNodeID, viewModel: viewModel)
                }
            )
            .onChange(of: node.isExpanded) { isNowExpanded in
                if isNowExpanded && node.hasChildrenAXProperty && !node.areChildrenFullyLoaded && !node.isLoadingChildren {
                    viewModel.expandNodeAndLoadChildren(node)
                }
            }
            .id(node.id) 
        } else {
            NodeLabel(node: node, selectedNodeID: $selectedNodeID, viewModel: viewModel)
                .id(node.id) 
        }
    }
} 