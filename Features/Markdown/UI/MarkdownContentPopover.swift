import AppKit
import Demark
import DesignSystem
import Diagnostics
import SwiftUI

@MainActor
private class MarkdownContentState: ObservableObject {
    @Published var markdownContent: String = ""
    @Published var htmlContent: String = ""
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var isObserving = false
    @Published var error: String?
}

struct MarkdownContentPopover: View {
    let window: MonitoredWindowInfo
    @ObservedObject var viewModel: CursorInputWatcherViewModel

    @StateObject private var contentState = MarkdownContentState()
    private let markdownService = ServiceManager.shared.demarkService
    private let logger = Logger(category: .ui)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sidebar Content")
                        .font(.headline)

                    Text("Window: \(window.windowTitle ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Observer toggle
                DSToggle(
                    contentState.isObserving ? "Observing" : "Observer Off",
                    isOn: $contentState.isObserving
                )
                .onChange(of: contentState.isObserving) { _, newValue in
                    Task { @MainActor in
                        // Defer the action to avoid modifying state during view update
                        try? await Task.sleep(for: .milliseconds(100))
                        if newValue {
                            await startObserving()
                        } else {
                            await stopObserving()
                        }
                    }
                }
            }
            .padding(.bottom, 4)

            Divider()

            // Status bar
            HStack {
                if contentState.isLoading {
                    DSShimmer(width: 14, height: 14, cornerRadius: 2)
                    Text("Fetching content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let error = contentState.error {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .frame(width: 14, height: 14) // Fixed size
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let updateTime = contentState.lastUpdateTime {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 14, height: 14) // Fixed size
                    Text("Updated: \(updateTime, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No content yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 4) {
                    // Copy markdown button
                    Button(action: copyMarkdown) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(contentState.markdownContent.isEmpty)
                    .help("Copy Markdown")

                    // Refresh button
                    Button(action: {
                        Task {
                            await fetchContent()
                        }
                    }, label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    })
                    .buttonStyle(.plain)
                    .disabled(contentState.isLoading || !viewModel.checkHookStatus(for: window))
                    .help("Refresh")
                }
            }

            Divider()

            // Content display with tabs
            TabView {
                // Markdown tab
                ScrollView {
                    Text(contentState.markdownContent.isEmpty ? "No content available" : contentState.markdownContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(contentState.markdownContent.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .tabItem {
                    Label("Markdown", systemImage: "doc.text")
                }

                // HTML tab (for debugging)
                ScrollView {
                    Text(contentState.htmlContent.isEmpty ? "No HTML content" : contentState.htmlContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(contentState.htmlContent.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .tabItem {
                    Label("HTML Source", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .frame(height: 400)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(4)
        }
        .padding()
        .frame(width: 600)
        .onAppear {
            Task {
                await fetchContent()
            }
        }
        .onDisappear {
            Task {
                await stopObserving()
            }
        }
    }

    // MARK: - Private Methods

    private func fetchContent() async {
        guard viewModel.checkHookStatus(for: window) else {
            contentState.error = "No active hook for this window"
            return
        }

        contentState.isLoading = true
        contentState.error = nil

        do {
            // Get composer content from the JS hook
            let result = try await viewModel.jsHookService.sendCommand([
                "type": "getComposerContent",
            ], to: window.id)

            // Parse the result to extract HTML content
            if let data = result.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                // Check if content exists and is not null
                if let html = json["content"] as? String, !html.isEmpty {
                    contentState.htmlContent = html

                    // Convert HTML to Markdown
                    let markdown = try await markdownService.convertToMarkdown(html)

                    await MainActor.run {
                        contentState.markdownContent = markdown
                        contentState.lastUpdateTime = Date()
                        contentState.isLoading = false
                    }
                } else {
                    // Content is null or empty - composer bar not found
                    await MainActor.run {
                        contentState.htmlContent = ""
                        contentState.markdownContent = ""
                        contentState.error = "No composer content found"
                        contentState.lastUpdateTime = Date()
                        contentState.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    contentState.error = "Failed to parse response"
                    contentState.isLoading = false
                }
            }

        } catch {
            await MainActor.run {
                contentState.error = error.localizedDescription
                contentState.isLoading = false
            }
            logger.error("Failed to fetch content: \(error)")
        }
    }

    private func startObserving() async {
        guard viewModel.checkHookStatus(for: window) else {
            contentState.error = "No active hook for this window"
            contentState.isObserving = false
            return
        }

        do {
            // Start the composer observer
            _ = try await viewModel.jsHookService.sendCommand([
                "type": "startComposerObserver",
            ], to: window.id)

            // Start periodic updates
            Task {
                while contentState.isObserving {
                    await fetchContent()
                    try? await Task.sleep(for: .seconds(2)) // 2 seconds
                }
            }

        } catch {
            await MainActor.run {
                contentState.error = error.localizedDescription
                contentState.isObserving = false
            }
            logger.error("Failed to start observer: \(error)")
        }
    }

    private func stopObserving() async {
        contentState.isObserving = false

        guard viewModel.checkHookStatus(for: window) else {
            return
        }

        do {
            // Stop the composer observer
            _ = try await viewModel.jsHookService.sendCommand([
                "type": "stopComposerObserver",
            ], to: window.id)
        } catch {
            logger.error("Failed to stop observer: \(error)")
        }
    }

    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contentState.markdownContent, forType: .string)
    }
}
