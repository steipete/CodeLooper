import Foundation
import Diagnostics

/// Comprehensive error types for the CodeLooper application.
///
/// This provides a structured approach to error handling with proper categorization,
/// context information, and recovery suggestions.
public enum AppError: Error, LocalizedError, CustomStringConvertible {
    // MARK: - Service Errors
    case serviceInitializationFailed(service: String, underlying: Error?)
    case serviceNotAvailable(service: String)
    case serviceDependencyMissing(service: String, dependency: String)
    
    // MARK: - Accessibility Errors
    case accessibilityPermissionDenied
    case accessibilityElementNotFound(locator: String)
    case accessibilityQueryFailed(query: String, underlying: Error?)
    case axorcistError(message: String, code: Int)
    
    // MARK: - JavaScript Hook Errors
    case hookInstallationFailed(windowId: String, underlying: Error?)
    case hookConnectionLost(windowId: String)
    case hookCommandFailed(command: String, windowId: String, underlying: Error?)
    case noActiveHook(windowId: String)
    
    // MARK: - Monitoring Errors
    case monitoringStartFailed(underlying: Error?)
    case windowDetectionFailed(underlying: Error?)
    case processMonitoringFailed(pid: Int32, underlying: Error?)
    
    // MARK: - AI Analysis Errors
    case aiAnalysisFailed(windowId: String, underlying: Error?)
    case aiProviderNotConfigured(provider: String)
    case aiRequestRateLimited(retryAfter: TimeInterval?)
    case aiResponseParsingFailed(response: String)
    
    // MARK: - Window Management Errors
    case windowNotFound(windowId: String)
    case windowOperationFailed(operation: String, windowId: String, underlying: Error?)
    case multipleWindowsFound(expected: String, found: Int)
    
    // MARK: - Configuration Errors
    case configurationInvalid(setting: String, value: String)
    case configurationMissing(setting: String)
    case defaultsAccessFailed(key: String, underlying: Error?)
    
    // MARK: - File System Errors
    case fileNotFound(path: String)
    case fileAccessDenied(path: String, operation: String)
    case directoryCreationFailed(path: String, underlying: Error?)
    
    // MARK: - Network Errors
    case networkConnectionFailed(url: String, underlying: Error?)
    case networkTimeout(url: String, duration: TimeInterval)
    case serverError(statusCode: Int, message: String?)
    
    // MARK: - Validation Errors
    case invalidInput(field: String, value: String, reason: String)
    case missingRequiredField(field: String)
    case valueOutOfRange(field: String, value: String, range: String)
    
    // MARK: - System Errors
    case systemResourceExhausted(resource: String)
    case systemPermissionDenied(permission: String)
    case systemOperationFailed(operation: String, underlying: Error?)
    
    // MARK: - Unknown/Generic Errors
    case unknown(underlying: Error)
    case internalInconsistency(message: String)
    
    // MARK: - Error Properties
    
