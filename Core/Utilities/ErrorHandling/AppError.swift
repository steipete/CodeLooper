import Diagnostics
import Foundation

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

    // MARK: - Code Signing/Notarization Errors
    
    case codeSigningFailed(reason: String, underlying: Error?)
    case notarizationFailed(reason: String, statusCode: Int?)
    case certificateMissing(type: String)

    // MARK: - Unknown/Generic Errors

    case unknown(underlying: Error)
    case internalInconsistency(message: String)

    // MARK: Public

    // MARK: - Error Properties

    public var errorDescription: String? {
        switch self {
        // Service Errors
        case let .serviceInitializationFailed(service, underlying):
            "Failed to initialize \(service)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .serviceNotAvailable(service):
            "\(service) is not available"
        case let .serviceDependencyMissing(service, dependency):
            "\(service) requires \(dependency) but it's not available"
        // Accessibility Errors
        case .accessibilityPermissionDenied:
            "Accessibility permission is required but not granted"
        case let .accessibilityElementNotFound(locator):
            "Accessibility element not found: \(locator)"
        case let .accessibilityQueryFailed(query, underlying):
            "Accessibility query failed: \(query)\(underlying.map { " (\($0.localizedDescription))" } ?? "")"
        case let .axorcistError(message, code):
            "AXorcist error (\(code)): \(message)"
        // JavaScript Hook Errors
        case let .hookInstallationFailed(windowId, underlying):
            "Failed to install JavaScript hook for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .hookConnectionLost(windowId):
            "JavaScript hook connection lost for window \(windowId)"
        case let .hookCommandFailed(command, windowId, underlying):
            "Hook command '\(command)' failed for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .noActiveHook(windowId):
            "No active JavaScript hook for window \(windowId)"
        // Monitoring Errors
        case let .monitoringStartFailed(underlying):
            "Failed to start monitoring\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .windowDetectionFailed(underlying):
            "Window detection failed\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .processMonitoringFailed(pid, underlying):
            "Process monitoring failed for PID \(pid)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        // AI Analysis Errors
        case let .aiAnalysisFailed(windowId, underlying):
            "AI analysis failed for window \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .aiProviderNotConfigured(provider):
            "AI provider '\(provider)' is not configured"
        case let .aiRequestRateLimited(retryAfter):
            "AI request rate limited\(retryAfter.map { ", retry after \($0) seconds" } ?? "")"
        case let .aiResponseParsingFailed(response):
            "Failed to parse AI response: \(response.prefix(100))..."
        // Window Management Errors
        case let .windowNotFound(windowId):
            "Window not found: \(windowId)"
        case let .windowOperationFailed(operation, windowId, underlying):
            "Window operation '\(operation)' failed for \(windowId)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .multipleWindowsFound(expected, found):
            "Expected \(expected) but found \(found) windows"
        // Configuration Errors
        case let .configurationInvalid(setting, value):
            "Invalid configuration for \(setting): \(value)"
        case let .configurationMissing(setting):
            "Missing required configuration: \(setting)"
        case let .defaultsAccessFailed(key, underlying):
            "Failed to access user defaults key '\(key)'\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        // File System Errors
        case let .fileNotFound(path):
            "File not found: \(path)"
        case let .fileAccessDenied(path, operation):
            "Access denied for \(operation) on: \(path)"
        case let .directoryCreationFailed(path, underlying):
            "Failed to create directory: \(path)\(underlying.map { " (\($0.localizedDescription))" } ?? "")"
        // Network Errors
        case let .networkConnectionFailed(url, underlying):
            "Network connection failed to \(url)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        case let .networkTimeout(url, duration):
            "Network timeout after \(duration)s for \(url)"
        case let .serverError(statusCode, message):
            "Server error \(statusCode)\(message.map { ": \($0)" } ?? "")"
        // Validation Errors
        case let .invalidInput(field, value, reason):
            "Invalid input for \(field): '\(value)' - \(reason)"
        case let .missingRequiredField(field):
            "Missing required field: \(field)"
        case let .valueOutOfRange(field, value, range):
            "Value for \(field) is out of range: '\(value)' (expected: \(range))"
        // System Errors
        case let .systemResourceExhausted(resource):
            "System resource exhausted: \(resource)"
        case let .systemPermissionDenied(permission):
            "System permission denied: \(permission)"
        case let .systemOperationFailed(operation, underlying):
            "System operation '\(operation)' failed\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        // Code Signing/Notarization Errors
        case let .codeSigningFailed(reason, underlying):
            "Code signing failed: \(reason)\(underlying.map { " (\($0.localizedDescription))" } ?? "")"
        case let .notarizationFailed(reason, statusCode):
            "Notarization failed: \(reason)\(statusCode.map { " (status: \($0))" } ?? "")"
        case let .certificateMissing(type):
            "Certificate missing: \(type)"
        // Unknown/Generic Errors
        case let .unknown(underlying):
            "Unknown error: \(underlying.localizedDescription)"
        case let .internalInconsistency(message):
            "Internal inconsistency: \(message)"
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
             let .systemOperationFailed(_, underlying),
             let .codeSigningFailed(_, underlying):
            underlying
        case let .unknown(underlying):
            underlying
        default:
            nil
        }
    }

    /// Get recovery suggestions for the error
    public var recoverySuggestion: String? {
        switch self {
        case .accessibilityPermissionDenied:
            "Please grant accessibility permission in System Settings > Privacy & Security > Accessibility"
        case .aiProviderNotConfigured:
            "Configure an AI provider in Settings > AI Analysis"
        case let .aiRequestRateLimited(retryAfter):
            "Please wait \(retryAfter.map { "\(Int($0)) seconds" } ?? "a moment") before trying again"
        case .serviceNotAvailable:
            "Try restarting the application"
        case .networkConnectionFailed:
            "Check your internet connection and try again"
        case .configurationMissing:
            "Please check your settings and ensure all required fields are filled"
        case .certificateMissing:
            "Install a valid Developer ID Application certificate in your keychain"
        case .codeSigningFailed:
            "Ensure your Developer ID certificate is valid and accessible"
        case .notarizationFailed:
            "Check your App Store Connect credentials and try again"
        default:
            nil
        }
    }

    /// Get the error category for logging and metrics
    public var category: ErrorCategory {
        switch self {
        case .serviceInitializationFailed, .serviceNotAvailable, .serviceDependencyMissing:
            .service
        case .accessibilityPermissionDenied, .accessibilityElementNotFound, .accessibilityQueryFailed, .axorcistError:
            .accessibility
        case .hookInstallationFailed, .hookConnectionLost, .hookCommandFailed, .noActiveHook:
            .jsHook
        case .monitoringStartFailed, .windowDetectionFailed, .processMonitoringFailed:
            .monitoring
        case .aiAnalysisFailed, .aiProviderNotConfigured, .aiRequestRateLimited, .aiResponseParsingFailed:
            .aiAnalysis
        case .windowNotFound, .windowOperationFailed, .multipleWindowsFound:
            .windowManagement
        case .configurationInvalid, .configurationMissing, .defaultsAccessFailed:
            .configuration
        case .fileNotFound, .fileAccessDenied, .directoryCreationFailed:
            .fileSystem
        case .networkConnectionFailed, .networkTimeout, .serverError:
            .network
        case .invalidInput, .missingRequiredField, .valueOutOfRange:
            .validation
        case .systemResourceExhausted, .systemPermissionDenied, .systemOperationFailed:
            .system
        case .codeSigningFailed, .notarizationFailed, .certificateMissing:
            .system
        case .unknown, .internalInconsistency:
            .unknown
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

public extension AppError {
    /// Log the error with appropriate level and context
    func log(logger: Logger, level: LogLevel = .error, context: [String: Any] = [:]) {
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
        case .notice:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        case .fault:
            logger.critical("\(message)")
        @unknown default:
            logger.error("\(message)")
        }
    }
}
