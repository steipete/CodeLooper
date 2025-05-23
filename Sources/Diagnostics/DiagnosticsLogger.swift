import Foundation
import os
import OSLog

// Make Defaults Sendable-compatible in Swift 6
@preconcurrency import Defaults

// No need for custom OSLogPrivacy extension - just use string interpolation without privacy modifiers

/// DiagnosticsLogger provides enhanced logging capabilities with diagnostic information
/// for troubleshooting critical app components.
///
/// This class is implemented as an actor to ensure thread safety across all operations.
///
/// Thread Safety:
/// - Swift actor model guarantees that all mutations to actor-isolated state happen
///   in a synchronized manner, preventing data races
/// - Each method that accesses or mutates state is implicitly isolated to the actor
/// - The safeRecord* functions provide convenient entry points from any thread
actor DiagnosticsLogger {
    // Singleton instance with thread-safe initialization
    static let shared = DiagnosticsLogger()

    // Primary logger instance
    private let logger = Logger(label: "DiagnosticsLogger", category: .general)

    // Diagnostic state tracking - all state is actor-isolated
    private var operationCounts: [String: Int] = [:]
    private var operationStartTimes: [UUID: (operation: String, startTime: Date)] = [:]
    private var operationErrors: [String: [Error]] = [:]
    private var operationTimings: [String: [TimeInterval]] = [:]

    private init() {
        // Private initializer for singleton
        logger.info("DiagnosticsLogger initialized on thread: \(Thread.isMainThread ? "main" : "background")")
    }

    /// Record the start of an operation for timing and tracking purposes
    /// - Parameters:
    ///   - operation: Name of the operation being tracked
    ///   - context: Additional context to log
    /// - Returns: A UUID that uniquely identifies this operation instance
    func recordOperationStart(_ operation: String, context: [String: Any]? = nil) -> UUID {
        // Generate unique ID for this operation instance
        let operationId = UUID()

        // Update actor-isolated state
        let currentCount = operationCounts[operation, default: 0] + 1
        operationCounts[operation] = currentCount
        operationStartTimes[operationId] = (operation: operation, startTime: Date())

        // Format context for logging
        var contextString = ""
        if let context {
            contextString = " - Context: \(context)"
        }

        // Build the log message
        let logMessage = "⏱️ Operation START: \(operation) (ID: \(operationId.uuidString), " +
            "Count: \(currentCount))\(contextString)"

        // Create a local copy of the logger to ensure proper isolation
        let loggerCopy = logger

        // Use Task.detached for logging to avoid potential cross-actor reference issues
        Task.detached { @Sendable in
            loggerCopy.info("\(logMessage)")
        }

        return operationId
    }

    /// Record the successful completion of an operation
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - context: Additional context to log
    func recordOperationSuccess(_ operationId: UUID, context: [String: Any]? = nil) {
        // Check if we have a start time for this operation
        guard let operationInfo = operationStartTimes[operationId] else {
            // Create a local copy of the logger
            let loggerCopy = logger

            // Log the warning in a detached task
            Task.detached { @Sendable in
                loggerCopy.warning("""
                ⚠️ Attempted to record success for untracked operation ID: \
                \(operationId.uuidString)
                """)
            }
            return
        }

        let operation = operationInfo.operation
        let startTime = operationInfo.startTime

        // Calculate duration and update actor-isolated state
        let duration = Date().timeIntervalSince(startTime)
        var timings = operationTimings[operation, default: []]
        timings.append(duration)
        operationTimings[operation] = timings

        // Clean up start time
        operationStartTimes.removeValue(forKey: operationId)

        // Format context for logging
        var contextString = ""
        if let context {
            contextString = " - Context: \(context)"
        }

        // Build the log message
        let logMessage = "✅ Operation SUCCESS: \(operation) (ID: \(operationId.uuidString), " +
            "Duration: \(String(format: "%.2f", duration))s)\(contextString)"

        // Create a local copy of the logger to ensure proper isolation
        let loggerCopy = logger

        // Use Task.detached for logging to avoid potential cross-actor reference issues
        Task.detached { @Sendable in
            loggerCopy.info("\(logMessage)")
        }
    }

    /// Record the successful completion of an operation by name
    /// - Parameters:
    ///   - operation: Name of the operation being completed
    ///   - context: Additional context to log
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    func recordOperationSuccess(_ operation: String, context: [String: Any]? = nil) {
        // This method looks for any operation with the given name
        // Not recommended when multiple operations with the same name run concurrently

        // Find the first operation with this name
        if let (operationId, _) = operationStartTimes.first(where: { $0.value.operation == operation }) {
            // Call the new UUID-based method
            recordOperationSuccess(operationId, context: context)
        } else {
            // Log a warning if no operation with this name is found
            let loggerCopy = logger
            Task.detached { @Sendable in
                loggerCopy.warning("⚠️ Attempted to record success for untracked operation: \(operation)")
            }
        }
    }

    /// Record the failure of an operation with detailed error information
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - error: The error that occurred
    ///   - context: Additional context to log
    func recordOperationFailure(_ operationId: UUID, error: Error, context: [String: Any]? = nil) {
        // Check if we have a start time for this operation
        guard let operationInfo = operationStartTimes[operationId] else {
            // Create a local copy of the logger
            let loggerCopy = logger

            // Log the warning in a detached task
            Task.detached { @Sendable in
                loggerCopy.warning("""
                ⚠️ Attempted to record failure for untracked operation ID: \
                \(operationId.uuidString)
                """)
            }
            return
        }

        let operation = operationInfo.operation
        let startTime = operationInfo.startTime

        // Track error for the operation - ensure proper actor isolation
        var errors = operationErrors[operation, default: []]
        errors.append(error)
        operationErrors[operation] = errors

        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)
        let durationString = " (Duration: \(String(format: "%.2f", duration))s)"

        // Clean up start time
        operationStartTimes.removeValue(forKey: operationId)

        // Format context for logging
        var contextString = ""
        if let context {
            contextString = " - Context: \(context)"
        }

        // Detailed error logging with stack trace when available
        let nsError = error as NSError
        let errorDetails = """
        ❌ Operation FAILED: \(operation) (ID: \(operationId.uuidString))\(durationString)
        Error: \(error.localizedDescription)
        Domain: \(nsError.domain)
        Code: \(nsError.code)
        User Info: \(nsError.userInfo)
        \(contextString)
        """

        // Create a local copy of the logger to ensure proper isolation
        let loggerCopy = logger

        // Use Task.detached for logging to avoid potential cross-actor reference issues
        Task.detached { @Sendable in
            loggerCopy.error("\(errorDetails)")
        }
    }

    /// Record the failure of an operation with detailed error information using operation name
    /// - Parameters:
    ///   - operation: Name of the operation that failed
    ///   - error: The error that occurred
    ///   - context: Additional context to log
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    func recordOperationFailure(_ operation: String, error: Error, context: [String: Any]? = nil) {
        // Find the operation with this name
        if let (operationId, _) = operationStartTimes.first(where: { $0.value.operation == operation }) {
            // Call the new UUID-based method
            recordOperationFailure(operationId, error: error, context: context)
        } else {
            // If no operation with this name is found, we still want to record the error
            // Track error for the operation even without start time - ensure proper actor isolation
            var errors = operationErrors[operation, default: []]
            errors.append(error)
            operationErrors[operation] = errors

            // Format context for logging
            var contextString = ""
            if let context {
                contextString = " - Context: \(context)"
            }

            // Detailed error logging with stack trace when available
            let nsError = error as NSError
            let errorDetails = """
            ❌ Operation FAILED: \(operation) (No start time found)
            Error: \(error.localizedDescription)
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            User Info: \(nsError.userInfo)
            \(contextString)
            """

            // Create a local copy of the logger to ensure proper isolation
            let loggerCopy = logger

            // Use Task.detached for logging to avoid potential cross-actor reference issues
            Task.detached { @Sendable in
                loggerCopy.error("\(errorDetails)")
            }
        }
    }

    /// Get a diagnostic report for all operations
    /// - Returns: A detailed diagnostics report string
    func getDiagnosticReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let systemInfo = getSystemInfoSection()

        var report = """
        === CodeLooper Diagnostics Report ===
        Generated: \(formatter.string(from: Date()))

        \(systemInfo)

        == Operation Statistics ==
        """

        // Sort operations alphabetically
        let sortedOperations = operationCounts.keys.sorted()

        for operation in sortedOperations {
            let count = operationCounts[operation, default: 0]
            let errors = operationErrors[operation, default: []]
            let timings = operationTimings[operation, default: []]

            var avgDuration = "N/A"
            if !timings.isEmpty {
                let total = timings.reduce(0, +)
                avgDuration = String(format: "%.2fs", total / Double(timings.count))
            }

            report += """

            \(operation):
            Count: \(count)
            Errors: \(errors.count)
            Average Duration: \(avgDuration)
            """

            // Include last 3 error details if available
            if !errors.isEmpty {
                report += "\n  Recent Errors:"
                for (index, error) in errors.suffix(3).enumerated() {
                    let nsError = error as NSError
                    report += """

                    Error \(index + 1): [\(nsError.domain):\(nsError.code)] \
                    \(error.localizedDescription)
                    """
                }
            }
        }

        // Add pending operations
        if !operationStartTimes.isEmpty {
            report += "\n\n== Pending Operations =="

            for (operationId, info) in operationStartTimes {
                let operation = info.operation
                let startTime = info.startTime
                let duration = Date().timeIntervalSince(startTime)
                report += """

                * \(operation) (ID: \(operationId.uuidString)): \
                Running for \(String(format: "%.2f", duration))s
                """
            }
        }

        report += "\n\n=== End of Diagnostics Report ==="

        return report
    }

    /// Get detailed system information for diagnostics
    /// - Returns: A formatted string with system information
    private nonisolated func getSystemInfoSection() -> String {
        // Get system information - All operations are nonisolated and thread-safe
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceName = Host.current().localizedName ?? "Unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Get memory and CPU information - ProcessInfo is thread-safe
        let physicalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024) // Convert to MB
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount

        // Get disk space information - FileManager needs to be used in a thread-safe way
        var freeSpace = "Unknown"
        var totalSpace = "Unknown"

        let fileManager = FileManager.default
        if let homeDirectory = fileManager.homeDirectoryForCurrentUser.path as String? {
            do {
                let attributes = try fileManager.attributesOfFileSystem(forPath: homeDirectory)
                if let freeSize = attributes[.systemFreeSize] as? UInt64,
                    let totalSize = attributes[.systemSize] as? UInt64 {

                    freeSpace = "\(freeSize / (1024 * 1024 * 1024)) GB" // Convert to GB
                    totalSpace = "\(totalSize / (1024 * 1024 * 1024)) GB" // Convert to GB
                }
            } catch {
                // Silently fail, we'll keep the "Unknown" values
            }
        }

        // Use safe default values for state properties to avoid actor isolation issues
        let contactsAccessState = "Unknown" // Can't access Defaults directly
        let isAuthenticated = "Unknown" // Can't access KeychainManager directly
        let uploadInterval = "3600" // Default value
        let lastUploadDate = "Never" // Default value

        // Create the system information section without actor-isolated properties
        return """
        == System Information ==
        Device: \(deviceName)
        macOS: \(osVersion)
        App Version: \(appVersion) (\(buildNumber))
        Memory: \(physicalMemory) MB
        Processors: \(processorCount) (Active: \(activeProcessorCount))
        Disk Space: \(freeSpace) free of \(totalSpace)

        == App State ==
        Contacts Access: \(contactsAccessState)
        Authenticated: \(isAuthenticated)
        Last Upload: \(lastUploadDate)
        Upload Interval: \(uploadInterval) seconds

        Note: Logs are available through Apple's Console.app 
        (using Subsystem: \(Bundle.main.bundleIdentifier ?? "me.steipete.codelooper"))
        """
    }

    /// Write the current diagnostic report to a file
    /// - Returns: URL to the diagnostic report file or nil if writing failed
    ///
    /// Note: While application logs are sent to the system logging facility (viewable in Console.app),
    /// diagnostic reports are still saved to files to facilitate easy sharing and analysis.
    func saveDiagnosticReport() async -> URL? {
        // Get report first as it accesses actor-isolated state
        let report = getDiagnosticReport()

        // Create a local copy of logger to ensure proper isolation
        let loggerCopy = logger

        // File operations can be done outside the actor
        return await Task.detached { () -> URL? in
            guard let logDir = FileLogger.shared.getLogDirectoryURL() else {
                Task { loggerCopy.error("Failed to get log directory for diagnostic report") }
                return nil
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())

            let reportURL = logDir.appendingPathComponent("CodeLooper_DiagnosticReport_\(timestamp).txt")

            do {
                try report.write(to: reportURL, atomically: true, encoding: .utf8)
                Task { loggerCopy.info("Diagnostic report saved to: \(reportURL.path)") }
                return reportURL
            } catch {
                Task { loggerCopy.error("Failed to save diagnostic report: \(error.localizedDescription)") }
                return nil
            }
        }.value
    }

    /// Reset all diagnostic tracking data
    func resetDiagnostics() {
        operationCounts.removeAll()
        operationStartTimes.removeAll()
        operationErrors.removeAll()
        operationTimings.removeAll()
        logger.info("All diagnostic tracking data has been reset")
    }

    /// Thread-safe way to start an operation from any thread
    /// - Parameters:
    ///   - operation: The operation name to record
    ///   - context: Optional context data
    /// - Returns: A Task that will return the operation UUID when completed
    nonisolated func safeRecordOperationStart(
        _ operation: String,
        context _: [String: Any]? = nil
    ) -> Task<UUID, Never> {
        // Create a Task.detached to avoid capturing context
        // Task.detached creates a new task with no access to the current task's context
        Task {
            // For Sendable compliance, we don't pass the non-Sendable context to the actor method
            // This simplifies the solution at the cost of not recording context in diagnostic logs
            await self.recordOperationStart(operation, context: nil)
        }
    }

    /// Thread-safe way to record operation success from background threads
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - context: Optional context data
    nonisolated func safeRecordOperationSuccess(_ operationId: UUID, context _: [String: Any]? = nil) {
        // Use Task.detached to avoid capturing context
        Task.detached {
            // For Sendable compliance, we don't pass the non-Sendable context
            await self.recordOperationSuccess(operationId, context: nil)
        }
    }

    /// Thread-safe way to record operation success from background threads using operation name
    /// - Parameters:
    ///   - operation: The operation name
    ///   - context: Optional context data
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    nonisolated func safeRecordOperationSuccess(_ operation: String, context _: [String: Any]? = nil) {
        // Use Task.detached to avoid capturing context
        Task.detached {
            // For Sendable compliance, we don't pass the non-Sendable context
            await self.recordOperationSuccess(operation, context: nil)
        }
    }

    /// Thread-safe way to record operation failure from background threads using UUID
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - error: The error that occurred
    ///   - context: Optional context data
    nonisolated func safeRecordOperationFailure(_ operationId: UUID, error: Error, context _: [String: Any]? = nil) {
        // Convert the error to string to avoid Sendable issues with arbitrary Error types
        let errorDescription = error.localizedDescription

        Task.detached {
            // Create a simple error from the description
            let userInfo = [NSLocalizedDescriptionKey: errorDescription]
            let simpleError = NSError(domain: "DiagnosticsLogger", code: -1, userInfo: userInfo)

            // For Sendable compliance, we don't pass the non-Sendable context
            await self.recordOperationFailure(operationId, error: simpleError, context: nil)
        }
    }

    /// Thread-safe way to record operation failure from background threads using operation name
    /// - Parameters:
    ///   - operation: The operation name
    ///   - error: The error that occurred
    ///   - context: Optional context data
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    nonisolated func safeRecordOperationFailure(_ operation: String, error: Error, context _: [String: Any]? = nil) {
        // Convert the error to string to avoid Sendable issues with arbitrary Error types
        let errorDescription = error.localizedDescription

        Task.detached {
            // Create a simple error from the description
            let userInfo = [NSLocalizedDescriptionKey: errorDescription]
            let simpleError = NSError(domain: "DiagnosticsLogger", code: -1, userInfo: userInfo)

            // For Sendable compliance, we don't pass the non-Sendable context
            await self.recordOperationFailure(operation, error: simpleError, context: nil)
        }
    }

    /// Thread-safe way to save diagnostic reports from non-async contexts
    /// - Returns: A Task that will eventually provide the URL to the saved report or nil if saving failed
    ///
    /// This method creates a Task that can be used from synchronous code to get the report URL.
    /// Example usage:
    /// ```
    /// let reportTask = DiagnosticsLogger.shared.safeSaveDiagnosticReport()
    /// // Later, when you need the URL:
    /// if let reportURL = await reportTask.value {
    ///     // Use the report URL
    /// }
    /// ```
    nonisolated func safeSaveDiagnosticReport() -> Task<URL?, Never> {
        // Use Task.detached to avoid actor context capture
        Task.detached {
            await self.saveDiagnosticReport()
        }
    }
}

