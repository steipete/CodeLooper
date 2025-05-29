import AppKit
import Diagnostics
import Foundation
import Ollama

@MainActor
final class OllamaService: AIService, Loggable {
    // MARK: Lifecycle

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.client = Client(host: baseURL)
    }

    // MARK: Internal

    let provider: AIProvider = .ollama

    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        let jpegData: Data
        do {
            jpegData = try ImageProcessor.optimizeForAI(request.image)
        } catch {
            logger.error("❌ Optimizing image for Ollama failed: \(error.localizedDescription)")
            throw AIServiceError.invalidImage
        }

        do {
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
        } catch {
            logger.error("❌ Ollama image generation failed: \(error.localizedDescription)")
            throw AIErrorMapper.mapError(error, from: .ollama)
        }
    }

    func isAvailable() async -> Bool {
        do {
            _ = try await client.listModels()
            return true
        } catch {
            logger.error("❌ Checking Ollama availability failed: \(error.localizedDescription)")
            return false
        }
    }

    func checkServiceAndModels() async throws -> (serviceRunning: Bool, visionModelsInstalled: [String]) {
        do {
            let models = try await client.listModels()
            let visionModels = models.models
                .map(\.name)
                .filter { name in
                    let lowercased = name.lowercased()
                    return lowercased.contains("llava") || lowercased.contains("bakllava")
                }
            return (true, visionModels)
        } catch {
            logger.error("❌ Checking Ollama service and models failed: \(error.localizedDescription)")
            // Check if it's a connection error (Ollama not running)
            if let urlError = error as? URLError,
               urlError.code == .cannotFindHost || urlError.code == .cannotConnectToHost
            {
                throw AIServiceError.ollamaNotRunning
            }
            throw AIServiceError.networkError(error)
        }
    }

    func supportedModels() -> [AIModel] {
        [.llava, .bakllava, .llava13b, .llava34b]
    }

    // MARK: Private

    private let client: Client
}
