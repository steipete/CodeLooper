import Defaults
import Foundation

extension Defaults.Keys {
    // Monitoring Loop Settings (Spec 3.3.A & CursorMonitor current constants)
    static let monitoringIntervalSeconds = Key<TimeInterval>(
        "monitoringIntervalSeconds",
        default: 1.0
    ) // Spec default 1s, CursorMonitor had 5.0; choosing 1.0 from spec
    static let maxInterventionsBeforePause = Key<Int>(
        "maxInterventionsBeforePause",
        default: 5
    ) // Spec 3.3.A "Max Auto-Interventions Per Instance"

    // Intervention Specific Limits (Spec 3.3.E & CursorMonitor current constants)
    static let maxConnectionIssueRetries = Key<Int>("maxConnectionIssueRetries", default: 3)
    static let maxConsecutiveRecoveryFailures = Key<Int>("maxConsecutiveRecoveryFailures", default: 3)
    
    // General Behavior (Spec 3.3.A / 3.3.E)
    static let playSoundOnIntervention = Key<Bool>("playSoundOnIntervention", default: true) // Assuming default true
    static let sendNotificationOnPersistentError = Key<Bool>(
        "sendNotificationOnPersistentError",
        default: true
    ) // Assuming default true
    
    // Future: Add other keys from Spec 3.3 as needed:
    // - textForCursorStopsRecovery (String)
    // - launchAtLogin (Bool) - SMAppService handles this, but a key to reflect user choice.
    // - enableConnectionIssuesRecovery (Bool)
    // - enableCursorForceStoppedRecovery (Bool)
    // - enableCursorStopsRecovery (Bool)
    // - monitorSidebarActivity (Bool)
    // - postInterventionObservationWindowSeconds (Int/TimeInterval)
}