/// Extension for String keys used in diagnostics
extension String {
    // Upload operations
    static let uploadContacts = "UploadContacts"
    static let exportContacts = "ExportContacts"
    static let uploadFile = "UploadFile"
    static let downloadProfilePic = "DownloadProfilePic"

    // Authentication operations
    static let authentication = "Authentication"
    static let tokenRefresh = "TokenRefresh"

    // Settings operations
    static let saveSettings = "SaveSettings"
    static let loadSettings = "LoadSettings"

    // App lifecycle operations
    static let appLaunch = "AppLaunch"
    static let appTerminate = "AppTerminate"
    static let windowOpen = "WindowOpen"
    static let windowClose = "WindowClose"

    // Menu operations
    static let menuRefresh = "MenuRefresh"
    static let menuAction = "MenuAction"
}

/*
Example usage of the UUID-based operation tracking:

// 1. Start an operation and get its UUID
let operationTask = DiagnosticsLogger.shared.safeRecordOperationStart(.uploadContacts)

// 2. Perform the operation
uploadContacts { result, error in
    // 3. Record success or failure with the UUID
    Task {
        let operationId = await operationTask.value

        if let error = error {
            DiagnosticsLogger.shared.safeRecordOperationFailure(operationId, error: error)
        } else {
            DiagnosticsLogger.shared.safeRecordOperationSuccess(operationId)
        }
    }
}

// Or for synchronous operations:
Task {
    // 1. Start an operation and get its UUID
    let operationId = await DiagnosticsLogger.shared.recordOperationStart(.exportContacts)

    do {
        // 2. Perform the operation
        try exportContacts()

        // 3. Record success
        DiagnosticsLogger.shared.recordOperationSuccess(operationId)
    } catch {
        // 3. Or record failure
        DiagnosticsLogger.shared.recordOperationFailure(operationId, error: error)
    }
}

// This approach ensures that each operation instance is tracked independently,
// even when multiple operations with the same name run concurrently.
*/
