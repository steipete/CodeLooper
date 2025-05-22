import SwiftUI

struct ClaudeCodeConfigView: View {
    @Binding var isPresented: Bool
    @Binding var customCliName: String // Bound to a property in MainSettingsViewModel
    var onSave: (String) -> Void // Action to save the new CLI name

    @State private var localCliName: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Claude Code MCP")
                .font(.title2)
                .padding(.top)

            Text("If you use a custom command for the Claude Code CLI (e.g., via an alias or a different installation method), you can specify it here. Otherwise, leave blank to use the default ('claude-code').")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Custom CLI Name (e.g., claude)", text: $localCliName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Text("Example: If your command is `claude --version`, enter `claude`.")
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    customCliName = localCliName
                    onSave(localCliName)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
        .onAppear {
            // Initialize localCliName with the current customCliName from the ViewModel
            localCliName = customCliName
        }
    }
}

#Preview {
    ClaudeCodeConfigView(isPresented: .constant(true), customCliName: .constant("claude-custom"), onSave: { name in print("Preview save: \(name)") })
} 