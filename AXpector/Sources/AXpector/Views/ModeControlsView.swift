import DesignSystem
import SwiftUI

struct ModeControlsView: View {
    @ObservedObject var viewModel: AXpectorViewModel

    var body: some View {
        VStack(spacing: Spacing.small) {
            // Hover Mode
            DSButton(
                viewModel.isHoverModeActive ? "Stop Hover Inspect" : "Start Hover Inspect",
                style: viewModel.isHoverModeActive ? .primary : .secondary,
                size: .small
            ) {
                viewModel.toggleHoverMode()
            }
            .frame(maxWidth: .infinity)

            if !viewModel.hoveredElementInfo.isEmpty {
                Text(viewModel.hoveredElementInfo)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            // Focus Tracking
            DSButton(
                viewModel.isFocusTrackingModeActive ? "Stop Focus Tracking" : "Start Focus Tracking",
                style: viewModel.isFocusTrackingModeActive ? .primary : .secondary,
                size: .small
            ) {
                viewModel.toggleFocusTrackingMode()
            }
            .frame(maxWidth: .infinity)

            DSToggle(
                "Auto-select focused app",
                isOn: $viewModel.autoSelectFocusedApp
            )

            if !viewModel.focusedElementInfo.isEmpty {
                Text(viewModel.focusedElementInfo)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            // Display detailed focused element attributes
            if viewModel.isFocusTrackingModeActive, let attributesDesc = viewModel.focusedElementAttributesDescription {
                ScrollView {
                    Text(attributesDesc)
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.text)
                        .padding(Spacing.xSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorPalette.backgroundSecondary.opacity(0.5))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 150) // Limit height to prevent oversized view
                .padding(.top, Spacing.xSmall)
            }
        }
    }
}