import Defaults
import DesignSystem
import Diagnostics
import Lottie
import SwiftUI

struct DebugSettingsView: View {
    // MARK: Internal

    @EnvironmentObject var sessionLogger: SessionLogger

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // Menu Bar Icon Settings
            DSSettingsSection("Menu Bar Icon") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    DSToggle(
                        "Use Dynamic Lottie Icon",
                        isOn: $useDynamicMenuBarIcon,
                        description: "Use animated Lottie icon instead of static PNG image in menu bar"
                    )

                    HStack {
                        Text("Current icon type:")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)

                        Spacer()

                        Text(useDynamicMenuBarIcon ? "Dynamic (Lottie)" : "Static (PNG)")
                            .font(Typography.caption1(.medium))
                            .foregroundColor(useDynamicMenuBarIcon ? ColorPalette.success : ColorPalette.primary)
                    }
                }
            }

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

            // Lottie Animation Test Section
            DSSettingsSection("Lottie Animation Test") {
                LottieTestView()
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
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @Default(.useDynamicMenuBarIcon) private var useDynamicMenuBarIcon
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

// MARK: - Lottie Test View (moved from AboutSettingsView)

private struct LottieTestView: View {
    @Default(.isGlobalMonitoringEnabled) private var isWatchingEnabled
    @State private var testSize: CGFloat = 32
    @State private var localAnimationEnabled = true
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Menu Bar Icon Test")
                .font(Typography.body(.medium))
                .foregroundColor(ColorPalette.text)

            // Animation analysis
            VStack(spacing: Spacing.small) {
                Text("Animation Analysis:")
                    .font(Typography.caption1(.medium))
                    .foregroundColor(ColorPalette.text)

                if let animation = LottieAnimation.named("chain_link_lottie") {
                    let duration = animation.duration
                    let frameRate = animation.framerate
                    let totalFrames = Int(duration * frameRate)

                    Text("Duration: \(String(format: "%.2f", duration))s, FPS: \(frameRate), Frames: \(totalFrames)")
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.textSecondary)
                } else {
                    Text("Failed to load animation")
                        .font(Typography.caption2())
                        .foregroundColor(.red)
                }
            }

            // Animation test views
            HStack(spacing: Spacing.large) {
                VStack(spacing: Spacing.small) {
                    Text("Menu Bar Size (16x16)")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    LottieMenuBarView()
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.red, width: 1) // Debug border
                }

                VStack(spacing: Spacing.small) {
                    Text("Test Size (\(Int(testSize))x\(Int(testSize)))")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    LottieTestAnimationView(isEnabled: localAnimationEnabled)
                        .frame(width: testSize, height: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.blue, width: 1) // Debug border
                }

                VStack(spacing: Spacing.small) {
                    Text("Rotating Icon Test")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Image(systemName: "link")
                        .renderingMode(.template)
                        .foregroundColor(Color.primary)
                        .font(.system(size: testSize / 2))
                        .frame(width: testSize, height: testSize)
                        .rotationEffect(.degrees(localAnimationEnabled ? rotationAngle : 0))
                        .animation(
                            localAnimationEnabled ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: localAnimationEnabled
                        )
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.green, width: 1)
                        .onAppear {
                            if localAnimationEnabled {
                                rotationAngle = 360
                            }
                        }
                        .onChange(of: localAnimationEnabled) { _, newValue in
                            if newValue {
                                rotationAngle = 360
                            } else {
                                rotationAngle = 0
                            }
                        }
                }

                VStack(spacing: Spacing.small) {
                    Text("Your Custom Icon")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    CustomChainLinkIcon(size: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.purple, width: 1)
                }

                VStack(spacing: Spacing.small) {
                    Text("Simplified Test")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    SimplifiedChainLinkIcon(size: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.orange, width: 1)
                }
            }

            DSDivider()

            // Controls section
            VStack(spacing: Spacing.medium) {
                // Animation toggle buttons
                HStack(spacing: Spacing.medium) {
                    Text("Local Animation:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Button("Enable") {
                        localAnimationEnabled = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localAnimationEnabled)

                    Button("Disable") {
                        localAnimationEnabled = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!localAnimationEnabled)
                }

                // Global monitoring toggle
                HStack(spacing: Spacing.medium) {
                    Text("Global Monitoring:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Button("Enable") {
                        Defaults[.isGlobalMonitoringEnabled] = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWatchingEnabled)

                    Button("Disable") {
                        Defaults[.isGlobalMonitoringEnabled] = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isWatchingEnabled)
                }

                // Size controls
                HStack(spacing: Spacing.medium) {
                    Text("Test Size:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Button("16") { testSize = 16 }
                        .buttonStyle(.bordered)

                    Button("24") { testSize = 24 }
                        .buttonStyle(.bordered)

                    Button("32") { testSize = 32 }
                        .buttonStyle(.bordered)

                    Button("64") { testSize = 64 }
                        .buttonStyle(.bordered)

                    Button("128") { testSize = 128 }
                        .buttonStyle(.bordered)
                }

                // Size slider
                HStack(spacing: Spacing.medium) {
                    Text("Custom:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)

                    Slider(value: $testSize, in: 16 ... 128, step: 1) {
                        Text("Size")
                    } minimumValueLabel: {
                        Text("16")
                            .font(Typography.caption2())
                    } maximumValueLabel: {
                        Text("128")
                            .font(Typography.caption2())
                    }
                    .frame(width: 200)

                    Text("\(Int(testSize))")
                        .font(Typography.caption1(.medium))
                        .frame(width: 30)
                }
            }

            DSDivider()

            // Status section
            VStack(spacing: Spacing.small) {
                Text("Current State:")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)

                HStack(spacing: Spacing.medium) {
                    Text("Global Watching: \(isWatchingEnabled ? "Enabled" : "Disabled")")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(isWatchingEnabled ? .green : .red)

                    Text("Local Animation: \(localAnimationEnabled ? "Enabled" : "Disabled")")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(localAnimationEnabled ? .green : .red)
                }
            }
        }
        .padding(Spacing.medium)
    }
}

