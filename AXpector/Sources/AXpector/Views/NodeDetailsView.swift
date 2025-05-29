import DesignSystem
import SwiftUI

struct NodeDetailsView: View {
    @ObservedObject var viewModel: AXpectorViewModel

    let node: AXPropertyNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Details")
                        .font(Typography.title3(.semibold))
                        .foregroundColor(ColorPalette.text)

                    Text(node.displayName)
                        .font(Typography.headline())
                        .foregroundColor(ColorPalette.textSecondary)
                }

                DSDivider()

                // Properties
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    PropertyRow(label: "Role", value: node.role)
                    PropertyRow(label: "Title", value: node.title.isEmpty ? "N/A" : node.title)
                    PropertyRow(
                        label: "Description",
                        value: node.descriptionText.isEmpty ? "N/A" : node.descriptionText
                    )
                    PropertyRow(label: "Value", value: node.value.isEmpty ? "N/A" : node.value)
                    PropertyRow(label: "Path", value: node.fullPath)
                    PropertyRow(label: "AXElementRef", value: "\(node.axElementRef)")
                    PropertyRow(label: "PID", value: "\(node.pid)")
                }

                DSDivider()

                // Attributes
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("Attributes")
                            .font(Typography.headline())
                            .foregroundColor(ColorPalette.text)

                        Text("(\(node.attributes.count))")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    if let status = viewModel.attributeUpdateStatusMessage {
                        DSBadge(
                            text: status,
                            style: status.contains("Failed") || status.contains("Error") ? .error : .success
                        )
                    }

                    if node.attributes.isEmpty {
                        Text("No attributes available.")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            ForEach(node.attributes.sorted { $0.key < $1.key }, id: \.key) { key, value in
                                AttributeRowView(
                                    viewModel: viewModel,
                                    node: node,
                                    attributeKey: key,
                                    attributeValue: value
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.large)
        }
        .background(ColorPalette.background)
    }
}
