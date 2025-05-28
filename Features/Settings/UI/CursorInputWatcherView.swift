import Defaults
import SwiftUI

struct CursorInputWatcherView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            windowsSection
            inputsSection
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Private

    @StateObject private var viewModel = CursorInputWatcherViewModel()

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor Input Watcher")
                .font(.title)

            Toggle("Enable Live Watching", isOn: Binding(
                get: { viewModel.isWatchingEnabled },
                set: { newValue in
                    Defaults[.isGlobalMonitoringEnabled] = newValue
                }
            ))

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var windowsSection: some View {
        Group {
            if !viewModel.cursorWindows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cursor Windows")
                        .font(.headline)

                    ForEach(viewModel.cursorWindows, id: \.id) { window in
                        WindowRow(window: window, viewModel: viewModel)
                    }
                }
            }
        }
    }

    private var inputsSection: some View {
        Group {
            if !viewModel.watchedInputs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monitored Inputs")
                        .font(.headline)

                    ForEach(viewModel.watchedInputs) { input in
                        InputRow(input: input)
                    }
                }
            }
        }
    }
}

// MARK: - Window Row

private struct WindowRow: View {
    // MARK: Internal

    let window: MonitoredWindowInfo
    let viewModel: CursorInputWatcherViewModel
    
    @State private var showDebugPopover = false

    var body: some View {
        HStack {
            Image(systemName: "window.ceiling")
                .foregroundColor(.secondary)

            Text(window.windowTitle ?? "Untitled Window")
                .font(.system(.body, design: .monospaced))

            Spacer()

            windowStatus
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: Private

    @ViewBuilder
    private var windowStatus: some View {
        let injectionState = viewModel.getInjectionState(for: window.id)
        let isHooked = viewModel.hookedWindows.contains(window.id)

        if isHooked {
            HStack(spacing: 6) {
                // Green heart when hooked and has heartbeat
                if let heartbeat = viewModel.getHeartbeatStatus(for: window.id), heartbeat.isAlive {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.green)
                        .help("Active connection with heartbeat")
                } else if isHooked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .help("Hooked")
                } else {
                    Image(systemName: "heart")
                        .foregroundColor(.orange)
                        .help("Hooked but no heartbeat")
                }

                if let port = viewModel.getPort(for: window.id) {
                    Text("Port: \(port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let heartbeat = viewModel.getHeartbeatStatus(for: window.id) {
                    Circle()
                        .fill(heartbeat.isAlive ? .green : .red)
                        .frame(width: 6, height: 6)
                        .help(heartbeat.isAlive ? "Connected" : "Disconnected")
                }
            }
        } else {
            HStack(spacing: 4) {
                if injectionState.isWorking {
                    // Show progress indicator
                    ProgressView()
                        .scaleEffect(0.6)
                        .controlSize(.mini)

                    Text(injectionState.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Debug icon (only when debug tab is visible)
                    if Defaults[.showDebugTab] {
                        Button(action: {
                            showDebugPopover = true
                        }) {
                            Image(systemName: "ladybug")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Debug JavaScript Functions")
                        .popover(isPresented: $showDebugPopover) {
                            DebugJSPopover(window: window, viewModel: viewModel)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.injectJSHook(into: window)
                        }
                    }) {
                        switch injectionState {
                        case .idle:
                            Text("Inject Hook")
                        case .failed:
                            Text("Retry Hook")
                        default:
                            Text("Working...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(injectionState.isWorking)

                    if case let .failed(error) = injectionState {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help("Error: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Input Row

private struct InputRow: View {
    let input: WatchedInputInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(input.name)
                .font(.system(.body, design: .rounded))

            HStack {
                Text(input.lastValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(input.lastUpdate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Heartbeat Indicator

private struct HeartbeatIndicator: View {
    // MARK: Internal

    let status: HeartbeatStatus

    var body: some View {
        HStack(spacing: 3) {
            // Animated heart for active connections
            if status.isAlive {
                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear {
                        isPulsing = true
                    }
            } else {
                Image(systemName: "heart")
                    .foregroundColor(status.resumeNeeded ? .orange : .red)
            }

            // Status dot
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .help(helpText)
    }

    // MARK: Private

    @State private var isPulsing = false

    private var color: Color {
        if status.resumeNeeded {
            .orange
        } else if status.isAlive {
            .green
        } else {
            .red
        }
    }

    private var helpText: String {
        if status.isAlive {
            "Connected - Last heartbeat: \(status.lastHeartbeat?.formatted(.dateTime.hour().minute().second()) ?? "Unknown")"
        } else if status.resumeNeeded {
            "Connection needs resume"
        } else {
            "Disconnected"
        }
    }
}

// MARK: - Debug JS Popover

private struct DebugJSPopover: View {
    let window: MonitoredWindowInfo
    let viewModel: CursorInputWatcherViewModel
    
    @State private var customMessage = "debug test"
    @State private var lastResult = ""
    @State private var isExecuting = false
    
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
                Text("Last Result:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView {
                    Text(lastResult.isEmpty ? "No result yet" : lastResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(lastResult.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .frame(height: 80)
            }
        }
        .padding()
        .frame(width: 350)
    }
    
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

// MARK: - Preview

struct CursorInputWatcherView_Previews: PreviewProvider {
    static var previews: some View {
        CursorInputWatcherView()
            .frame(width: 600, height: 400)
    }
}