// MARK: - Lottie Test Animation View

private struct LottieTestAnimationView: View {
    // MARK: Internal

    let isEnabled: Bool

    var body: some View {
        Group {
            if let animation = loadAnimation() {
                LottieView(animation: animation)
                    .playing(loopMode: isEnabled ? .loop : .playOnce)
                    .animationSpeed(0.3)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(Color.primary)
                    .clipped()
                    .onAppear {
                        logger.info("Test Lottie animation view appeared, enabled: \(isEnabled)")
                    }
            } else {
                Image(systemName: "link")
                    .renderingMode(.template)
                    .foregroundColor(Color.primary)
                    .onAppear {
                        logger.error("Test animation failed to load, using fallback")
                    }
            }
        }
    }

    // MARK: Private

    private let logger = Logger(category: .statusBar)

    private func loadAnimation() -> LottieAnimation? {
        LottieAnimation.named("chain_link_lottie") ??
            LottieAnimation.filepath(Bundle.main.path(forResource: "chain_link_lottie", ofType: "json") ?? "")
    }
}

// MARK: - Simplified Chain Link Icon

private struct SimplifiedChainLinkIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // First oval link
            Ellipse()
                .stroke(Color.primary, lineWidth: max(2, size / 12))
                .frame(width: size * 0.4, height: size * 0.2)
                .offset(x: -size * 0.15, y: 0)

            // Second oval link (rotated and offset)
            Ellipse()
                .stroke(Color.primary, lineWidth: max(2, size / 12))
                .frame(width: size * 0.2, height: size * 0.4)
                .offset(x: size * 0.15, y: 0)
        }
        .frame(width: size, height: size)
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
                .foregroundColor(.red)
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
        case .debug: .gray
        case .info: .blue
        case .warning: .orange
        case .error, .critical: .red
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
            .background(ColorPalette.background)
            .withDesignSystem()
    }
}
