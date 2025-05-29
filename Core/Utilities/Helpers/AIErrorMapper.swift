import Foundation

/// Maps AI provider-specific errors to standardized AIServiceError cases.
///
/// AIErrorMapper provides consistent error handling across different AI providers
/// by normalizing various provider-specific error formats into the application's
/// standard AIServiceError enumeration. This eliminates duplicate error mapping
/// logic in individual provider implementations.
///
/// ## Topics
///
/// ### Error Mapping
/// - ``mapError(_:from:)``
/// - ``mapURLError(_:)``
/// - ``mapHTTPError(_:responseData:)``
///
/// ### Provider-Specific Mapping
/// - ``mapOpenAIError(_:)``
/// - ``mapOllamaError(_:)``
public enum AIErrorMapper {
    // MARK: Public

    /// Maps provider-specific errors to AIServiceError
    /// - Parameters:
    ///   - error: The original error from the AI provider
    ///   - provider: The AI provider that generated the error
    /// - Returns: Mapped AIServiceError
    public static func mapError(_ error: Error, from provider: AIProvider) -> AIServiceError {
        // Handle common error types first
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }

        // Handle provider-specific errors
        switch provider {
        case .openAI:
            return mapOpenAIError(error)
        case .ollama:
            return mapOllamaError(error)
        }
    }

    /// Maps URLError instances to appropriate AIServiceError cases
    /// - Parameter urlError: The URLError to map
    /// - Returns: Corresponding AIServiceError
    public static func mapURLError(_ urlError: URLError) -> AIServiceError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            .networkError(URLError(.notConnectedToInternet))

        case .timedOut:
            .serviceUnavailable

        case .cannotConnectToHost, .cannotFindHost:
            .networkError(URLError(.cannotConnectToHost))

        case .badServerResponse:
            .invalidResponse

        case .userCancelledAuthentication, .userAuthenticationRequired:
            .apiKeyMissing

        case .badURL:
            .connectionFailed("Invalid AI service URL")

        default:
            .networkError(urlError)
        }
    }

    /// Maps HTTP response errors to AIServiceError
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - responseData: Optional response body data
    /// - Returns: Mapped AIServiceError
    public static func mapHTTPError(_ statusCode: Int, responseData: Data? = nil) -> AIServiceError {
        switch statusCode {
        case 400:
            return .invalidResponse

        case 401:
            return .apiKeyMissing

        case 403:
            return .apiKeyMissing

        case 404:
            return .connectionFailed("AI service endpoint not found")

        case 408:
            return .serviceUnavailable

        case 429:
            return .serviceUnavailable

        case 500 ... 599:
            return .serviceUnavailable

        default:
            let message = extractErrorMessage(from: responseData) ?? "HTTP \(statusCode)"
            return .connectionFailed("Server error: \(message)")
        }
    }

    // MARK: Private

    /// Maps NSError instances to appropriate AIServiceError cases
    /// - Parameter nsError: The NSError to map
    /// - Returns: Corresponding AIServiceError
    private static func mapNSError(_ nsError: NSError) -> AIServiceError {
        switch nsError.domain {
        case NSURLErrorDomain:
            // Convert NSError to URLError and map
            let urlError = URLError(URLError.Code(rawValue: nsError.code))
            return mapURLError(urlError)

        case "NSPOSIXErrorDomain":
            switch nsError.code {
            case 61: // Connection refused
                return .connectionFailed("AI service connection refused")
            case 60: // Operation timed out
                return .serviceUnavailable
            default:
                return .networkError(nsError)
            }

        default:
            return .networkError(nsError)
        }
    }

    /// Maps OpenAI-specific errors
    /// - Parameter error: The OpenAI error
    /// - Returns: Mapped AIServiceError
    private static func mapOpenAIError(_ error: Error) -> AIServiceError {
        let errorDescription = error.localizedDescription.lowercased()

        // Check for common OpenAI error patterns
        if errorDescription.contains("api key") || errorDescription.contains("authentication") {
            return .apiKeyMissing
        }

        if errorDescription.contains("rate limit") || errorDescription.contains("quota") {
            return .serviceUnavailable
        }

        if errorDescription.contains("model") && errorDescription.contains("not found") {
            return .modelNotFound("Requested OpenAI model is not available")
        }

        if errorDescription.contains("content") && errorDescription.contains("policy") {
            return .invalidResponse
        }

        if errorDescription.contains("tokens") || errorDescription.contains("length") {
            return .invalidResponse
        }

        return .networkError(error)
    }

    /// Maps Ollama-specific errors
    /// - Parameter error: The Ollama error
    /// - Returns: Mapped AIServiceError
    private static func mapOllamaError(_ error: Error) -> AIServiceError {
        let errorDescription = error.localizedDescription.lowercased()

        // Check for common Ollama error patterns
        if errorDescription
            .contains("model") &&
            (errorDescription.contains("not found") || errorDescription.contains("not available"))
        {
            return .modelNotFound("Requested Ollama model is not available or not downloaded")
        }

        if errorDescription.contains("connection") && errorDescription.contains("refused") {
            return .ollamaNotRunning
        }

        if errorDescription.contains("out of memory") || errorDescription.contains("insufficient") {
            return .serviceUnavailable
        }

        if errorDescription.contains("invalid"), errorDescription.contains("format") {
            return .invalidResponse
        }

        return .networkError(error)
    }

    /// Extracts error message from response data
    /// - Parameter data: Response data that might contain error information
    /// - Returns: Extracted error message or nil
    private static func extractErrorMessage(from data: Data?) -> String? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        // Try common error message fields
        if let message = json["error"] as? String {
            return message
        }

        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String
        {
            return message
        }

        if let message = json["message"] as? String {
            return message
        }

        return nil
    }
}
