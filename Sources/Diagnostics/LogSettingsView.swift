import SwiftUI
import OSLog // For LogLevel if it's defined there or needed for filtering
// Assuming LogEntry and LogLevel are accessible, e.g., from the main app module or a shared module.

@MainActor
struct LogSettingsView: View {
    @ObservedObject private var sessionLogger = SessionLogger.shared
    @State private var searchText: String = ""
    @State private var selectedLogLevelFilter: LogLevel? = nil // Allow 'nil' for all levels

    // Placeholder for actual log levels if LogLevel.allCases isn't directly usable
    // or if a specific order/naming is desired for the filter.
    private var logLevelsForFilter: [LogLevel?] {
        var levels: [LogLevel?] = [nil] // "All Levels"
        levels.append(contentsOf: LogLevel.allCases)
        return levels
    }

    private var filteredLogEntries: [LogEntry] {
        var filtered = sessionLogger.entries

        if let levelFilter = selectedLogLevelFilter {
            filtered = filtered.filter { $0.level == levelFilter }
        }

        if !searchText.isEmpty {
            let lowercasedSearchText = searchText.lowercased()
            filtered = filtered.filter {
                $0.message.lowercased().contains(lowercasedSearchText) ||
                ($0.instancePID != nil && String($0.instancePID!).contains(lowercasedSearchText))
            }
        }
        return filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Toolbar / Controls
            HStack {
                Picker("Filter by Level:", selection: $selectedLogLevelFilter) {
                    ForEach(logLevelsForFilter, id: \\.self) { level in
                        Text(level?.rawValue.capitalized ?? "All Levels").tag(level)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                TextField("Search messages or PID...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                Button {
                    exportLog()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Log")
                }
                
                Button {
                    copyLogToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Log")
                }

                Button {
                    sessionLogger.clearLog()
                } label: {
                    Image(systemName: "trash")
                    Text("Clear Log")
                }
                .foregroundColor(.red)
            }
            .padding()

            Divider()

            // MARK: - Log Entries List
            List {
                if filteredLogEntries.isEmpty {
                    Text("No log entries matching filters, or log is empty.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ForEach(filteredLogEntries) { entry in
                        logEntryRow(entry: entry)
                            .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.plain) // Use plain list style for better density
        }
        .frame(minWidth: 500, idealWidth: 700, minHeight: 300, idealHeight: 500)
    }

    @ViewBuilder
    private func logEntryRow(entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.caption.monospaced())
                .foregroundColor(colorForLogLevel(entry.level))
                .frame(minWidth: 70, alignment: .leading) // Ensure consistent width for timestamp

            Text(entry.level.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundColor(colorForLogLevel(entry.level))
                .frame(minWidth: 60, alignment: .leading) // Ensure consistent width for level

            if let pid = entry.instancePID {
                Text("PID: \\(pid)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray)
                    .frame(minWidth: 70, alignment: .leading)
            } else {
                Text("") // Keep layout consistent
                    .frame(minWidth: 70, alignment: .leading)
            }
            
            Text(entry.message)
                .font(.callout)
                .lineLimit(nil) // Allow multiline
                .textSelection(.enabled)
            
            Spacer() // Push content to left
        }
    }

    private func colorForLogLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error, .critical: return .red
        // Add other cases if LogLevel has more
        default: return .primary
        }
    }
    
    private func copyLogToClipboard() {
        let logText = sessionLogger.entries.map { entry -> String in
            let pidString = entry.instancePID.map { "[PID: \\($0)] " } ?? ""
            return "\\(entry.timestamp.formatted(date: .omitted, time: .standard)) [\\(entry.level.rawValue.uppercased())] \\(pidString)\\(entry.message)"
        }.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
        // Optionally, provide user feedback that copy was successful
    }

    private func exportLog() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "CodeLooper_SessionLog_\\(dateFormatterForFilename()).txt"

        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                var logContent = ""
                for entry in sessionLogger.entries.reversed() { // Export oldest first
                    let pidString = entry.instancePID != nil ? "PID: \\(entry.instancePID!)" : ""
                    logContent += "\\(entry.timestamp) [\\(entry.level.rawValue.uppercased())] \\(pidString) \\(entry.message)\\n"
                }
                do {
                    try logContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    // Handle error (e.g., show an alert)
                    print("Failed to export log: \\(error.localizedDescription)")
                    // Consider showing an alert to the user via AlertPresenter or similar
                }
            }
        }
    }

    private func dateFormatterForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

#if DEBUG
struct LogSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Example: Populate SessionLogger with some mock data for previewing
        let logger = SessionLogger.shared
        Task {
            await logger.log(level: .info, message: "Preview log: Application started.", pid: 123)
            await logger.log(level: .debug, message: "Preview log: Debugging some cool feature here. This message might be a bit longer to test wrapping and text selection capabilities within the log view.", pid: 456)
            await logger.log(level: .warning, message: "Preview log: Something might be wrong, be careful!", pid: 123)
            await logger.log(level: .error, message: "Preview log: An error occurred! Oh noes! Details should follow.", pid: 789)
            await logger.log(level: .critical, message: "Preview log: Critical failure, system unstable.", pid: 123)
            await logger.log(level: .info, message: "Preview log: Another info message without PID.")
        }
        
        return LogSettingsView()
            .environmentObject(logger) // Ensure the logger is in the environment for the preview
    }
}
#endif 