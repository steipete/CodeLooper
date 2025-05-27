import AppKit
import Combine
import Contacts
import Defaults
import SwiftUI

/// Shared section component for settings
struct SettingsSection<Content: View>: View {
    // MARK: Lifecycle

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    // MARK: Internal

    let title: String
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only use the title if it's not empty
            if !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            content
        }
        .padding(.bottom, 12)
    }
}
