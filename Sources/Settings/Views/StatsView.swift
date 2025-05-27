import AppKit
import Defaults
import Foundation
import SwiftUI

/// A view that displays application statistics
@MainActor
struct StatsView: View {
    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application Statistics")
                .font(.headline)

            Text("CodeLooper is running and ready to help with your coding tasks.")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A view controller that displays application statistics
@MainActor
class StatsViewController: NSViewController {
    // MARK: Internal

    // MARK: - View Lifecycle

    override func loadView() {
        view = NSHostingView(rootView: statsView)
        title = "Statistics"
    }

    // MARK: Private

    private let statsView = StatsView()
}

/// A preview provider for StatsView
#Preview {
    StatsView()
}
