import AppKit
import Diagnostics
import Foundation

/// Centralized error handling coordinator for consistent error management.
///
/// This provides standardized error handling patterns including logging,
/// user notification, recovery attempts, and metrics collection.
@MainActor
public final class ErrorHandler {
    // MARK: Lifecycle

    private init() {
        logger.info("ErrorHandler initialized")
    }

    // MARK: Public

    // MARK: - Singleton

    public static let shared = ErrorHandler()

    // MARK: - Public API

    /// Handle an error with appropriate logging, user notification, and recovery
    public func handle(
        _ error: Error,
        context: ErrorContext = .general,
        showAlert: Bool = false,
        attemptRecovery: Bool = false
    ) {
        let appError = normalizeError(error)

        // Log the error with context
        logError(appError, context: context)

        // Show user notification if requested
        if showAlert {
            showErrorAlert(appError, context: context)
        }

        // Attempt recovery if requested and available
        if attemptRecovery {
            attemptErrorRecovery(appError, context: context)
        }

        // Record metrics for monitoring
        recordErrorMetrics(appError, context: context)
    }

    /// Handle an error asynchronously with proper error context
    public func handleAsync(
        _ error: Error,
        context: ErrorContext = .general,
        showAlert: Bool = false,
        attemptRecovery: Bool = false
    ) async {
        await MainActor.run {
            handle(error, context: context, showAlert: showAlert, attemptRecovery: attemptRecovery)
        }
    }

    /// Create a Result type handler for common async operations
    public func handleResult<T>(
        _ result: Result<T, Error>,
        context: ErrorContext = .general,
        showAlert: Bool = false,
        onSuccess: ((T) -> Void)? = nil
    ) {
        switch result {
        case let .success(value):
            onSuccess?(value)
        case let .failure(error):
            handle(error, context: context, showAlert: showAlert)
        }
    }

    /// Execute an operation with automatic error handling
    public func withErrorHandling<T>(
        context: ErrorContext = .general,
        showAlert: Bool = false,
        operation: () throws -> T
    ) -> T? {
        do {
            return try operation()
        } catch {
            handle(error, context: context, showAlert: showAlert)
            return nil
        }
    }

