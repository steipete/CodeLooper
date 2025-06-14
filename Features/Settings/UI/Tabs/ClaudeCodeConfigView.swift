import SwiftUI

/// Configuration view for Claude Code MCP (Model Context Protocol) integration.
///
/// ClaudeCodeConfigView allows users to:
/// - Configure custom CLI command names
/// - Set up aliases for Claude Code installation
/// - Verify CLI installation and functionality
/// - Customize integration settings
///
/// This view handles the configuration of how CodeLooper
/// interacts with the Claude Code command-line interface.
struct ClaudeCodeConfigView: View {
    // MARK: Internal

    @Binding var isPresented: Bool
    @Binding var customCliName: String // Bound to a property in MainSettingsViewModel

    var onSave: (String) -> Void // Action to save the new CLI name

    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Claude Code MCP")
                .font(.title2)
                .padding(.top)

            Text(
                "If you use a custom command for the Claude Code CLI (e.g., via an alias or a different " +
                    "installation method), you can specify it here. Otherwise, leave blank to use the default ('claude-code')."
            )
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

    // MARK: Private

    @State private var localCliName: String = ""
}

#if hasFeature(PreviewsMacros)
    #Preview {
        ClaudeCodeConfigView(isPresented: .constant(true), customCliName: .constant("claude-custom")) { name in
            print("Preview save: \(name)")
        }
    }
#endif
