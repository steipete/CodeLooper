import Defaults
import DesignSystem
import Diagnostics
import SwiftUI

struct DebugSettingsView: View {
    // MARK: Internal

    @EnvironmentObject var sessionLogger: SessionLogger

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {

            // JS Hook Settings
            DSSettingsSection("JavaScript Hook Settings") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    DSToggle(
                        "Automatic Hook Injection",
                        isOn: $automaticJSHookInjection,
                        description: "Automatically open debug console and inject hook script. When disabled, " +
                            "script is copied to clipboard for manual injection."
                    )

                    HStack {
                        Text("Current mode:")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)

                        Spacer()

                        Text(automaticJSHookInjection ? "Automatic" : "Manual (Clipboard)")
                            .font(Typography.caption1(.medium))
                            .foregroundColor(automaticJSHookInjection ? ColorPalette.warning : ColorPalette.success)
                    }
                }
            }


            // Debug Information
            DSSettingsSection("Build Information") {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("Build Configuration:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text("Debug")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.success)
                    }

                    HStack {
                        Text("Bundle Identifier:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    HStack {
                        Text("Version:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }

            // Debug Actions
            DSSettingsSection("Debug Actions") {
                VStack(spacing: Spacing.medium) {
                    DSButton("Open AXpector", style: .secondary, isFullWidth: true) {
                        NotificationCenter.default.post(name: .showAXpectorWindow, object: nil)
                    }
                    .frame(minHeight: 44)

                    DSButton("Trigger Test Notification", style: .secondary, isFullWidth: true) {
                        triggerTestNotification()
                    }
                    .frame(minHeight: 44)

                    DSButton("Show Welcome Screen", style: .secondary, isFullWidth: true) {
                        showWelcomeScreen()
                    }
                    .frame(minHeight: 44)

                    DSButton("Clear All UserDefaults", style: .destructive, isFullWidth: true) {
                        clearUserDefaults()
                    }
                    .frame(minHeight: 44)
                }
            }

            // Log Viewer Section
            DSSettingsSection("Session Logs") {
                LogViewerContent(sessionLogger: sessionLogger)
                    .frame(height: 300)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaterialPalette.windowBackground)
        .withDesignSystem()
    }

    // MARK: Private

    @Default(.automaticJSHookInjection) private var automaticJSHookInjection

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("DEBUG: Cleared all UserDefaults for domain: \(domain)")
    }

    private func triggerTestNotification() {
        NotificationCenter.default.post(name: .init("DebugTestNotification"), object: nil)
        print("DEBUG: Triggered test notification")
    }

    private func showWelcomeScreen() {
        NotificationCenter.default.post(name: .showWelcomeWindow, object: nil)
        print("DEBUG: Posted showWelcomeWindow notification")
    }
}

// MARK: - Log Viewer Content

private struct LogViewerContent: View {
    // MARK: Internal

    let sessionLogger: SessionLogger

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Picker("Filter:", selection: $selectedLogLevelFilter) {
                    Text("All").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level as LogLevel?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Spacer()

                Button {
                    copyLogToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy log to clipboard")

                Button {
                    sessionLogger.clearLog()
                    updateLogEntries()
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(ColorPalette.error)
                .help("Clear log")
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)

            DSDivider()

            // Log entries
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filteredLogEntries.isEmpty {
                        Text("No log entries")
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(filteredLogEntries) { entry in
                            logEntryRow(entry: entry)
                                .padding(.horizontal, Spacing.medium)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .onAppear {
            updateLogEntries()
        }
        .onChange(of: selectedLogLevelFilter) { _, _ in
            updateLogEntries()
        }
        .onChange(of: searchText) { _, _ in
            updateLogEntries()
        }
    }

    // MARK: Private

    @State private var searchText: String = ""
    @State private var selectedLogLevelFilter: LogLevel?
    @State private var logEntries: [LogEntry] = []

    private var filteredLogEntries: [LogEntry] {
        var filtered = logEntries

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

    @ViewBuilder
    private func logEntryRow(entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(colorForLogLevel(entry.level))
                .frame(width: 60, alignment: .leading)

            Text(entry.level.displayName.uppercased())
                .font(.system(.caption, weight: .bold))
                .foregroundColor(colorForLogLevel(entry.level))
                .frame(width: 50, alignment: .leading)

            if let pid = entry.instancePID {
                Text("[\(pid)]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 50, alignment: .leading)
            }

            Text(entry.message)
                .font(.system(.caption))
                .lineLimit(nil)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func updateLogEntries() {
        logEntries = sessionLogger.getEntries()
    }

    private func colorForLogLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: ColorPalette.textSecondary
        case .info: ColorPalette.info
        case .warning: ColorPalette.warning
        case .error, .critical: ColorPalette.error
        default: .primary
        }
    }

    private func copyLogToClipboard() {
        let entries = sessionLogger.getEntries()
        let logText = entries.map { entry -> String in
            let pidString = entry.instancePID.map { "[PID: \($0)] " } ?? ""
            let timeString = entry.timestamp.formatted(date: .omitted, time: .standard)
            let levelString = entry.level.displayName.uppercased()
            return "\(timeString) [\(levelString)] \(pidString)\(entry.message)"
        }.joined(separator: "\n")

        if let data = logText.data(using: .utf8) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .string)
        }
    }
}

// MARK: - Preview

struct DebugSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
            .environmentObject(SessionLogger.shared)
            .frame(width: 600, height: 800)
            .padding()
            .background(MaterialPalette.windowBackground)
            .withDesignSystem()
    }
}
