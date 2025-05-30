import AppKit
import Diagnostics
import Foundation
import OpenAI

@MainActor
final class OpenAIService: AIService, Loggable {
    // MARK: Lifecycle

    init(apiKey: String) {
        self.client = OpenAI(apiToken: apiKey)
    }

    // MARK: Internal

    let provider: AIProvider = .openAI

    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        let base64Image: String
        do {
            base64Image = try ImageProcessor.convertToBase64(request.image)
        } catch {
            logger.error("❌ Converting image to base64 for OpenAI failed: \(error.localizedDescription)")
            throw AIServiceError.invalidImage
        }

        let textContent = ChatQuery.ChatCompletionMessageParam.UserMessageParam.Content.VisionContent
            .ChatCompletionContentPartTextParam(text: request.prompt)
        let imageContent = ChatQuery.ChatCompletionMessageParam.UserMessageParam.Content.VisionContent
            .ChatCompletionContentPartImageParam(
                imageUrl: .init(url: "data:image/jpeg;base64,\(base64Image)", detail: .auto)
            )

        let userMessage = ChatQuery.ChatCompletionMessageParam.UserMessageParam(
            content: .vision([
                .chatCompletionContentPartTextParam(textContent),
                .chatCompletionContentPartImageParam(imageContent),
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
            logger.error("❌ OpenAI chat completion failed: \(error.localizedDescription)")
            throw AIErrorMapper.mapError(error, from: .openAI)
        }
    }

    func isAvailable() async -> Bool {
        // Simply return true if we have a client with an API key
        // The actual test will happen when we try to use it
        true
    }

    func supportedModels() -> [AIModel] {
        [.gpt4o, .gpt4TurboVision, .gpt4oMini, .o1, .clipVitL14]
    }

    // MARK: Private

    private let client: OpenAI
}
