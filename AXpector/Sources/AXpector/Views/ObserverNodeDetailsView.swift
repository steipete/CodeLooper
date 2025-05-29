import DesignSystem
import SwiftUI

struct ObserverNodeDetailsView: View {
    let node: AXPropertyNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text("Selected Element (Observer)")
                    .font(Typography.headline())
                    .foregroundColor(ColorPalette.text)

                PropertyRow(label: "Display Name", value: node.displayName)
                PropertyRow(label: "Role", value: node.role)
                PropertyRow(label: "Title", value: node.title.isEmpty ? "N/A" : node.title)
                PropertyRow(label: "Value", value: node.value.isEmpty ? "N/A" : node.value)
                PropertyRow(label: "Description", value: node.descriptionText.isEmpty ? "N/A" : node.descriptionText)
                PropertyRow(label: "Path", value: node.fullPath)

                if !node.attributes.isEmpty {
                    DSDivider()
                    Text("All Attributes (\(node.attributes.count)")
                        .font(Typography.subheadline(.semibold))
                        .foregroundColor(ColorPalette.text)
                        .padding(.top, Spacing.small)

                    ForEach(node.attributes.sorted { $0.key < $1.key }, id: \.key) { key, attrInfo in
                        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                            Text(key)
                                .font(Typography.caption1(.semibold))
                                .foregroundColor(ColorPalette.textSecondary)
                            Text(String(describing: attrInfo.value))
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.text)
                                .textSelection(.enabled)
                        }
                        .padding(.bottom, Spacing.xxSmall)
                    }
                }
            }
            .padding(Spacing.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaterialPalette.panelBackground) // Differentiate from main tree background
        .border(ColorPalette.border, width: 1)
    }
}
