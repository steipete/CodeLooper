import Foundation
import os
import OSLog

/// Handles operation tracking functionality for the DiagnosticsLogger
actor OperationTracker {
    // MARK: Internal
    
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

    /// Reset all operation tracking data
    func resetOperationData() {
        operationCounts.removeAll()
        operationStartTimes.removeAll()
        operationErrors.removeAll()
        operationTimings.removeAll()
    }

    /// Get operation statistics for reporting
    func getOperationStatistics() -> (
        counts: [String: Int],
        errors: [String: [Error]],
        timings: [String: [TimeInterval]],
        pendingOperations: [UUID: (operation: String, startTime: Date)]
    ) {
        return (
            counts: operationCounts,
            errors: operationErrors,
            timings: operationTimings,
            pendingOperations: operationStartTimes
        )
    }

    // MARK: Private

    // Primary logger instance
    private let logger = Logger(label: "OperationTracker", category: .general)

    // Operation tracking state - all state is actor-isolated
    private var operationCounts: [String: Int] = [:]
    private var operationStartTimes: [UUID: (operation: String, startTime: Date)] = [:]
    private var operationErrors: [String: [Error]] = [:]
    private var operationTimings: [String: [TimeInterval]] = [:]
}