import Foundation

extension Task where Success == Never, Failure == Never {
    /// Run a task with a timeout, throwing a TimeoutError if the timeout is exceeded
    /// Modern implementation using async/await without task groups
    /// - Parameters:
    ///   - seconds: The timeout in seconds
    ///   - operation: The async operation to run
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the timeout is exceeded, or any error thrown by the operation
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        // Create a task for the operation
        let operationTask = Task<T, Error> {
            try await operation()
        }

        // Create a separate task for the timeout
        let timeoutTask = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(seconds))
            // If we reach here, the timeout has expired
            operationTask.cancel()
        }

        do {
            // Wait for the operation task to complete
            let result = try await operationTask.value

            // Operation completed successfully, cancel the timeout task
            timeoutTask.cancel()

            return result
        } catch is CancellationError {
            // If we got here with a cancellation error, it was likely due to the timeout
            throw TimeoutError(seconds: seconds)
        } catch {
            // Propagate any other errors from the operation
            timeoutTask.cancel()
            throw error
        }
    }
}

/// Error thrown when a task exceeds its allotted execution time.
///
/// TimeoutError provides:
/// - The timeout duration that was exceeded
/// - User-friendly error message for display
/// - Sendable compliance for safe concurrent usage
struct TimeoutError: Error, LocalizedError, Sendable {
    let seconds: TimeInterval

    var errorDescription: String? {
        "Operation timed out after \(String(format: "%.1f", seconds)) seconds"
    }
}
