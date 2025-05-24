import SwiftUI
import AXorcist // Assuming LogEntry and GlobalAXLogger are here

// Simple view for a single log entry
struct AXInspectorLogEntryRow: View { // Renamed
    let entry: AXLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(logLevelToString(entry.level))
                    .font(.caption.weight(.bold))
                    .foregroundColor(logLevelToColor(entry.level))
                Spacer()
            }
            Text(entry.message)
                .font(.callout)
            if let details = entry.details, !details.isEmpty {
                Text("Details: \(details.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    private func logLevelToString(_ level: AXLogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    private func logLevelToColor(_ level: AXLogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error, .critical: return .red
        }
    }
}

struct AXInspectorLogView: View { // Renamed
    @State private var logEntries: [AXLogEntry] = []
    @State private var filterText: String = ""
    @State private var selectedLogLevel: AXLogLevel? = nil
    @State private var refreshTimer: Timer?

    var filteredLogEntries: [AXLogEntry] {
        logEntries.filter { entry in
            let textMatch = filterText.isEmpty || 
                            entry.message.localizedCaseInsensitiveContains(filterText) ||
                            (entry.details?.values.contains(where: { "\($0)".localizedCaseInsensitiveContains(filterText) }) ?? false)
            let levelMatch = selectedLogLevel == nil || entry.level == selectedLogLevel
            return textMatch && levelMatch
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("AXpector & AXorcist Logs")
                .font(.title2)
                .padding([.top, .leading])

            HStack {
                TextField("Filter logs...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Level", selection: $selectedLogLevel) {
                    Text("All").tag(nil as AXLogLevel?)
                    ForEach(AXLogLevel.allCases, id: \.self) {
                        Text(String(describing: $0).capitalized).tag($0 as AXLogLevel?)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task { await axClearLogs(); logEntries = [] }
                } label: {
                    Image(systemName: "trash")
                }
            }
            .padding(.horizontal)

            ScrollViewReader { proxy in
                List(filteredLogEntries) { entry in
                    AXInspectorLogEntryRow(entry: entry) // Renamed
                        .id(entry.id)
                }
                .listStyle(.inset)
                .onChange(of: filteredLogEntries) { oldValue, newValue in 
                    if newValue.count > oldValue.count {
                        proxy.scrollTo(newValue.last?.id, anchor: .bottom)
                    }
                }
            }
        }
        .onAppear {
            loadEntries() 
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in self.loadEntries() }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    @MainActor
    private func loadEntries() {
        Task {
            let currentEntries = await axGetLogEntries()
            self.logEntries = currentEntries
        }
    }
}

#if DEBUG
@MainActor
struct AXInspectorLogView_Previews: PreviewProvider { // Renamed
    static var previews: some View {
        Task {
            await axClearLogs()
            axDebugLog("Debug message for preview", details: ["key": "value"])
            axInfoLog("Info message for preview")
            try? await Task.sleep(for: .milliseconds(10))
            axWarningLog("Warning: Something might be wrong.")
            try? await Task.sleep(for: .milliseconds(10))
            axErrorLog("Error: Something went wrong!", details: ["code": "123"])
        }
        return AXInspectorLogView() // Renamed
    }
}
#endif 