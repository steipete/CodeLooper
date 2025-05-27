import AppKit
import Combine
import Defaults
import Diagnostics
import OSLog
import SwiftUI

// Spec 1.6: Menu Bar Icon Behavior
enum AppIconState: Sendable { // Made Sendable
    case green // Generating, no red
    case black // Idle/Active, no red/yellow
    case gray // Monitoring disabled
    case yellow // Recovering, no red
    case red // Persistent Error/Unrecoverable

    // MARK: Internal

    // case flash      // Briefly for successful intervention (handled by temporary tint color change)

    /// Maps the icon state to its corresponding tint color
    var tintColor: NSColor? {
        switch self {
        case .green: .systemGreen
        case .black: nil // Use default system appearance
        case .gray: .disabledControlTextColor
        case .yellow: .systemYellow
        case .red: .systemRed
        }
    }
}

@MainActor
class AppIconStateController: ObservableObject {
    // MARK: Lifecycle

    private init() { // Made private for singleton
        Self.logger.info("AppIconStateController initialized.")
        // Don't read from Defaults during init to avoid background thread issues
        currentIconState = .gray
        currentTintColor = currentIconState.tintColor
    }

    // MARK: Public

    public static let shared = AppIconStateController() // Added shared instance

    public func flashIcon(durationSeconds: TimeInterval = 0.3) {
        flashTask?.cancel() // Cancel any existing flash

        if currentIconState == .gray { // Don't flash if monitoring is off (or app is generally inactive)
            Self.logger.debug("Attempted to flash icon while in .gray state. Flash suppressed.")
            return
        }

        // Store current tint color before flash
        preFlashTintColor = currentTintColor
        isFlashing = true
        // Set flash tint color (use accent color or blue for visibility)
        currentTintColor = .controlAccentColor
        Self.logger.debug("Icon flash initiated with tint: \\(String(describing: currentTintColor)).")

        flashTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(durationSeconds))
                if Task.isCancelled { return }

                // Restore previous tint color
                self.isFlashing = false
                self.currentTintColor = self.preFlashTintColor
                self.preFlashTintColor = nil
                Self.logger.debug("Icon flash ended, restored tint: \\(String(describing: self.currentTintColor)).")
            } catch is CancellationError {
                Self.logger.debug("Icon flash task cancelled. Restoring tint.")
                self.isFlashing = false
                self.currentTintColor = self.preFlashTintColor
                self.preFlashTintColor = nil
            } catch {
                Self.logger.error("Error during icon flash sleep: \\(error). Restoring tint.")
                self.isFlashing = false
                self.currentTintColor = self.preFlashTintColor
                self.preFlashTintColor = nil
            }
        }
    }

    // MARK: Internal

    @Published private(set) var currentTintColor: NSColor?
    @Published private(set) var isFlashing: Bool = false // New published property for flash state

    func setup(cursorMonitor: CursorMonitor) {
        self.cursorMonitor = cursorMonitor

        // Now it's safe to read from Defaults
        self.globalMonitoringEnabled = Defaults[.isGlobalMonitoringEnabled]

        Self.logger.info("AppIconStateController setup with CursorMonitor.")

        // Observe global monitoring toggle from Defaults
        Defaults.publisher(.isGlobalMonitoringEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                self.globalMonitoringEnabled = change.newValue
                self.calculateAndApplyIconState()
            }
            .store(in: &cancellables)

        // Observe CursorMonitor's monitoredApps (previously monitoredInstances)
        cursorMonitor.$monitoredApps // Use $monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: [MonitoredAppInfo]) in
                // Explicitly type the sink parameter if needed, or just use _
                guard let self else { return }
                self.calculateAndApplyIconState()
            }
            .store(in: &cancellables)

        // Mark setup as complete and do initial calculation
        self.isSetupComplete = true
        calculateAndApplyIconState()
    }

    // MARK: Private

    private static let logger = Logger(category: .statusBar)

    private var currentIconState: AppIconState = .gray // Internal logical state
    private var preFlashTintColor: NSColor? // Store tint color before flash
    private var cursorMonitor: CursorMonitor?
    private var globalMonitoringEnabled: Bool = false // Don't read Defaults during init
    private var cancellables = Set<AnyCancellable>()
    private var flashTask: Task<Void, Never>? // To manage the flash duration
    private var isSetupComplete: Bool = false // Track if setup is complete

    private func calculateAndApplyIconState() {
        // Don't update state until setup is complete to avoid background thread issues
        guard isSetupComplete else {
            Self.logger.debug("Setup not complete, skipping icon state calculation")
            return
        }

        guard let monitor = self.cursorMonitor else {
            currentIconState = globalMonitoringEnabled ? .black : .gray // Default if monitor not set up
            let newTintColor = currentIconState.tintColor
            // Only update tint if not flashing
            if !isFlashing {
                currentTintColor = newTintColor
            } else {
                preFlashTintColor = newTintColor
            }
            Self.logger.debug("CursorMonitor not available, tint color: \\(String(describing: newTintColor))")
            return
        }

        if !globalMonitoringEnabled {
            currentIconState = .gray
            let newTintColor = currentIconState.tintColor
            // Only update tint if not flashing
            if !isFlashing {
                currentTintColor = newTintColor
            } else {
                preFlashTintColor = newTintColor
            }
            Self.logger.debug("Global monitoring disabled, tint color: gray")
            return
        }

        let instances = monitor.monitoredApps // Use monitoredApps

        if instances.isEmpty {
            currentIconState = .black // No instances, but monitoring is on
            let newTintColor = currentIconState.tintColor
            // Only update tint if not flashing
            if !isFlashing {
                currentTintColor = newTintColor
            } else {
                preFlashTintColor = newTintColor
            }
            Self.logger
                .debug("Global monitoring enabled, no instances, tint color: \\(String(describing: newTintColor))")
            return
        }

        var hasRed = false
        var hasYellow = false
        var hasGreen = false

        for instance in instances {
            switch instance.status {
            case .pausedUnrecoverable:
                // Spec 1.6 for Red: Persistent Error or Unrecoverable UI Element Not Found.
                hasRed = true
            case .intervening, .observation:
                hasYellow = true
            case .positiveWork:
                // Spec 1.6 for Green: At least one monitored Cursor instance is in a "Generating..." state
                hasGreen = true
            default:
                break
            }
        }

        // Apply priority logic from Spec 1.6
        if hasRed {
            currentIconState = .red
        } else if hasYellow {
            currentIconState = .yellow
        } else if hasGreen {
            currentIconState = .green
        } else {
            currentIconState = .black // Default if no other specific state conditions met
        }

        let newTintColor = currentIconState.tintColor
        // Only update tint if not flashing
        if !isFlashing {
            currentTintColor = newTintColor
        } else {
            preFlashTintColor = newTintColor
        }

        Self.logger.debug(
            "Calculated state: \\(currentIconState) with tint: \\(String(describing: newTintColor)) (Red: \\(hasRed), Yellow: \\(hasYellow), Green: \\(hasGreen))"
        )
    }
}
