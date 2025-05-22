import Combine
import Defaults
import OSLog
import SwiftUI

// Spec 1.6: Menu Bar Icon Behavior
enum AppIconState: Sendable { // Made Sendable
    case green      // Generating, no red
    case black      // Idle/Active, no red/yellow
    case gray       // Monitoring disabled
    case yellow     // Recovering, no red
    case red        // Persistent Error/Unrecoverable
    // case flash      // Briefly for successful intervention (handled by temporary image change)

    var imageName: String {
        switch self {
        case .green: return "status_icon_green"
        case .black: return "status_icon_black"
        case .gray: return "status_icon_gray"
        case .yellow: return "status_icon_yellow"
        case .red: return "status_icon_red"
        }
    }
}

@MainActor
class AppIconStateController: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper", 
        category: "AppIconStateController"
    )
    
    public static let shared = AppIconStateController() // Added shared instance

    @Published private(set) var currentIconState: AppIconState = .gray
    @Published private(set) var isFlashing: Bool = false // New published property for flash state
    
    private var cursorMonitor: CursorMonitor?
    private var globalMonitoringEnabled: Bool = Defaults[.isGlobalMonitoringEnabled]
    private var cancellables = Set<AnyCancellable>()
    private var flashTask: Task<Void, Never>? // To manage the flash duration

    private init() { // Made private for singleton
        Self.logger.info("AppIconStateController initialized.")
        currentIconState = globalMonitoringEnabled ? .black : .gray
    }
    
    func setup(cursorMonitor: CursorMonitor) {
        self.cursorMonitor = cursorMonitor
        Self.logger.info("AppIconStateController setup with CursorMonitor.")

        // Observe global monitoring toggle from Defaults
        Defaults.publisher(.isGlobalMonitoringEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self = self else { return }
                self.globalMonitoringEnabled = change.newValue
                self.calculateAndApplyIconState()
            }
            .store(in: &cancellables)

        // Observe CursorMonitor's instanceInfo
        cursorMonitor.$instanceInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in // We just need the trigger, will read instanceInfo directly
                guard let self = self else { return }
                self.calculateAndApplyIconState()
            }
            .store(in: &cancellables)
        
        // Initial calculation
        calculateAndApplyIconState()
    }
    
    private func calculateAndApplyIconState() {
        guard let monitor = self.cursorMonitor else {
            currentIconState = globalMonitoringEnabled ? .black : .gray // Default if monitor not set up
            Self.logger.debug("CursorMonitor not available, icon state: \\(currentIconState)")
            return
        }

        if !globalMonitoringEnabled {
            currentIconState = .gray
            Self.logger.debug("Global monitoring disabled, icon state: .gray")
            return
        }

        let instances = monitor.instanceInfo.values // Get collection of CursorInstanceInfo

        if instances.isEmpty {
            currentIconState = .black // No instances, but monitoring is on
            Self.logger.debug("Global monitoring enabled, no instances, icon state: .black")
            return
        }

        var hasRed = false
        var hasYellow = false
        var hasGreen = false

        for instance in instances {
            switch instance.status {
            case .unrecoverable, .error: // Treat .error also as a potential red flag for icon state
                // Spec 1.6 for Red: Persistent Error or Unrecoverable UI Element Not Found.
                // Let's refine: .unrecoverable definitely makes it Red. .error might contribute to Yellow or Red depending on severity/persistence.
                // For now, let's say .unrecoverable is Red. Simple .error might not change the global icon alone unless it becomes persistent.
                // Persistent failure is handled by CursorMonitor setting status to .unrecoverable.
                if case .unrecoverable = instance.status {
                    hasRed = true
                }
            case .recovering:
                hasYellow = true
            case .working(let detail):
                // Spec 1.6 for Green: At least one monitored Cursor instance is in a "Generating..." state
                if detail.lowercased().contains("generating") { // Check for "generating"
                    hasGreen = true
                }
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
        Self.logger.debug(
            "Calculated icon state: \\(currentIconState) (Red: \\(hasRed), Yellow: \\(hasYellow), Green: \\(hasGreen))"
        )
    }
    
    public func flashIcon(durationSeconds: TimeInterval = 0.75) {
        flashTask?.cancel() // Cancel any existing flash

        if currentIconState == .gray { // Don't flash if monitoring is off (or app is generally inactive)
            Self.logger.debug("Attempted to flash icon while in .gray state. Flash suppressed.")
            return
        }
        
        isFlashing = true
        Self.logger.debug("Icon flash initiated (isFlashing = true).")

        flashTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await Task.sleep(for: .seconds(durationSeconds))
                if Task.isCancelled { return }
                self.isFlashing = false
                Self.logger.debug("Icon flash ended (isFlashing = false).")
            } catch is CancellationError {
                Self.logger.debug("Icon flash task cancelled. Ensuring isFlashing is false.")
                self.isFlashing = false // Ensure it's reset if task is cancelled
            } catch {
                Self.logger.error("Error during icon flash sleep: \\(error). Ensuring isFlashing is false.")
                self.isFlashing = false // Ensure it's reset on other errors
            }
        }
    }
} 
