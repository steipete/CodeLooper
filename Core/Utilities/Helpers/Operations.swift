import Foundation

// MARK: - Upload Operations

/// Defines all trackable operations within the application for logging and analytics.
///
/// Operations enum provides a centralized definition of user actions and system events
/// that can be tracked for diagnostics, analytics, and debugging purposes.
/// Each case represents a distinct operation that may be logged or monitored.
enum Operations: String {
    // Upload operations
    case uploadContactsManual = "UploadContactsManual"
    case uploadContactsScheduled = "UploadContactsScheduled"
    case uploadContactsExportFailed = "UploadContactsExportFailed"
    case uploadContactsUploadFailed = "UploadContactsUploadFailed"
    case uploadContactsTimeout = "UploadContactsTimeout"

    // Server sync operations
    case serverSyncManual = "ServerSyncManual"

    // System operations
    case preferenceChangeRescheduleUploads = "PreferenceChangeRescheduleUploads"
}