    /// Execute an async operation with automatic error handling
    public func withErrorHandling<T: Sendable>(
        context: ErrorContext = .general,
        showAlert: Bool = false,
        operation: @Sendable () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            await handleAsync(error, context: context, showAlert: showAlert)
            return nil
        }
    }

    // MARK: Private

    // MARK: - Private Implementation

    private let logger = Logger(category: .general)

    /// Normalize any error to AppError for consistent handling
    private func normalizeError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        // Convert common error types to AppError
        let nsError = error as NSError
        switch nsError.domain {
        case NSCocoaErrorDomain:
            return convertCocoaError(nsError)
        case NSURLErrorDomain:
            return convertURLError(nsError)
        default:
            return .unknown(underlying: error)
        }
    }

    /// Convert NSError from Cocoa domain to AppError
    private func convertCocoaError(_ error: NSError) -> AppError {
        switch error.code {
        case NSFileReadNoSuchFileError:
            let path = error.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileNotFound(path: path)
        case NSFileReadNoPermissionError:
            let path = error.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileAccessDenied(path: path, operation: "read")
        case NSFileWriteNoPermissionError:
            let path = error.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileAccessDenied(path: path, operation: "write")
        default:
            return .unknown(underlying: error)
        }
    }

    /// Convert NSURLError to AppError
    private func convertURLError(_ error: NSError) -> AppError {
        let url = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String ?? "unknown"

        switch error.code {
        case NSURLErrorTimedOut:
            return .networkTimeout(url: url, duration: 30) // Default timeout
        case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            return .networkConnectionFailed(url: url, underlying: error)
        default:
            return .networkConnectionFailed(url: url, underlying: error)
        }
    }

    /// Log error with appropriate level and context
    private func logError(_ error: AppError, context: ErrorContext) {
        let contextInfo = [
            "error_context": context.rawValue,
            "error_category": error.category.rawValue,
        ]

        error.log(logger: logger, context: contextInfo)
    }

    /// Show error alert to user if appropriate
    private func showErrorAlert(_ error: AppError, context: ErrorContext) {
        // Skip showing alerts in test environment
        if Constants.isTestEnvironment {
            logger.info("Skipping error alert in test mode: \(error.category.rawValue)")
            return
        }

        // Only show alerts for user-facing errors in certain contexts
        guard shouldShowAlert(for: error, context: context) else { return }

        let alert = NSAlert()
        alert.messageText = getAlertTitle(for: error, context: context)
        alert.informativeText = error.errorDescription ?? "An unknown error occurred"
        alert.alertStyle = getAlertStyle(for: error)

        if let recovery = error.recoverySuggestion {
            alert.informativeText += "\n\n\(recovery)"
        }

        alert.addButton(withTitle: "OK")

        // Add additional buttons based on error type
        if canAttemptRecovery(for: error) {
            alert.addButton(withTitle: "Retry")
        }

        let response = alert.runModal()

        // Handle retry button
        if response == .alertSecondButtonReturn, canAttemptRecovery(for: error) {
            attemptErrorRecovery(error, context: context)
        }
    }

    /// Determine if an alert should be shown for this error
    private func shouldShowAlert(for error: AppError, context: ErrorContext) -> Bool {
        switch context {
        case .userInitiated, .criticalOperation:
            true
        case .backgroundOperation:
            error.category == .accessibility || error.category == .system
        case .general:
            error.category != .monitoring && error.category != .network
        }
    }

    /// Get appropriate alert title for the error
    private func getAlertTitle(for error: AppError, context _: ErrorContext) -> String {
        switch error.category {
        case .accessibility:
            "Accessibility Permission Required"
        case .jsHook:
            "JavaScript Hook Error"
        case .aiAnalysis:
            "AI Analysis Error"
        case .network:
            "Network Error"
        case .configuration:
            "Configuration Error"
        default:
            "Error"
        }
    }

    /// Get appropriate alert style for the error
    private func getAlertStyle(for error: AppError) -> NSAlert.Style {
        switch error.category {
        case .system, .accessibility:
            .critical
        case .configuration, .validation:
            .warning
        default:
            .informational
        }
    }

    /// Check if recovery can be attempted for this error
    private func canAttemptRecovery(for error: AppError) -> Bool {
        switch error {
        case .serviceNotAvailable, .hookConnectionLost, .networkConnectionFailed:
            true
        default:
            false
        }
    }

    /// Attempt automatic recovery for the error
    private func attemptErrorRecovery(_ error: AppError, context _: ErrorContext) {
        logger.info("Attempting recovery for error: \(error.category.rawValue)")

        Task { @MainActor in
            switch error {
            case .serviceNotAvailable:
                await attemptServiceRestart()
            case let .hookConnectionLost(windowId):
                await attemptHookReconnection(windowId: windowId)
            case .networkConnectionFailed:
                await attemptNetworkRetry()
            default:
                logger.info("No automatic recovery available for error type: \(error.category.rawValue)")
            }
        }
    }

    /// Attempt to restart a failed service
    private func attemptServiceRestart() async {
        logger.info("Attempting service restart...")
        // Service restart logic would go here
    }

    /// Attempt to reconnect a lost JavaScript hook
    private func attemptHookReconnection(windowId: String) async {
        logger.info("Attempting hook reconnection for window: \(windowId)")
        // Hook reconnection logic would go here
    }

    /// Attempt to retry a failed network operation
    private func attemptNetworkRetry() async {
        logger.info("Attempting network retry...")
        // Network retry logic would go here
    }

    /// Record error metrics for monitoring and analysis
    private func recordErrorMetrics(_ error: AppError, context: ErrorContext) {
        // This could integrate with analytics or crash reporting
        logger.debug("Recording error metrics: \(error.category.rawValue) in \(context.rawValue)")
    }
}

// MARK: - Supporting Types

/// Context in which an error occurred, affects handling behavior
public enum ErrorContext: String, CaseIterable {
    case general = "General"
    case userInitiated = "User Initiated"
    case backgroundOperation = "Background Operation"
    case criticalOperation = "Critical Operation"
}

// MARK: - Convenience Extensions

public extension Result where Failure == Error {
    /// Handle the result using ErrorHandler
    @MainActor
    func handle(
        context: ErrorContext = .general,
        showAlert: Bool = false,
        onSuccess: ((Success) -> Void)? = nil
    ) {
        ErrorHandler.shared.handleResult(self, context: context, showAlert: showAlert, onSuccess: onSuccess)
    }
}

public extension Task where Failure == Error {
    /// Create a task with automatic error handling
    @MainActor
    static func withErrorHandling(
        context: ErrorContext = .general,
        showAlert: Bool = false,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task<Success?, Never> {
        Task<Success?, Never> {
            await ErrorHandler.shared.withErrorHandling(
                context: context,
                showAlert: showAlert,
                operation: operation
            )
        }
    }
}
