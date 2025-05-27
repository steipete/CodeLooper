import Foundation
import OpenAI
import AppKit

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
        } catch {
            // Check for specific OpenAI errors
            let errorMessage = error.localizedDescription
            let errorString = String(describing: error)
            
            // Check for authentication errors
            if errorMessage.contains("You didn't provide an API key") || 
               errorMessage.contains("Authorization header") ||
               errorMessage.contains("Bearer auth") {
                throw AIServiceError.connectionFailed("API key not properly configured. Please check your OpenAI API key.")
            }
            
            // Check for other common issues
            if errorMessage.lowercased().contains("unauthorized") || errorMessage.contains("401") || 
               errorString.lowercased().contains("unauthorized") || errorString.contains("401") {
                throw AIServiceError.connectionFailed("Invalid API key. Please check your OpenAI API key.")
            }
            if errorMessage.lowercased().contains("invalid") && errorMessage.lowercased().contains("key") {
                throw AIServiceError.connectionFailed("Invalid API key format or key has been revoked")
            }
            if errorMessage.contains("rate limit") || errorString.contains("rate_limit") {
                throw AIServiceError.connectionFailed("Rate limit exceeded. Please try again later.")
            }
            if errorMessage.contains("insufficient_quota") || errorString.contains("insufficient_quota") {
                throw AIServiceError.connectionFailed("OpenAI quota exceeded. Please check your billing.")
            }
            
            throw AIServiceError.networkError(error)
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
}