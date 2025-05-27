import Foundation
import Ollama
import AppKit

@MainActor
final class OllamaService: AIService {
    let provider: AIProvider = .ollama
    private let client: Client
    
    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.client = Client(host: baseURL)
    }
    
    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        guard let imageData = request.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
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
            // Check if it's a URLError to provide more specific error messages
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotFindHost, .cannotConnectToHost:
                    throw AIServiceError.connectionFailed("Cannot connect to Ollama at \(client.host). Make sure Ollama is running.")
                case .notConnectedToInternet:
                    throw AIServiceError.connectionFailed("No internet connection.")
                case .timedOut:
                    throw AIServiceError.connectionFailed("Connection timed out. Ollama may be slow or unresponsive.")
                default:
                    throw AIServiceError.networkError(error)
                }
            }
            
            // Check if error message contains model not found
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("model") && errorMessage.contains("not found") {
                throw AIServiceError.modelNotFound(request.model.rawValue)
            }
            
            throw AIServiceError.networkError(error)
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
                .map { $0.name }
                .filter { name in
                    let lowercased = name.lowercased()
                    return lowercased.contains("llava") || lowercased.contains("bakllava")
                }
            return (true, visionModels)
        } catch {
            // Check if it's a connection error (Ollama not running)
            if let urlError = error as? URLError,
               (urlError.code == .cannotFindHost || urlError.code == .cannotConnectToHost) {
                throw AIServiceError.ollamaNotRunning
            }
            throw AIServiceError.networkError(error)
        }
    }
    
    func supportedModels() -> [AIModel] {
        [.llava, .bakllava, .llava13b, .llava34b]
    }
}