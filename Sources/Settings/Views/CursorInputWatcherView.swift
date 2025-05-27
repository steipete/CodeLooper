import SwiftUI

struct CursorInputWatcherView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading) {
            Text("Cursor Input Watcher")
                .font(.title)
                .padding(.bottom)

            Toggle("Enable Live Watching", isOn: $viewModel.isWatchingEnabled)
                .padding(.bottom)

            Text(viewModel.statusMessage)
                .font(.caption)
                .padding(.bottom)

            // Display Cursor Windows
            if !viewModel.cursorWindows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cursor Windows")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(viewModel.cursorWindows) { window in
                        HStack {
                            Image(systemName: "window.ceiling")
                                .foregroundColor(.secondary)
                            Text(window.windowTitle ?? "Untitled Window")
                                .font(.system(.body, design: .monospaced))
                            Spacer()

                            // JS Hook status indicator
                            if viewModel.hookedWindows.contains(window.id) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    if let port = viewModel.getPort(for: window.id) {
                                        Text(":\(port)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .help("JS Hook installed on port \(viewModel.getPort(for: window.id) ?? 0)")
                            }

                            // Inject/Reinject button
                            Button(viewModel.hookedWindows.contains(window.id) ? "Reinject" : "Inject JS") {
                                Task {
                                    await viewModel.injectJSHook(into: window)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isInjectingHook)

                            if window.isPaused {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(.bottom)

                Divider()
                    .padding(.bottom)
            }

            if viewModel.isWatchingEnabled, viewModel.watchedInputs.isEmpty {
                Text("No inputs are currently being watched. Configure in ViewModel.")
                    .foregroundColor(.orange)
            }

            List {
                ForEach(viewModel.watchedInputs) { inputInfo in
                    VStack(alignment: .leading) {
                        Text(inputInfo.name)
                            .font(.headline)
                        Text("Last Text: \(inputInfo.lastKnownText)")
                            .font(.body)
                            .lineLimit(3)
                        if let error = inputInfo.lastError {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Private

    @StateObject private var viewModel = CursorInputWatcherViewModel()
}

struct CursorInputWatcherView_Previews: PreviewProvider {
    static var previews: some View {
        CursorInputWatcherView()
    }
}
