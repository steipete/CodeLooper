import AppKit
import SwiftUI

struct DebugJSPopover: View {
    // MARK: Internal
    
    let window: MonitoredWindowInfo
    let viewModel: CursorInputWatcherViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug JavaScript Functions")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Window: \(window.windowTitle ?? "Unknown")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Built-in commands
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                DebugButton("Ping", "network") {
                    await executeCommand(["type": "ping"])
                }
                
                DebugButton("Version", "info.circle") {
                    await executeCommand(["type": "getVersion"])
                }
                
                DebugButton("System Info", "desktopcomputer") {
                    await executeCommand(["type": "getSystemInfo"])
                }
                
                DebugButton("Active Element", "cursorarrow.click.2") {
                    await executeCommand(["type": "getActiveElement"])
                }
                
                DebugButton("Check Resume", "play.circle") {
                    await executeCommand(["type": "checkResumeNeeded"])
                }
                
                DebugButton("Click Resume", "play.fill") {
                    await executeCommand(["type": "clickResume"])
                }
                
                DebugButton("Start Composer Observer", "eye") {
                    await executeCommand(["type": "startComposerObserver"])
                }
                
                DebugButton("Stop Composer Observer", "eye.slash") {
                    await executeCommand(["type": "stopComposerObserver"])
                }
                
                DebugButton("Get Composer Content", "text.quote") {
                    await executeCommand(["type": "getComposerContent"])
                }
            }
            
            Divider()
            
            // Custom notification
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Notification:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Message", text: $customMessage)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send") {
                        Task {
                            await executeCommand([
                                "type": "showNotification",
                                "message": customMessage,
                                "showToast": true
                            ])
                        }
                    }
                    .disabled(isExecuting || customMessage.isEmpty)
                }
            }
            
            Divider()
            
            // Result display
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Last Result:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(lastResult, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(lastResult.isEmpty)
                    .help("Copy to clipboard")
                }
                
                ScrollView {
                    Text(lastResult.isEmpty ? "No result yet" : lastResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(lastResult.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .frame(width: 350)
    }
    
    // MARK: Private
    
    @State private var customMessage = "debug test"
    @State private var lastResult = ""
    @State private var isExecuting = false
    
    @ViewBuilder
    private func DebugButton(_ title: String, _ icon: String, action: @escaping () async -> Void) -> some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isExecuting)
    }
    
    private func executeCommand(_ command: [String: Any]) async {
        guard viewModel.checkHookStatus(for: window) else {
            lastResult = "Error: No active hook for this window"
            return
        }
        
        isExecuting = true
        defer { isExecuting = false }
        
        do {
            let result = try await viewModel.jsHookManager.sendCommand(command, to: window.id)
            lastResult = result
        } catch {
            lastResult = "Error: \(error.localizedDescription)"
        }
    }
}