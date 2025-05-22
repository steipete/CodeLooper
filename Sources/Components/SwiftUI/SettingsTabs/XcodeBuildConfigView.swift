import SwiftUI

struct XcodeBuildConfigView: View {
    @Binding var isPresented: Bool
    @Binding var versionString: String
    @Binding var isIncrementalBuildsEnabled: Bool
    @Binding var isSentryDisabled: Bool
    var onSave: (String, Bool, Bool) -> Void

    // Local state for editing
    @State private var localVersionString: String = ""
    @State private var localIsIncrementalBuildsEnabled: Bool = false
    @State private var localIsSentryDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Configure XcodeBuild MCP")
                .font(.title2)
                .padding(.top)
            
            Text("Specify the version of XcodeBuildMCP to use and configure its behavior. These settings will be applied to the XcodeBuildMCP entry in your `~/.cursor/mcp.json` file.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            Form {
                TextField("Version String (e.g., 1.0.0):", text: $localVersionString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Toggle("Enable Incremental Builds", isOn: $localIsIncrementalBuildsEnabled)
                    .help("If supported by your XcodeBuildMCP version, this may speed up builds.")
                
                Toggle("Disable Sentry Reporting", isOn: $localIsSentryDisabled)
                    .help("Disable Sentry error reporting within XcodeBuildMCP, if applicable.")
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    // Update binding variables before calling onSave
                    versionString = localVersionString
                    isIncrementalBuildsEnabled = localIsIncrementalBuildsEnabled
                    isSentryDisabled = localIsSentryDisabled
                    onSave(localVersionString, localIsIncrementalBuildsEnabled, localIsSentryDisabled)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .frame(width: 450, height: 320)
        .padding()
        .onAppear {
            // Initialize local state with current values from ViewModel bindings
            localVersionString = versionString
            localIsIncrementalBuildsEnabled = isIncrementalBuildsEnabled
            localIsSentryDisabled = isSentryDisabled
        }
    }
}

#Preview {
    XcodeBuildConfigView(
        isPresented: .constant(true),
        versionString: .constant("1.2.3"),
        isIncrementalBuildsEnabled: .constant(true),
        isSentryDisabled: .constant(false),
        onSave: { version, incremental, sentry in
            print("Preview save: Version=\(version), Incremental=\(incremental), Sentry=\(sentry)")
        }
    )
} 