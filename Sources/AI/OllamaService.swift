import AppKit
import Diagnostics
import Foundation
import Ollama

@MainActor
final class OllamaService: AIService {
    // MARK: Lifecycle

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.client = Client(host: baseURL)
    }

    // MARK: Internal

    let provider: AIProvider = .ollama

    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        guard let imageData = request.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
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
        } catch let urlError as URLError {
            // AIServiceError.networkError will provide specific messages for URLError codes
            // For Ollama, .cannotFindHost or .cannotConnectToHost strongly implies Ollama isn't running or accessible
            if urlError.code == .cannotFindHost || urlError.code == .cannotConnectToHost {
                throw AIServiceError.ollamaNotRunning // More specific than generic connectionFailed
            }
            throw AIServiceError.networkError(urlError)
        } catch {
            // General catch-all
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("model"),
               errorMessage.contains("not found") || errorMessage.contains("does not exist")
            {
                throw AIServiceError.modelNotFound(request.model.rawValue)
            }
            // Check for other common Ollama issues if any specific error types are known from the Ollama library
            // For now, fallback to a generic network error or service unavailable
            logger.error("Unhandled error during Ollama request: \(error)")
            throw AIServiceError.serviceUnavailable // Could be various issues with Ollama server itself
        }
    }

    func isAvailable() async -> Bool {
        do {
            _ = try await client.listModels()
            return true
        } catch {
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

    private let logger = Logger(category: .api)
}
