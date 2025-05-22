import Foundation
import Combine
import OSLog
import Defaults

@MainActor
public class CursorInstanceStateManager: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper",
        category: String(describing: CursorInstanceStateManager.self)
    )

    // Moved from CursorMonitor
    @Published public var manuallyPausedPIDs: Set<pid_t> = []
    @Published public var automaticInterventionsSincePositiveActivity: [pid_t: Int] = [:]
    @Published public var totalAutomaticInterventionsThisSession: Int = 0
    @Published public var connectionIssueResumeButtonClicks: [pid_t: Int] = [:]
    @Published public var consecutiveRecoveryFailures: [pid_t: Int] = [:]
    @Published public var lastKnownSidebarStateHash: [pid_t: Int?] = [:] // Int? as per CursorMonitor
    @Published public var lastActivityTimestamp: [pid_t: Date] = [:]
    @Published public var pendingObservationForPID: [pid_t: (startTime: Date, initialInterventionCountWhenObservationStarted: Int)] = [:]

    private let sessionLogger: SessionLogger

    public init(sessionLogger: SessionLogger) {
        self.sessionLogger = sessionLogger
        logger.info("CursorInstanceStateManager initialized.")
    }

    deinit {
        logger.info("CursorInstanceStateManager deinitialized.")
    }

    // MARK: - State Initialization and Cleanup

    public func initializeState(for pid: pid_t) {
        logger.info("Initializing state for PID: \(pid)")
        automaticInterventionsSincePositiveActivity[pid] = 0
        connectionIssueResumeButtonClicks[pid] = 0
        consecutiveRecoveryFailures[pid] = 0
        lastKnownSidebarStateHash[pid] = nil
        lastActivityTimestamp[pid] = Date()
        pendingObservationForPID.removeValue(forKey: pid)
        manuallyPausedPIDs.remove(pid) // Ensure it's not manually paused on new init
    }

    public func cleanupState(for pid: pid_t) {
        logger.info("Cleaning up state for PID: \(pid)")
        automaticInterventionsSincePositiveActivity.removeValue(forKey: pid)
        connectionIssueResumeButtonClicks.removeValue(forKey: pid)
        consecutiveRecoveryFailures.removeValue(forKey: pid)
        lastKnownSidebarStateHash.removeValue(forKey: pid)
        lastActivityTimestamp.removeValue(forKey: pid)
        pendingObservationForPID.removeValue(forKey: pid)
        manuallyPausedPIDs.remove(pid)
    }

    public func resetAllStatesAndSessionCounters() {
        logger.info("Resetting all instance states and session counters.")
        let pids = Set(automaticInterventionsSincePositiveActivity.keys)
            .union(connectionIssueResumeButtonClicks.keys)
            .union(consecutiveRecoveryFailures.keys)
            .union(lastKnownSidebarStateHash.keys)
            .union(lastActivityTimestamp.keys)
            .union(pendingObservationForPID.keys)
            .union(manuallyPausedPIDs)

        for pid in pids {
            initializeState(for: pid) // Re-initialize to default for active PIDs, effectively resetting.
                                     // For PIDs that might only be in manuallyPausedPIDs, this also clears them.
        }
        // Explicitly clear all, as initializeState only acts on one PID at a time.
        automaticInterventionsSincePositiveActivity.removeAll()
        connectionIssueResumeButtonClicks.removeAll()
        consecutiveRecoveryFailures.removeAll()
        lastKnownSidebarStateHash.removeAll()
        lastActivityTimestamp.removeAll()
        pendingObservationForPID.removeAll()
        manuallyPausedPIDs.removeAll()
        
        totalAutomaticInterventionsThisSession = 0
        Task {
            await sessionLogger.log(level: .info, message: "All instance states and session counters have been reset.")
        }
    }

    // MARK: - Manual Pause State
    public func isManuallyPaused(pid: pid_t) -> Bool {
        return manuallyPausedPIDs.contains(pid)
    }

    public func setManuallyPaused(pid: pid_t, paused: Bool) {
        if paused {
            manuallyPausedPIDs.insert(pid)
        } else {
            manuallyPausedPIDs.remove(pid)
        }
    }
    
    // MARK: - Intervention Counters
    public func getAutomaticInterventions(for pid: pid_t) -> Int {
        automaticInterventionsSincePositiveActivity[pid, default: 0]
    }

    public func incrementAutomaticInterventions(for pid: pid_t) {
        automaticInterventionsSincePositiveActivity[pid, default: 0] += 1
    }

    public func resetAutomaticInterventions(for pid: pid_t) {
        automaticInterventionsSincePositiveActivity[pid] = 0
    }

    public func getTotalAutomaticInterventionsThisSession() -> Int {
        totalAutomaticInterventionsThisSession
    }

    public func incrementTotalAutomaticInterventionsThisSession() {
        totalAutomaticInterventionsThisSession += 1
    }
    
    public func resetTotalAutomaticInterventionsThisSession() {
        totalAutomaticInterventionsThisSession = 0
    }

    // MARK: - Connection Issue Retries
    public func getConnectionIssueRetries(for pid: pid_t) -> Int {
        connectionIssueResumeButtonClicks[pid, default: 0]
    }

    public func incrementConnectionIssueRetries(for pid: pid_t) {
        connectionIssueResumeButtonClicks[pid, default: 0] += 1
    }

    public func resetConnectionIssueRetries(for pid: pid_t) {
        connectionIssueResumeButtonClicks[pid] = 0
    }

    // MARK: - Consecutive Recovery Failures
    public func getConsecutiveRecoveryFailures(for pid: pid_t) -> Int {
        consecutiveRecoveryFailures[pid, default: 0]
    }

    public func incrementConsecutiveRecoveryFailures(for pid: pid_t) {
        consecutiveRecoveryFailures[pid, default: 0] += 1
    }

    public func resetConsecutiveRecoveryFailures(for pid: pid_t) {
        consecutiveRecoveryFailures[pid] = 0
    }
    
    // MARK: - Last Activity Timestamp
    public func getLastActivityTimestamp(for pid: pid_t) -> Date? {
        lastActivityTimestamp[pid]
    }

    public func setLastActivityTimestamp(for pid: pid_t, date: Date) {
        lastActivityTimestamp[pid] = date
    }
    
    // MARK: - Last Known Sidebar State Hash
    public func getLastKnownSidebarStateHash(for pid: pid_t) -> Int?? { // Returns Int?? because dictionary access is Int? and then outer optional
        lastKnownSidebarStateHash[pid]
    }

    public func setLastKnownSidebarStateHash(for pid: pid_t, hash: Int?) {
        lastKnownSidebarStateHash[pid] = hash
    }

    // MARK: - Pending Observation
    public func getPendingObservation(for pid: pid_t) -> (startTime: Date, initialInterventionCountWhenObservationStarted: Int)? {
        pendingObservationForPID[pid]
    }

    public func startPendingObservation(for pid: pid_t, initialInterventionCount: Int) {
        pendingObservationForPID[pid] = (startTime: Date(), initialInterventionCountWhenObservationStarted: initialInterventionCount)
    }

    public func clearPendingObservation(for pid: pid_t) {
        pendingObservationForPID.removeValue(forKey: pid)
    }
} 