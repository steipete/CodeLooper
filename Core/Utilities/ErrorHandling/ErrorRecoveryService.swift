import AppKit
import Diagnostics
import Foundation

/// Centralized error recovery service providing automated recovery strategies and user notifications.
///
/// ErrorRecoveryService provides:
/// - Intelligent error analysis and recovery suggestions
/// - Automated retry with exponential backoff
/// - User notification with recovery actions
/// - Fallback strategies for critical operations
/// - Error aggregation and reporting
@MainActor
public class ErrorRecoveryService {
    // MARK: Lifecycle
    
    public init() {
        self.retryManager = RetryManager(config: .default)
        self.logger = Logger(category: .errorHandling)
    }
    
    // MARK: Public
    
    /// Recovery strategy for different types of errors
    public enum RecoveryStrategy {
        case retry(maxAttempts: Int)
        case fallback(operation: () async throws -> Void)
        case userIntervention(message: String, actions: [RecoveryAction])
        case ignore
        case escalate(to: EscalationLevel)
    }
    
    /// Recovery actions that users can take
    public struct RecoveryAction {
        public let title: String
        public let action: () async -> Void
        
        public init(title: String, action: @escaping () async -> Void) {
            self.title = title
            self.action = action
        }
    }
    
    /// Escalation levels for critical errors
    public enum EscalationLevel {
        case logWarning
        case notifyUser
        case disableFeature
        case shutdownGracefully
    }
    
    /// Handle an error with automatic recovery strategies
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - fallback: Optional fallback operation to try
    /// - Returns: True if error was recovered, false if manual intervention is needed
    @discardableResult
    public func handleError(
        _ error: Error,
        context: String = "",
        fallback: (() async throws -> Void)? = nil
    ) async -> Bool {
        logger.error("🚨 Handling error in \(context): \(error)")
        
        let strategy = determineRecoveryStrategy(for: error)
        
        switch strategy {
        case .retry(let maxAttempts):
            return await attemptRetry(error: error, maxAttempts: maxAttempts, context: context)
            
        case .fallback(let operation):
            return await attemptFallback(operation: operation, context: context)
            
        case .userIntervention(let message, let actions):
            await presentUserRecoveryOptions(message: message, actions: actions)
            return false
            
        case .ignore:
            logger.debug("🔕 Ignoring error as per recovery strategy")
            return true
            
        case .escalate(let level):
            await escalateError(error, level: level, context: context)
            return false
        }
    }
    
