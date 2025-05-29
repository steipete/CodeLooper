import Diagnostics
import Foundation

/// Utility for standardized error handling across the application.
///
/// ErrorHandlingUtility provides consistent error handling patterns,
/// logging, and recovery strategies. This eliminates duplicated error
/// handling code and ensures uniform error reporting throughout the app.
///
/// ## Topics
///
/// ### Error Handling
/// - ``handle(_:in:operation:)``
/// - ``handleAsync(_:in:operation:)``
/// - ``handleAndLog(_:logger:context:)``
///
/// ### Recovery Strategies
/// - ``withErrorRecovery(_:recovery:)``
/// - ``withRetryOnError(_:maxAttempts:operation:)``
public enum ErrorHandlingUtility {
    
    /// Handles errors with standardized logging and optional recovery
    /// - Parameters:
    ///   - operation: The throwing operation to execute
    ///   - context: Description of what operation was being performed
    ///   - logger: Logger to use for error reporting
    ///   - recovery: Optional recovery closure
    /// - Returns: The result of the operation or recovery
    public static func handle<T>(
        _ operation: @autoclosure () throws -> T,
        in context: String,
        logger: Logger,
        recovery: (() -> T)? = nil
    ) -> T? {
        do {
            return try operation()
        } catch {
            logger.error("❌ \(context) failed: \(error.localizedDescription)")
            
            if let recovery = recovery {
                logger.info("🔄 Attempting error recovery for: \(context)")
                return recovery()
            }
            
            return nil
        }
    }
    
    /// Handles async errors with standardized logging and optional recovery
    /// - Parameters:
    ///   - operation: The async throwing operation to execute
    ///   - context: Description of what operation was being performed
    ///   - logger: Logger to use for error reporting
    ///   - recovery: Optional async recovery closure
    /// - Returns: The result of the operation or recovery
    public static func handleAsync<T>(
        _ operation: @escaping () async throws -> T,
        in context: String,
        logger: Logger,
        recovery: (() async -> T)? = nil
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            logger.error("❌ \(context) failed: \(error.localizedDescription)")
            
            if let recovery = recovery {
                logger.info("🔄 Attempting error recovery for: \(context)")
                return await recovery()
            }
            
            return nil
        }
    }
    
    /// Logs an error with standardized format and context
    /// - Parameters:
    ///   - error: The error to log
    ///   - logger: Logger to use for error reporting
    ///   - context: Additional context about when the error occurred
    public static func handleAndLog(
        _ error: Error,
        logger: Logger,
        context: String
    ) {
        let errorType = String(describing: type(of: error))
        logger.error("❌ [\(errorType)] \(context): \(error.localizedDescription)")
        
        // Log additional debug information for development
        #if DEBUG
        logger.debug("Error details: \(String(reflecting: error))")
        #endif
    }
    
    /// Executes an operation with error recovery fallback
    /// - Parameters:
    ///   - operation: The primary operation to attempt
    ///   - recovery: Fallback operation if primary fails
    /// - Returns: Result from primary operation or recovery
    public static func withErrorRecovery<T>(
        _ operation: @autoclosure () throws -> T,
        recovery: @autoclosure () -> T
    ) -> T {
        do {
            return try operation()
        } catch {
            return recovery()
        }
    }
    
    /// Executes an async operation with error recovery fallback
    /// - Parameters:
    ///   - operation: The primary async operation to attempt
    ///   - recovery: Fallback async operation if primary fails
    /// - Returns: Result from primary operation or recovery
    public static func withAsyncErrorRecovery<T>(
        _ operation: @escaping () async throws -> T,
        recovery: @escaping () async -> T
    ) async -> T {
        do {
            return try await operation()
        } catch {
            return await recovery()
        }
    }
    
    /// Executes an operation with retry logic
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - operation: The operation to retry
    /// - Returns: The result if successful
    /// - Throws: The last error if all attempts fail
    public static func withRetryOnError<T>(
        maxAttempts: Int = 3,
        _ operation: @escaping () throws -> T
    ) throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Simple linear backoff - could be enhanced with exponential backoff
                    Thread.sleep(forTimeInterval: Double(attempt))
                }
            }
        }
        
        throw lastError ?? NSError(
            domain: "ErrorHandlingUtility",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]
        )
    }
    
    /// Creates a standardized error context for operations
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - component: Component or service performing the operation
    ///   - details: Additional details about the operation
    /// - Returns: Formatted context string
    public static func createContext(
        operation: String,
        component: String,
        details: String? = nil
    ) -> String {
        var context = "\(component).\(operation)"
        if let details = details {
            context += " (\(details))"
        }
        return context
    }
}

/// Protocol for types that want standardized error handling
public protocol ErrorHandling {
    var errorLogger: Logger { get }
    
    /// Handle an error with automatic logging and context
    func handleError<T>(_ operation: @autoclosure () throws -> T, context: String) -> T?
    
    /// Handle an async error with automatic logging and context
    func handleAsyncError<T>(_ operation: @escaping () async throws -> T, context: String) async -> T?
}

public extension ErrorHandling {
    func handleError<T>(_ operation: @autoclosure () throws -> T, context: String) -> T? {
        return ErrorHandlingUtility.handle(
            try operation(),
            in: context,
            logger: errorLogger
        )
    }
    
    func handleAsyncError<T>(_ operation: @escaping () async throws -> T, context: String) async -> T? {
        return await ErrorHandlingUtility.handleAsync(
            operation,
            in: context,
            logger: errorLogger
        )
    }
}
