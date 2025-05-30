import AppKit
import SwiftUI

// Separate state class to isolate state updates and prevent AttributeGraph cycles
@MainActor
private class DebugPopoverState: ObservableObject {
    @Published var customMessage = "debug test"
    @Published var lastResult = ""
    @Published var isExecuting = false
}

struct DebugJSPopover: View {
    // MARK: Internal

    let window: MonitoredWindowInfo
    @ObservedObject var viewModel: CursorInputWatcherViewModel

    // Create a separate StateObject to isolate state updates
    @StateObject private var debugState = DebugPopoverState()

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
                debugButton("Ping", "network") {
                    await executeCommand(["type": "ping"])
                }

                debugButton("Version", "info.circle") {
                    await executeCommand(["type": "getVersion"])
                }

                debugButton("System Info", "desktopcomputer") {
                    await executeCommand(["type": "getSystemInfo"])
                }

                debugButton("Active Element", "cursorarrow.click.2") {
                    await executeCommand(["type": "getActiveElement"])
                }

                debugButton("Check Rule Needed", "play.circle") {
                    await executeCommand(["type": "checkRuleNeeded"])
                }

                debugButton("Click Resume", "play.fill") {
                    await executeCommand(["type": "clickResume"])
                }

                debugButton("Perform Rule", "gearshape.fill") {
                    await executeCommand(["type": "performRule"])
                }

                debugButton("Start Composer Observer", "eye") {
                    await executeCommand(["type": "startComposerObserver"])
                }

                debugButton("Stop Composer Observer", "eye.slash") {
                    await executeCommand(["type": "stopComposerObserver"])
                }

                debugButton("Get Composer Content", "text.quote") {
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
                    TextField("Message", text: $debugState.customMessage)
                        .textFieldStyle(.roundedBorder)

                    Button("Send") {
                        Task {
                            await executeCommand([
                                "type": "showNotification",
                                "message": debugState.customMessage,
                                "showToast": true,
                            ])
                        }
                    }
                    .disabled(debugState.isExecuting || debugState.customMessage.isEmpty)
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
                        NSPasteboard.general.setString(debugState.lastResult, forType: .string)
                    }, label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    })
                    .buttonStyle(.plain)
                    .disabled(debugState.lastResult.isEmpty)
                    .help("Copy to clipboard")
                }

                ScrollView {
                    Text(debugState.lastResult.isEmpty ? "No result yet" : debugState.lastResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(debugState.lastResult.isEmpty ? .secondary : .primary)
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

    @ViewBuilder
    private func debugButton(_ title: String, _ icon: String, action: @escaping () async -> Void) -> some View {
        Button(action: {
            Task {
                await action()
            }
        }, label: {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
        })
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(debugState.isExecuting)
    }

    private func executeCommand(_ command: [String: Any]) async {
        guard viewModel.checkHookStatus(for: window) else {
            debugState.lastResult = "Error: No active hook for this window"
            return
        }

        debugState.isExecuting = true
        defer {
            Task { @MainActor in
                debugState.isExecuting = false
            }
        }

        do {
            let result = try await viewModel.jsHookService.sendCommand(command, to: window.id)
            await MainActor.run {
                debugState.lastResult = result
            }
        } catch {
            await MainActor.run {
                debugState.lastResult = "Error: \(error.localizedDescription)"
            }
        }
    }
}