    /// Execute an operation with automatic error recovery
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - context: Description of the operation for logging
    ///   - recoveryStrategy: Optional custom recovery strategy
    /// - Returns: The result of the operation
    /// - Throws: Error if recovery fails
    public func executeWithRecovery<T>(
        operation: @escaping () async throws -> T,
        context: String,
        recoveryStrategy: RecoveryStrategy? = nil
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            logger.warning("⚠️ Operation '\(context)' failed, attempting recovery: \(error)")
            
            let strategy = recoveryStrategy ?? determineRecoveryStrategy(for: error)
            
            switch strategy {
            case .retry(let maxAttempts):
                return try await retryManager.execute(
                    operation: operation,
                    onRetry: { attempt, error, delay in
                        self.logger.info("🔄 Retrying '\(context)' (attempt \(attempt)) after \(delay)s: \(error)")
                    }
                )
                
            case .fallback(let fallbackOp):
                do {
                    try await fallbackOp()
                    // If fallback succeeds, retry the original operation once
                    return try await operation()
                } catch {
                    logger.error("❌ Fallback failed for '\(context)': \(error)")
                    throw error
                }
                
            default:
                // For non-retry strategies, handle the error and re-throw
                await handleError(error, context: context)
                throw error
            }
        }
    }
    
    // MARK: Private
    
    private let retryManager: RetryManager
    private let logger: Logger
    
    /// Determine the appropriate recovery strategy for an error
    private func determineRecoveryStrategy(for error: Error) -> RecoveryStrategy {
        // Check for specific error types with known recovery strategies
        switch error {
        case let hookError as CursorJSHook.HookError:
            return recoveryStrategyForHookError(hookError)
            
        case let urlError as URLError:
            return recoveryStrategyForURLError(urlError)
            
        case let nsError as NSError:
            return recoveryStrategyForNSError(nsError)
            
        default:
            // Default strategy based on error characteristics
            if let retryableError = error as? RetryableError, retryableError.isRetryable {
                return .retry(maxAttempts: 3)
            } else {
                return .userIntervention(
                    message: "An unexpected error occurred: \(error.localizedDescription)",
                    actions: [
                        RecoveryAction(title: "Retry") { /* Default retry */ },
                        RecoveryAction(title: "Cancel") { /* Do nothing */ }
                    ]
                )
            }
        }
    }
    
    private func recoveryStrategyForHookError(_ error: CursorJSHook.HookError) -> RecoveryStrategy {
        switch error {
        case .timeout, .connectionLost, .handshakeFailed:
            return .retry(maxAttempts: 3)
            
        case .portInUse:
            return .userIntervention(
                message: "Port conflict detected. Another instance may be running.",
                actions: [
                    RecoveryAction(title: "Retry with different port") {
                        // Implementation would switch to alternative port
                    },
                    RecoveryAction(title: "Kill other instances") {
                        // Implementation would terminate other instances
                    }
                ]
            )
            
        case .applescriptPermissionDenied:
            return .userIntervention(
                message: "Automation permissions are required for CodeLooper to function.",
                actions: [
                    RecoveryAction(title: "Open System Settings") {
                        await self.openAutomationSettings()
                    },
                    RecoveryAction(title: "Continue without automation") {
                        // Implementation would disable affected features
                    }
                ]
            )
            
        case .networkError:
            return .retry(maxAttempts: 5)
            
        case .cancelled:
            return .ignore
            
        default:
            return .escalate(to: .notifyUser)
        }
    }
    
    private func recoveryStrategyForURLError(_ error: URLError) -> RecoveryStrategy {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost:
            return .retry(maxAttempts: 3)
        case .notConnectedToInternet:
            return .userIntervention(
                message: "Internet connection is required.",
                actions: [
                    RecoveryAction(title: "Check Network Settings") {
                        await self.openNetworkSettings()
                    }
                ]
            )
        default:
            return .escalate(to: .logWarning)
        }
    }
    
    private func recoveryStrategyForNSError(_ error: NSError) -> RecoveryStrategy {
        switch error.domain {
        case NSURLErrorDomain:
            return recoveryStrategyForURLError(URLError(.init(rawValue: error.code) ?? .unknown))
        case NSCocoaErrorDomain:
            if error.code == NSFileReadNoPermissionError {
                return .userIntervention(
                    message: "File access permission is required.",
                    actions: [
                        RecoveryAction(title: "Grant Permission") {
                            // Implementation would request file access
                        }
                    ]
                )
            }
            return .escalate(to: .logWarning)
        default:
            return .escalate(to: .logWarning)
        }
    }
    
    private func attemptRetry(error: Error, maxAttempts: Int, context: String) async -> Bool {
        logger.info("🔄 Attempting retry recovery for '\(context)' (max \(maxAttempts) attempts)")
        // In a real implementation, this would coordinate with the retry manager
        // For now, just log the attempt
        return false
    }
    
    private func attemptFallback(operation: () async throws -> Void, context: String) async -> Bool {
        do {
            logger.info("🛡️ Attempting fallback recovery for '\(context)'")
            try await operation()
            return true
        } catch {
            logger.error("❌ Fallback failed for '\(context)': \(error)")
            return false
        }
    }
    
    private func presentUserRecoveryOptions(message: String, actions: [RecoveryAction]) async {
        logger.info("👤 Presenting recovery options to user: \(message)")
        
        let alert = NSAlert()
        alert.messageText = "Recovery Required"
        alert.informativeText = message
        alert.alertStyle = .warning
        
        for action in actions {
            alert.addButton(withTitle: action.title)
        }
        
        let response = alert.runModal()
        let actionIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        if actionIndex >= 0 && actionIndex < actions.count {
            await actions[actionIndex].action()
        }
    }
    
    private func escalateError(_ error: Error, level: EscalationLevel, context: String) async {
        switch level {
        case .logWarning:
            logger.warning("⚠️ Escalated error in '\(context)': \(error)")
            
        case .notifyUser:
            logger.error("🚨 Critical error in '\(context)': \(error)")
            await showErrorNotification(error: error, context: context)
            
        case .disableFeature:
            logger.error("⛔ Disabling feature due to error in '\(context)': \(error)")
            // Implementation would disable the affected feature
            
        case .shutdownGracefully:
            logger.critical("💥 Critical system error, initiating graceful shutdown: \(error)")
            // Implementation would initiate graceful shutdown
        }
    }
    
    private func showErrorNotification(error: Error, context: String) async {
        let content = UNMutableNotificationContent()
        content.title = "CodeLooper Error"
        content.body = "Error in \(context): \(error.localizedDescription)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to show error notification: \(error)")
        }
    }
    
    private func openAutomationSettings() async {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openNetworkSettings() async {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Shared Instance

public extension ErrorRecoveryService {
    static let shared = ErrorRecoveryService()
}