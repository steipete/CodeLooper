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
        if viewModel.hookedWindows.contains(window.id) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)

                if let port = viewModel.getPort(for: window.id) {
                    Text("Port: \(port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let heartbeat = viewModel.getHeartbeatStatus(for: window.id) {
                    HeartbeatIndicator(status: heartbeat)
                }
            }
        } else {
            Button("Inject Hook") {
                Task {
                    await viewModel.injectJSHook(into: window)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isInjectingHook)
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
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help(status.isAlive ? "Connected" : "Disconnected")
    }

    // MARK: Private

    private var color: Color {
        if status.resumeNeeded {
            .orange
        } else if status.isAlive {
            .green
        } else {
            .red
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
