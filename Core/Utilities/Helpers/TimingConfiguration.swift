import Foundation

/// Centralized configuration for timing values across the application.
///
/// TimingConfiguration provides a single source of truth for all sleep durations,
/// delays, and timeout values used throughout CodeLooper. This enables:
/// - Easy adjustment of timing behavior
/// - Consistent timing across components
/// - Future user configurability
/// - Performance tuning and testing
///
/// ## Topics
///
/// ### Monitoring Intervals
/// - ``monitoringCycleInterval``
/// - ``monitoringDisabledCheckInterval``
/// - ``heartbeatCheckInterval``
///
/// ### Connection Timeouts
/// - ``webSocketHandshakePollingInterval``
/// - ``webSocketHandshakeTimeout``
/// - ``jsHookInjectionDelay``
///
/// ### UI Interaction Delays
/// - ``keyboardEventDelay``
/// - ``uiFeedbackDuration``
/// - ``interventionActionDelay``
///
/// ### Retry and Recovery
/// - ``retryBaseDelay``
/// - ``retryMaxDelay``
/// - ``probePollingInterval``
public enum TimingConfiguration {
    
    // MARK: - Monitoring Intervals
    
    /// Interval between monitoring cycles when actively monitoring apps
    public static let monitoringCycleInterval: TimeInterval = 5.0
    
    /// Interval to check if monitoring should resume when globally disabled
    public static let monitoringDisabledCheckInterval: TimeInterval = 10.0
    
    /// Interval between heartbeat checks for connection health
    public static let heartbeatCheckInterval: TimeInterval = 2.0
    
    // MARK: - Connection Timeouts
    
    /// Polling interval while waiting for WebSocket handshake completion
    public static let webSocketHandshakePollingInterval: TimeInterval = 0.2
    
    /// Maximum time to wait for WebSocket handshake
    public static let webSocketHandshakeTimeout: TimeInterval = 120.0
    
    /// Delay after JavaScript injection to allow script initialization
    public static let jsHookInjectionDelay: TimeInterval = 2.0
    
    // MARK: - UI Interaction Delays
    
    /// Delay between keyboard key down and key up events for reliability
    public static let keyboardEventDelay: TimeInterval = 0.05
    
    /// Duration to display UI feedback messages
    public static let uiFeedbackDuration: TimeInterval = 2.0
    
    /// Standard delay between intervention actions
    public static let interventionActionDelay: TimeInterval = 2.0
    
    // MARK: - Retry and Recovery
    
    /// Base delay for retry operations before exponential backoff
    public static let retryBaseDelay: TimeInterval = 1.0
    
    /// Maximum delay for retry operations
    public static let retryMaxDelay: TimeInterval = 30.0
    
    /// Polling interval for probe completion checks
    public static let probePollingInterval: TimeInterval = 0.1
    
    // MARK: - Performance Profiles
    
    /// Aggressive performance profile with shorter delays
    public struct AggressiveProfile {
        public static let monitoringCycleInterval: TimeInterval = 2.0
        public static let heartbeatCheckInterval: TimeInterval = 1.0
        public static let jsHookInjectionDelay: TimeInterval = 1.0
        public static let interventionActionDelay: TimeInterval = 1.0
    }
    
    /// Conservative performance profile with longer delays
    public struct ConservativeProfile {
        public static let monitoringCycleInterval: TimeInterval = 10.0
        public static let heartbeatCheckInterval: TimeInterval = 5.0
        public static let jsHookInjectionDelay: TimeInterval = 5.0
        public static let interventionActionDelay: TimeInterval = 5.0
    }
    
    // MARK: - Conversion Helpers
    
    /// Convert seconds to nanoseconds for Task.sleep
    public static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        UInt64(seconds * 1_000_000_000)
    }
    
    /// Convert seconds to Duration for Task.sleep(for:)
    public static func duration(_ seconds: TimeInterval) -> Duration {
        .seconds(seconds)
    }
}