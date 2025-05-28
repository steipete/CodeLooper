import Foundation
import OpenAI
import AppKit
import Diagnostics

@MainActor
final class OpenAIService: AIService {
    let provider: AIProvider = .openAI
    private let client: OpenAI
    
    init(apiKey: String) {
        self.client = OpenAI(apiToken: apiKey)
    }
    
    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        guard let imageData = request.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw AIServiceError.invalidImage
        }
        
        let base64Image = jpegData.base64EncodedString()
        
        let textContent = ChatQuery.ChatCompletionMessageParam.UserMessageParam.Content.VisionContent.ChatCompletionContentPartTextParam(text: request.prompt)
        let imageContent = ChatQuery.ChatCompletionMessageParam.UserMessageParam.Content.VisionContent.ChatCompletionContentPartImageParam(
            imageUrl: .init(url: "data:image/jpeg;base64,\(base64Image)", detail: .auto)
        )
        
        let userMessage = ChatQuery.ChatCompletionMessageParam.UserMessageParam(
            content: .vision([
                .chatCompletionContentPartTextParam(textContent),
                .chatCompletionContentPartImageParam(imageContent)
            ])
        )
        
        let messages: [ChatQuery.ChatCompletionMessageParam] = [.user(userMessage)]
        
        let query = ChatQuery(
            messages: messages,
            model: Model(request.model.rawValue),
            maxTokens: 1000
        )
        
        do {
            let response = try await client.chats(query: query)
            
            guard let content = response.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            return ImageAnalysisResponse(
                text: content,
                model: request.model,
                tokensUsed: response.usage?.totalTokens
            )
        } catch let openAIError as APIError {
            // Handle specific OpenAI APIErrors
            switch openAIError.type {
            case "invalid_request_error":
                if openAIError.message.lowercased().contains("api key") {
                    throw AIServiceError.apiKeyMissing
                } else if openAIError.message.lowercased().contains("model not found") {
                    throw AIServiceError.unsupportedModel // Or modelNotFound if we want to pass the name
                }
                throw AIServiceError.invalidResponse // Or a more specific one based on message
            case "authentication_error", "permission_error":
                throw AIServiceError.apiKeyMissing // Typically API key related
            case "api_error", "internal_error":
                throw AIServiceError.serviceUnavailable // General server-side issue
            case "rate_limit_error":
                throw AIServiceError.serviceUnavailable // Or a specific rate limit error if defined
            case "insufficient_quota":
                 throw AIServiceError.serviceUnavailable // Or a specific quota error
            default:
                // Fallback for other OpenAI APIErrors
                logger.warning("Unhandled OpenAI APIError type: \(openAIError.type ?? "unknown"). Message: \(openAIError.message)")
                throw AIServiceError.networkError(openAIError)
            }
        } catch let urlError as URLError {
            // Handle URLErrors specifically for better network messages
            throw AIServiceError.networkError(urlError) // AIServiceError.networkError has specific URLError handling
        } catch {
            // General catch-all, try to interpret based on message if possible
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("api key") || errorMessage.contains("unauthorized") || errorMessage.contains("bearer auth") {
                throw AIServiceError.apiKeyMissing
            }
            if errorMessage.contains("rate_limit") || errorMessage.contains("rate limit") {
                throw AIServiceError.serviceUnavailable // Rate limit
            }
            if errorMessage.contains("insufficient_quota") {
                throw AIServiceError.serviceUnavailable // Quota issue
            }
            logger.error("Unhandled error during OpenAI request: \(error)")
            throw AIServiceError.networkError(error) // Fallback to generic network error
        }
    }
    
    func isAvailable() async -> Bool {
        // Simply return true if we have a client with an API key
        // The actual test will happen when we try to use it
        return true
    }
    
    func supportedModels() -> [AIModel] {
        [.gpt4o, .gpt4TurboVision, .gpt4oMini, .o1, .clipVitL14]
    }
    
    private let logger = Logger(category: .api)
}