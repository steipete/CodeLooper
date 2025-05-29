import DesignSystem
import SwiftUI

/// Picker view for selecting which application to inspect with AXpector.
///
/// ApplicationPickerView provides:
/// - Dropdown list of running applications with accessible windows
/// - Application icons and names for easy identification
/// - Automatic refresh when applications launch or quit
/// - Filtering to show only applications with accessibility support
///
/// The picker integrates with the view model to trigger accessibility
/// tree fetching when a new application is selected.
struct ApplicationPickerView: View {
    // MARK: Internal

    @ObservedObject var viewModel: AXpectorViewModel

    var body: some View {
        HStack {
            Text("Application")
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)

            Spacer()

            Menu {
                Button("Select Application") {
                    viewModel.selectedApplicationPID = nil
                }
                .disabled(viewModel.selectedApplicationPID == nil)

                Divider()

                ForEach(viewModel.runningApplications, id: \.processIdentifier) { app in
                    Button(action: {
                        viewModel.selectedApplicationPID = app.processIdentifier
                    }) {
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(app.localizedName ?? "Unknown App")
                            if app.processIdentifier == viewModel.selectedApplicationPID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xSmall) {
                    if let selectedApp = viewModel.runningApplications
                        .first(where: { $0.processIdentifier == viewModel.selectedApplicationPID }),
                        let icon = selectedApp.icon
                    {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(selectedAppName)
                        .font(Typography.body())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xSmall)
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: Private

    private var selectedAppName: String {
        if let pid = viewModel.selectedApplicationPID,
           let app = viewModel.runningApplications.first(where: { $0.processIdentifier == pid })
        {
            return app.localizedName ?? "Unknown App"
        }
        return "Select Application"
    }
}
