import Foundation

/// An actor that ensures continuations are only resumed once
/// This prevents potential crashes from multiple resume operations
/// on the same continuation
actor ContinuationGuard {
    private var hasResumed = false

    /// Attempts to resume with a success value
    /// - Parameter value: The value to resume with
    /// - Returns: Whether this was the first resume attempt (true) or a duplicate (false)
    func resume(returning value: some Any) -> Bool {
        guard !hasResumed else { return false }
        hasResumed = true
        return true
    }

    /// Attempts to resume with an error
    /// - Parameter error: The error to resume with
    /// - Returns: Whether this was the first resume attempt (true) or a duplicate (false)
    func resume(throwing error: Error) -> Bool {
        guard !hasResumed else { return false }
        hasResumed = true
        return true
    }
}
