import Defaults
import DesignSystem
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
        .onAppear {
            viewModel.handleViewAppear()
        }
        .onDisappear {
            viewModel.handleViewDisappear()
        }
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

    @State private var showDebugPopover = false

    @ViewBuilder
    private var windowStatus: some View {
        let injectionState = viewModel.getInjectionState(for: window.id)
        let isHooked = viewModel.hookedWindows.contains(window.id)

        if isHooked {
            HStack(spacing: 6) {
                // Debug icon (only when debug tab is visible and hooked)
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

                // Green heart when hooked and has heartbeat
                if let heartbeat = viewModel.getHeartbeatStatus(for: window.id), heartbeat.isAlive {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.green)
                        .help("Active connection with heartbeat")
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .help("Hooked")
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
                    // Show shimmer indicator
                    DSShimmer(width: 12, height: 12, cornerRadius: 2)

                    Text(injectionState.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.injectJSHook(into: window)
                        }
                    }) {
                        switch injectionState {
                        case .idle:
                            Text("Inject JS")
                        case .failed:
                            Text("Retry")
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

// DebugJSPopover is now in a separate file

// MARK: - Preview

struct CursorInputWatcherView_Previews: PreviewProvider {
    static var previews: some View {
        CursorInputWatcherView()
            .frame(width: 600, height: 400)
    }
}
