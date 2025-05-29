import Foundation
import os
import OSLog

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
    // MARK: Lifecycle

    private init() {
        // Private initializer for singleton
        logger.info("DiagnosticsLogger initialized on thread: \(Thread.isMainThread ? "main" : "background")")
    }

    // MARK: Internal

    // Singleton instance with thread-safe initialization
    static let shared = DiagnosticsLogger()

    /// Record the start of an operation for timing and tracking purposes
    /// - Parameters:
    ///   - operation: Name of the operation being tracked
    ///   - context: Additional context to log
    /// - Returns: A UUID that uniquely identifies this operation instance
    func recordOperationStart(_ operation: String, context: [String: Any]? = nil) async -> UUID {
        return await operationTracker.recordOperationStart(operation, context: nil)
    }

    /// Record the successful completion of an operation
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - context: Additional context to log
    func recordOperationSuccess(_ operationId: UUID, context: [String: Any]? = nil) async {
        await operationTracker.recordOperationSuccess(operationId, context: nil)
    }

    /// Record the successful completion of an operation by name
    /// - Parameters:
    ///   - operation: Name of the operation being completed
    ///   - context: Additional context to log
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    func recordOperationSuccess(_ operation: String, context: [String: Any]? = nil) async {
        await operationTracker.recordOperationSuccess(operation, context: nil)
    }

    /// Record the failure of an operation with detailed error information
    /// - Parameters:
    ///   - operationId: The UUID returned when starting the operation
    ///   - error: The error that occurred
    ///   - context: Additional context to log
    func recordOperationFailure(_ operationId: UUID, error: Error, context: [String: Any]? = nil) async {
        await operationTracker.recordOperationFailure(operationId, error: error, context: nil)
    }

    /// Record the failure of an operation with detailed error information using operation name
    /// - Parameters:
    ///   - operation: Name of the operation that failed
    ///   - error: The error that occurred
    ///   - context: Additional context to log
    /// - Warning: This method is less reliable - prefer using the UUID-based version to avoid race conditions
    func recordOperationFailure(_ operation: String, error: Error, context: [String: Any]? = nil) async {
        await operationTracker.recordOperationFailure(operation, error: error, context: nil)
    }

    /// Get a diagnostic report for all operations
    /// - Returns: A detailed diagnostics report string
    func getDiagnosticReport() async -> String {
        let stats = await operationTracker.getOperationStatistics()
        return DiagnosticReportGenerator.generateReport(
            counts: stats.counts,
            errors: stats.errors,
            timings: stats.timings,
            pendingOperations: stats.pendingOperations
        )
    }

    /// Write the current diagnostic report to a file
    /// - Returns: URL to the diagnostic report file or nil if writing failed
    ///
    /// Note: While application logs are sent to the system logging facility (viewable in Console.app),
    /// diagnostic reports are still saved to files to facilitate easy sharing and analysis.
    func saveDiagnosticReport() async -> URL? {
        // Get report first as it accesses actor-isolated state
        let report = await getDiagnosticReport()

        // Create a local copy of logger to ensure proper isolation
        let loggerCopy = logger

        // File operations can be done outside the actor
        return await Task.detached { () -> URL? in
            if let reportURL = DiagnosticReportGenerator.saveReport(report) {
                Task { loggerCopy.info("Diagnostic report saved to: \(reportURL.path)") }
                return reportURL
            } else {
                Task { loggerCopy.error("Failed to save diagnostic report") }
                return nil
            }
        }.value
    }

    /// Reset all diagnostic tracking data
    func resetDiagnostics() async {
        await operationTracker.resetOperationData()
        logger.info("All diagnostic tracking data has been reset")
    }

    // MARK: Internal

    let operationTracker = OperationTracker()

    // MARK: Private

    // Primary logger instance
    private let logger = Logger(label: "DiagnosticsLogger", category: .general)
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