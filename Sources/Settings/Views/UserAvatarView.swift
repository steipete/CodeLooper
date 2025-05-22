import SwiftUI

struct UserAvatarView: View {
    var userName: String?
    var userEmail: String
    var imageData: Data?
    var size: CGFloat = 40

    var body: some View {
        if let imageData, let uiImage = NSImage(data: imageData) {
            // Show image if available
            Image(nsImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 1)
                )
        } else {
            // Show initials if no image available
            Circle()
                .fill(profileColor)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundColor(.white)
                )
        }
    }

    // Generate initials from name or email
    private var initials: String {
        if let name = userName, !name.isEmpty {
            // Use up to two initials from name
            let components = name.components(separatedBy: .whitespacesAndNewlines)
            if components.count > 1, let first = components.first?.first, let last = components.last?.first {
                return "\(first)\(last)"
            } else if let firstChar = name.first {
                return String(firstChar)
            }
        }

        // Fallback to email initial
        if let initial = userEmail.first {
            return String(initial).uppercased()
        }

        // Ultimate fallback
        return "?"
    }

    // Generate deterministic color based on email
    private var profileColor: Color {
        // Simple hash of the email to generate a repeatable color
        let emailHash = userEmail.utf8.reduce(0) { $0 + Int($1) }

        // Use a set of pleasant colors
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .teal,
            Color(red: 0.2, green: 0.5, blue: 0.9),
            Color(red: 0.8, green: 0.4, blue: 0.2),
            Color(red: 0.5, green: 0.7, blue: 0.3),
            Color(red: 0.7, green: 0.3, blue: 0.8)
        ]

        // Select color based on hash
        return colors[abs(emailHash) % colors.count]
    }
}

#Preview {
    VStack(spacing: 20) {
        UserAvatarView(userName: "John Doe", userEmail: "john@example.com")
        UserAvatarView(userName: "Jane Smith", userEmail: "jane@example.com", size: 60)
        UserAvatarView(userName: nil, userEmail: "unknown@example.com", size: 45)
    }
    .padding()
}
