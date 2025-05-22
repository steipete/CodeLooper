import AppKit
import Combine
import Contacts
import Defaults
import SwiftUI

/// Radio button row component for settings options
struct RadioButtonRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.primary, lineWidth: 1)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(title)
                    .foregroundColor(.primary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
