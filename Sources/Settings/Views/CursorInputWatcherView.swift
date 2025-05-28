import SwiftUI
import Defaults

struct CursorInputWatcherView: View {
    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading) {
            Text("Cursor Input Watcher")
                .font(.title)
                .padding(.bottom)

            Toggle("Enable Live Watching", isOn: Binding(
                get: { viewModel.isWatchingEnabled },
                set: { newValue in 
                    Defaults[.isGlobalMonitoringEnabled] = newValue
                }
            ))
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
                                    // Hook status icon
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    
                                    // Port number
                                    if let port = viewModel.getPort(for: window.id) {
                                        Text(":\(port)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Heartbeat indicator
                                    if let heartbeat = viewModel.getHeartbeatStatus(for: window.id) {
                                        if heartbeat.isAlive {
                                            Image(systemName: "heart.fill")
                                                .foregroundColor(heartbeat.resumeNeeded ? .orange : .green)
                                                .font(.caption2)
                                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: heartbeat.isAlive)
                                                .help(heartbeat.resumeNeeded ? "Resume needed" : "Heartbeat active")
                                        } else {
                                            Image(systemName: "heart.slash")
                                                .foregroundColor(.gray)
                                                .font(.caption2)
                                                .help("No heartbeat")
                                        }
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
                        
                        // AI Status button - only show if window is hooked
                        if viewModel.hookedWindows.contains(window.id) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    Task {
                                        await viewModel.analyzeWindowWithAI(window: window)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text("🧠")
                                        Text("AI Status")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.getAIAnalysisStatus(for: window.id)?.isAnalyzing ?? false)
                                
                                Spacer()
                            }
                            .padding(.top, 4)
                            
                            // Show AI analysis result
                            if let aiStatus = viewModel.getAIAnalysisStatus(for: window.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if aiStatus.isAnalyzing {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Analyzing window...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                    } else if let status = aiStatus.status {
                                        Text(status)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    } else if let error = aiStatus.error {
                                        Text("Error: \(error)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 8)
                                    }
                                    
                                    if let lastAnalysis = aiStatus.lastAnalysis {
                                        Text("Last checked: \(lastAnalysis, style: .relative)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
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
