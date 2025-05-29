import AXorcist
import DesignSystem
import SwiftUI

@MainActor
public struct AXpectorView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        // Check for Accessibility Permissions first
        if viewModel.isAccessibilityEnabled == nil {
            LoadingView(message: "Checking Accessibility Permissions...")
        } else if viewModel.isAccessibilityEnabled == false {
            PermissionRequiredView()
        } else {
            MainContentView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
        }
    }

    // MARK: Private

    @StateObject private var viewModel = AXpectorViewModel()
    @State private var selectedNodeID: AXPropertyNode.ID?
}

// MARK: - Preview

#if DEBUG
    struct AXpectorView_Previews: PreviewProvider {
        static var previews: some View {
            AXpectorView()
                .frame(width: 900, height: 700)
                .withDesignSystem()
        }
    }
#endif
