import AXorcist
import DesignSystem
import SwiftUI

/// The main view for the AXpector accessibility inspector tool.
///
/// AXpectorView provides a complete interface for exploring and debugging
/// accessibility hierarchies in macOS applications. It includes:
/// - Permission checking and setup guidance
/// - Application selection and filtering
/// - Real-time accessibility tree visualization
/// - Element property inspection and editing
/// - Focus tracking and element highlighting
///
/// The view automatically checks for accessibility permissions and guides
/// the user through the setup process if needed.
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
