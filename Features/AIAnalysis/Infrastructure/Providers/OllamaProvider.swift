import AppKit
import Diagnostics
import Foundation
import Ollama
import Utilities

@MainActor
final class OllamaService: AIService, Loggable {
    // MARK: Lifecycle

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.client = Client(host: baseURL)
    }

    // MARK: Internal

    let provider: AIProvider = .ollama

    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        let jpegData = try await ErrorHandlingUtility.handle(
            operation: { try ImageProcessor.optimizeForAI(request.image) },
            context: "Optimizing image for Ollama",
            logger: logger,
            recoverableError: { _ in throw AIServiceError.invalidImage }
        )

        return try await ErrorHandlingUtility.handle(
            operation: {
                let response = try await client.generate(
                    model: Model.ID(stringLiteral: request.model.rawValue),
                    prompt: request.prompt,
                    images: [jpegData]
                )
                
                return ImageAnalysisResponse(
                    text: response.response,
                    model: request.model,
                    tokensUsed: nil
                )
            },
            context: "Ollama image generation",
            logger: logger,
            recoverableError: { error in
                throw AIErrorMapper.mapError(error, from: .ollama)
            }
        )
    }

    func isAvailable() async -> Bool {
        await ErrorHandlingUtility.handle(
            operation: {
                _ = try await client.listModels()
                return true
            },
            context: "Checking Ollama availability",
            logger: logger,
            fallback: false
        )
    }

    func checkServiceAndModels() async throws -> (serviceRunning: Bool, visionModelsInstalled: [String]) {
        try await ErrorHandlingUtility.handle(
            operation: {
                let models = try await client.listModels()
                let visionModels = models.models
                    .map(\.name)
                    .filter { name in
                        let lowercased = name.lowercased()
                        return lowercased.contains("llava") || lowercased.contains("bakllava")
                    }
                return (true, visionModels)
            },
            context: "Checking Ollama service and models",
            logger: logger,
            recoverableError: { error in
                // Check if it's a connection error (Ollama not running)
                if let urlError = error as? URLError,
                   urlError.code == .cannotFindHost || urlError.code == .cannotConnectToHost
                {
                    throw AIServiceError.ollamaNotRunning
                }
                throw AIServiceError.networkError(error)
            }
        )
    }

    func supportedModels() -> [AIModel] {
        [.llava, .bakllava, .llava13b, .llava34b]
    }

    // MARK: Private

    private let client: Client
}
