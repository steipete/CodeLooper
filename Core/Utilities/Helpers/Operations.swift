import Foundation

// MARK: - Upload Operations

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