    public var errorDescription: String? {
        switch self {
        // Service Errors
        case let .serviceInitializationFailed(service, underlying):
            return "Failed to initialize \(service)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .serviceNotAvailable(service):
            return "\(service) is not available"
        case let .serviceDependencyMissing(service, dependency):
            return "\(service) requires \(dependency) but it's not available"
            
        // Accessibility Errors
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required but not granted"
        case let .accessibilityElementNotFound(locator):
            return "Accessibility element not found: \(locator)"
        case let .accessibilityQueryFailed(query, underlying):
            return "Accessibility query failed: \(query)\(underlying.map { " (\($0.localizedDescription))" } ?? "")"
        case let .axorcistError(message, code):
            return "AXorcist error (\(code)): \(message)"
            
        // JavaScript Hook Errors
        case let .hookInstallationFailed(windowId, underlying):
            return "Failed to install JavaScript hook for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .hookConnectionLost(windowId):
            return "JavaScript hook connection lost for window \(windowId)"
        case let .hookCommandFailed(command, windowId, underlying):
            return "Hook command '\(command)' failed for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .noActiveHook(windowId):
            return "No active JavaScript hook for window \(windowId)"
            
        // Monitoring Errors
        case let .monitoringStartFailed(underlying):
            return "Failed to start monitoring\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .windowDetectionFailed(underlying):
            return "Window detection failed\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .processMonitoringFailed(pid, underlying):
            return "Process monitoring failed for PID \(pid)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
            
        // AI Analysis Errors
        case let .aiAnalysisFailed(windowId, underlying):
            return "AI analysis failed for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .aiProviderNotConfigured(provider):
            return "AI provider '\(provider)' is not configured"
        case let .aiRequestRateLimited(retryAfter):
            return "AI request rate limited\(retryAfter.map { ", retry after \($0) seconds" } ?? "")"
        case let .aiResponseParsingFailed(response):
            return "Failed to parse AI response: \(response.prefix(100))..."
            
        // Window Management Errors
        case let .windowNotFound(windowId):
            return "Window not found: \(windowId)"
        case let .windowOperationFailed(operation, windowId, underlying):
            return "Window operation '\(operation)' failed for \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .multipleWindowsFound(expected, found):
            return "Expected \(expected) but found \(found) windows"
            
        // Configuration Errors
        case let .configurationInvalid(setting, value):
            return "Invalid configuration for \(setting): \(value)"
        case let .configurationMissing(setting):
            return "Missing required configuration: \(setting)"
        case let .defaultsAccessFailed(key, underlying):
            return "Failed to access user defaults key '\(key)'\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
            
        // File System Errors
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .fileAccessDenied(path, operation):
            return "Access denied for \(operation) on: \(path)"
        case let .directoryCreationFailed(path, underlying):
            return "Failed to create directory: \(path)\(underlying.map { " (\($0.localizedDescription))" } ?? "")"
            
        // Network Errors
        case let .networkConnectionFailed(url, underlying):
            return "Network connection failed to \(url)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .networkTimeout(url, duration):
            return "Network timeout after \(duration)s for \(url)"
        case let .serverError(statusCode, message):
            return "Server error \(statusCode)\(message.map { ": \($0)" } ?? "")"
            
        // Validation Errors
        case let .invalidInput(field, value, reason):
            return "Invalid input for \(field): '\(value)' - \(reason)"
        case let .missingRequiredField(field):
            return "Missing required field: \(field)"
        case let .valueOutOfRange(field, value, range):
            return "Value for \(field) is out of range: '\(value)' (expected: \(range))"
            
        // System Errors
        case let .systemResourceExhausted(resource):
            return "System resource exhausted: \(resource)"
        case let .systemPermissionDenied(permission):
            return "System permission denied: \(permission)"
        case let .systemOperationFailed(operation, underlying):
            return "System operation '\(operation)' failed\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
            
        // Unknown/Generic Errors
        case let .unknown(underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        case let .internalInconsistency(message):
            return "Internal inconsistency: \(message)"
        }
    }
    
    public var description: String {
        errorDescription ?? "Unknown error"
    }
    
    /// Get the underlying error if available
    public var underlyingError: Error? {
        switch self {
        case let .serviceInitializationFailed(_, underlying),
             let .accessibilityQueryFailed(_, underlying),
             let .hookInstallationFailed(_, underlying),
             let .hookCommandFailed(_, _, underlying),
             let .monitoringStartFailed(underlying),
             let .windowDetectionFailed(underlying),
             let .processMonitoringFailed(_, underlying),
             let .aiAnalysisFailed(_, underlying),
             let .windowOperationFailed(_, _, underlying),
             let .defaultsAccessFailed(_, underlying),
             let .directoryCreationFailed(_, underlying),
             let .networkConnectionFailed(_, underlying),
             let .systemOperationFailed(_, underlying):
            return underlying
        case let .unknown(underlying):
            return underlying
        default:
            return nil
        }
    }
    
    /// Get recovery suggestions for the error
    public var recoverySuggestion: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Please grant accessibility permission in System Settings > Privacy & Security > Accessibility"
        case .aiProviderNotConfigured:
            return "Configure an AI provider in Settings > AI Analysis"
        case let .aiRequestRateLimited(retryAfter):
            return "Please wait \(retryAfter.map { "\(Int($0)) seconds" } ?? "a moment") before trying again"
        case .serviceNotAvailable:
            return "Try restarting the application"
        case .networkConnectionFailed:
            return "Check your internet connection and try again"
        case .configurationMissing:
            return "Please check your settings and ensure all required fields are filled"
        default:
            return nil
        }
    }
    
    /// Get the error category for logging and metrics
    public var category: ErrorCategory {
        switch self {
        case .serviceInitializationFailed, .serviceNotAvailable, .serviceDependencyMissing:
            return .service
        case .accessibilityPermissionDenied, .accessibilityElementNotFound, .accessibilityQueryFailed, .axorcistError:
            return .accessibility
        case .hookInstallationFailed, .hookConnectionLost, .hookCommandFailed, .noActiveHook:
            return .jsHook
        case .monitoringStartFailed, .windowDetectionFailed, .processMonitoringFailed:
            return .monitoring
        case .aiAnalysisFailed, .aiProviderNotConfigured, .aiRequestRateLimited, .aiResponseParsingFailed:
            return .aiAnalysis
        case .windowNotFound, .windowOperationFailed, .multipleWindowsFound:
            return .windowManagement
        case .configurationInvalid, .configurationMissing, .defaultsAccessFailed:
            return .configuration
        case .fileNotFound, .fileAccessDenied, .directoryCreationFailed:
            return .fileSystem
        case .networkConnectionFailed, .networkTimeout, .serverError:
            return .network
        case .invalidInput, .missingRequiredField, .valueOutOfRange:
            return .validation
        case .systemResourceExhausted, .systemPermissionDenied, .systemOperationFailed:
            return .system
        case .unknown, .internalInconsistency:
            return .unknown
        }
    }
}

// MARK: - Supporting Types

public enum ErrorCategory: String, CaseIterable {
    case service = "Service"
    case accessibility = "Accessibility"
    case jsHook = "JavaScript Hook"
    case monitoring = "Monitoring"
    case aiAnalysis = "AI Analysis"
    case windowManagement = "Window Management"
    case configuration = "Configuration"
    case fileSystem = "File System"
    case network = "Network"
    case validation = "Validation"
    case system = "System"
    case unknown = "Unknown"
}

// MARK: - Error Logging Extension

extension AppError {
    /// Log the error with appropriate level and context
    public func log(logger: Logger, level: LogLevel = .error, context: [String: Any] = [:]) {
        let message = "\(description)\(recoverySuggestion.map { " | Suggestion: \($0)" } ?? "")"
        
        var logContext = context
        logContext["error_category"] = category.rawValue
        if let underlying = underlyingError {
            logContext["underlying_error"] = String(describing: underlying)
        }
        
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        @unknown default:
            logger.error("\(message)")
        }
    }
}