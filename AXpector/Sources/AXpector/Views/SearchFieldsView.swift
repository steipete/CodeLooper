import DesignSystem
import SwiftUI

struct SearchFieldsView: View {
    @ObservedObject var viewModel: AXpectorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            DSToggle("Display Name", isOn: $viewModel.searchInDisplayName)
            DSToggle("Role", isOn: $viewModel.searchInRole)
            DSToggle("Title", isOn: $viewModel.searchInTitle)
            DSToggle("Value", isOn: $viewModel.searchInValue)
            DSToggle("Description", isOn: $viewModel.searchInDescription)
            DSToggle("Path", isOn: $viewModel.searchInPath)
        }
        .padding(.leading, Spacing.small)
    }
}
