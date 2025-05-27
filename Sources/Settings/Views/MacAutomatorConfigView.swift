import SwiftUI

struct MacAutomatorConfigView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "applescript.fill") // Or "text.badge.command"
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
                .padding(.top)

            Text("macOS Automator MCP Configuration")
                .font(.title2)

            Text(
                "This Model Context Protocol (MCP) server allows AI agents to control your Mac by executing AppleScript and JavaScript for Automation (JXA) scripts."
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Text("⚠️ Security Warning:")
                .font(.headline)
                .foregroundColor(.orange)

            Text(
                "Enabling this MCP grants significant control over your computer. Only use this feature if you fully understand the implications and trust the AI agents and scripts that will be interacting with it. Malicious scripts could potentially harm your system or compromise your data."
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            Button("Open User Scripts Directory") {
                let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
                    ".cursor/scripts",
                    isDirectory: true
                )
                NSWorkspace.shared.open(url)
            }
            .padding(.top)

            Spacer()

            Button("Done") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 450, height: 400) // Adjusted size
        .padding()
    }
}

#if DEBUG
    struct MacAutomatorConfigView_Previews: PreviewProvider {
        static var previews: some View {
            MacAutomatorConfigView(isPresented: .constant(true))
        }
    }
#endif
