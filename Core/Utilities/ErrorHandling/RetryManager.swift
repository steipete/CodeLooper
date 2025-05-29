import Diagnostics
import Foundation

/// Manages retry logic for operations that may fail temporarily.
///
/// RetryManager provides configurable retry strategies with:
/// - Exponential backoff with jitter
/// - Conditional retry based on error types
/// - Maximum attempt limits
/// - Comprehensive logging of retry attempts
/// - Cancellation support for long-running retries
@MainActor
public class RetryManager {
    // MARK: Lifecycle

    /// Initialize a retry manager with custom configuration
    /// - Parameter config: Retry configuration parameters
    public init(config: RetryConfiguration = .default) {
        self.config = config
        self.logger = Logger(category: .utilities)
    }

    // MARK: Public

    /// Retry configuration parameters
    public struct RetryConfiguration: Sendable {
        // MARK: Lifecycle

        public init(
            maxAttempts: Int = 3,
            initialDelay: TimeInterval = 1.0,
            maxDelay: TimeInterval = 30.0,
            backoffMultiplier: Double = 2.0,
            jitterEnabled: Bool = true
        ) {
            self.maxAttempts = maxAttempts
            self.initialDelay = initialDelay
            self.maxDelay = maxDelay
            self.backoffMultiplier = backoffMultiplier
            self.jitterEnabled = jitterEnabled
        }

        // MARK: Public

        public static let `default` = RetryConfiguration()

        public static let aggressive = RetryConfiguration(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 10.0,
            backoffMultiplier: 1.5
        )

        public static let conservative = RetryConfiguration(
            maxAttempts: 2,
            initialDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 3.0
        )

        public let maxAttempts: Int
        public let initialDelay: TimeInterval
        public let maxDelay: TimeInterval
        public let backoffMultiplier: Double
        public let jitterEnabled: Bool
    }

    /// Execute an operation with retry logic
    /// - Parameters:
    ///   - operation: The async operation to retry
    ///   - shouldRetry: Optional predicate to determine if error is retryable
    ///   - onRetry: Optional callback for retry attempts
    /// - Returns: The result of the successful operation
    /// - Throws: The last error if all retries fail
    public func execute<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        shouldRetry: (@Sendable (Error) -> Bool)? = nil,
        onRetry: (@Sendable (Int, Error, TimeInterval) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        var delay = config.initialDelay

        for attempt in 1 ... config.maxAttempts {
            do {
                let result = try await operation()

                // Log successful operation after retries
                if attempt > 1 {
                    logger.info("✅ Operation succeeded after \(attempt) attempts")
                }

                return result

            } catch {
                lastError = error

                // Check if we should retry this error
                let errorIsRetryable = shouldRetry?(error) ?? defaultShouldRetry(error)

                // If this is our last attempt or error is not retryable, throw
                if attempt >= config.maxAttempts || !errorIsRetryable {
                    if !errorIsRetryable {
                        logger.debug("❌ Error is not retryable: \(error)")
                    } else {
                        logger.error("❌ All \(config.maxAttempts) retry attempts exhausted")
                    }
                    throw error
                }

                // Calculate delay with jitter if enabled
                let actualDelay = calculateDelay(baseDelay: delay)

                logger
                    .warning(
                        "⚠️ Attempt \(attempt) failed, retrying in \(String(format: "%.1f", actualDelay))s: \(error)"
                    )

                // Notify retry callback
                onRetry?(attempt, error, actualDelay)

                // Wait before next attempt
                try await Task.sleep(for: .seconds(actualDelay))

                // Update delay for next iteration
                delay = min(delay * config.backoffMultiplier, config.maxDelay)
            }
        }

        // This should never be reached, but provide fallback
        throw lastError ?? RetryError.unknownFailure
    }

    /// Execute an operation with specific retry conditions
    /// - Parameters:
    ///   - operation: The async operation to retry
    ///   - retryableErrors: Specific error types that should be retried
    /// - Returns: The result of the successful operation
    /// - Throws: The last error if all retries fail
    public func execute<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        retryableErrors: [(some Error & Equatable).Type]
    ) async throws -> T {
        try await execute(operation: operation) { error in
            retryableErrors.contains { type(of: error) == $0 }
        }
    }

    // MARK: Private

    private let config: RetryConfiguration
    private let logger: Logger

    /// Default retry logic based on common error patterns
    private func defaultShouldRetry(_ error: Error) -> Bool {
        // Check for retryable error protocols
        if let retryableError = error as? RetryableError {
            return retryableError.isRetryable
        }

        // Check for common retryable error types
        switch error {
        case let urlError as URLError:
            return isRetryableURLError(urlError)
        case let nsError as NSError:
            return isRetryableNSError(nsError)
        default:
            // Default to not retrying unknown errors
            return false
        }
    }

    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .dnsLookupFailed, .cannotFindHost, .httpTooManyRedirects:
            true
        case .userCancelledAuthentication, .badURL, .unsupportedURL:
            false
        default:
            false
        }
    }

    private func isRetryableNSError(_ error: NSError) -> Bool {
        switch error.domain {
        case NSURLErrorDomain:
            // Handle URL errors
            if let urlErrorCode = URLError.Code(rawValue: error.code) {
                return isRetryableURLError(URLError(urlErrorCode))
            } else {
                return false
            }
        case "NWErrorDomain":
            // Network framework errors
            error.code != 57 // Connection refused is usually not retryable
        default:
            false
        }
    }

    private func calculateDelay(baseDelay: TimeInterval) -> TimeInterval {
        guard config.jitterEnabled else { return baseDelay }

        // Add up to 25% jitter to prevent thundering herd
        let jitter = Double.random(in: 0.75 ... 1.25)
        return baseDelay * jitter
    }
}

// MARK: - Supporting Types

/// Protocol for errors that can indicate their retry eligibility
public protocol RetryableError: Error {
    var isRetryable: Bool { get }
}

/// Retry-specific errors
public enum RetryError: Error, LocalizedError {
    case unknownFailure
    case maxAttemptsExceeded(attempts: Int)
    case operationCancelled

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .unknownFailure:
            "An unknown error occurred during retry operation"
        case let .maxAttemptsExceeded(attempts):
            "Operation failed after \(attempts) retry attempts"
        case .operationCancelled:
            "Retry operation was cancelled"
        }
    }
}
