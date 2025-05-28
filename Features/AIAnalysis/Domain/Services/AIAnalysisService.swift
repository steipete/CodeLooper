import Defaults
import Foundation
import SwiftUI

public enum AIProvider: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case openAI = "OpenAI"
    case ollama = "Ollama"

    // MARK: Public

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .ollama: "Ollama (Local)"
        }
    }
}

public enum AIModel: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    // OpenAI Models
    case gpt4o = "gpt-4o"
    case gpt4TurboVision = "gpt-4-turbo-2024-04-09"
    case gpt4oMini = "gpt-4o-mini"
    case o1
    case clipVitL14 = "image-embedding-ada-002"

    // Ollama Models
    case llava
    case bakllava
    case llava13b = "llava:13b"
    case llava34b = "llava:34b"

    // MARK: Public

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        // OpenAI Models
        case .gpt4o: "GPT-4o (Flagship)"
        case .gpt4TurboVision: "GPT-4 Turbo with Vision"
        case .gpt4oMini: "GPT-4o-mini"
        case .o1: "o1"
        case .clipVitL14: "CLIP ViT-L/14 embeddings"
        // Ollama Models
        case .llava: "LLaVA"
        case .bakllava: "BakLLaVA"
        case .llava13b: "LLaVA 13B"
        case .llava34b: "LLaVA 34B"
        }
    }

    public var provider: AIProvider {
        switch self {
        case .gpt4o, .gpt4TurboVision, .gpt4oMini, .o1, .clipVitL14:
            .openAI
        case .llava, .bakllava, .llava13b, .llava34b:
            .ollama
        }
    }
}

public struct ImageAnalysisRequest {
    // MARK: Lifecycle

    public init(image: NSImage, prompt: String, model: AIModel) {
        self.image = image
        self.prompt = prompt
        self.model = model
    }

    // MARK: Public

    public let image: NSImage
    public let prompt: String
    public let model: AIModel
}

public struct ImageAnalysisResponse {
    // MARK: Lifecycle

    public init(text: String, model: AIModel, tokensUsed: Int? = nil) {
        self.text = text
        self.model = model
        self.tokensUsed = tokensUsed
    }

    // MARK: Public

    public let text: String
    public let model: AIModel
    public let tokensUsed: Int?
}

public enum AIServiceError: Error, LocalizedError {
    case apiKeyMissing
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case unsupportedModel
    case serviceUnavailable
    case connectionFailed(String)
    case modelNotFound(String)
    case ollamaNotRunning
    case noVisionModelsInstalled

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing. Please configure it in settings."
        case .invalidImage:
            return "Invalid image provided."
        case let .networkError(error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network settings."
                case .cannotFindHost:
                    return "Cannot connect to the AI service. Please check the URL/host settings."
                case .timedOut:
                    return "Connection timed out. The AI service may be slow or unavailable."
                default:
                    return "Network error: \(urlError.localizedDescription)"
                }
            }
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service."
        case .unsupportedModel:
            return "The selected model is not supported."
        case .serviceUnavailable:
            return "AI service is currently unavailable."
        case let .connectionFailed(details):
            return "Connection failed: \(details)"
        case let .modelNotFound(model):
            return "Model '\(model)' not found. Please ensure it's installed in Ollama."
        case .ollamaNotRunning:
            return "Ollama is not running. Please start Ollama to use local AI models."
        case .noVisionModelsInstalled:
            return "No vision models are installed in Ollama. Please install a vision model to analyze images."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing:
            "Go to Settings > AI to configure your API key."
        case .networkError:
            "Check your internet connection and firewall settings."
        case .serviceUnavailable, .connectionFailed:
            "For Ollama: Make sure Ollama is running (ollama serve). For OpenAI: Check your API key and internet connection."
        case let .modelNotFound(model):
            "Run 'ollama pull \(model)' in Terminal to download the model."
        case .ollamaNotRunning:
            "Run 'ollama serve' in Terminal or start the Ollama app."
        case .noVisionModelsInstalled:
            "Run 'ollama pull llava' or 'ollama pull bakllava' to install a vision model."
        default:
            nil
        }
    }
}

@MainActor
public protocol AIService {
    var provider: AIProvider { get }
    func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse
    func isAvailable() async -> Bool
    func supportedModels() -> [AIModel]
}

@MainActor
public final class AIServiceManager: ObservableObject {
    // MARK: Lifecycle

    private init() {
        configureWithCurrentDefaults()
    }

    // MARK: Public

    public static let shared = AIServiceManager()

    @Published public private(set) var currentProvider: AIProvider = Defaults[.aiProvider]
    @Published public private(set) var isAvailable = false

    public func configureWithCurrentDefaults() {
        let provider = Defaults[.aiProvider]
        let apiKey = APIKeyService.shared.loadOpenAIKey()
        let ollamaURL = URL(string: Defaults[.ollamaBaseURL])

        self.configure(provider: provider, apiKey: apiKey, baseURL: ollamaURL)
    }

    public func configure(provider: AIProvider, apiKey: String? = nil, baseURL: URL? = nil) {
        currentProvider = provider

        switch provider {
        case .openAI:
            if let apiKey {
                openAIService = OpenAIService(apiKey: apiKey)
            }
        case .ollama:
            if let baseURL {
                ollamaService = OllamaService(baseURL: baseURL)
            } else {
                ollamaService = OllamaService()
            }
        }

        Task {
            await checkAvailability()
        }
    }

    public func analyzeImage(_ request: ImageAnalysisRequest) async throws -> ImageAnalysisResponse {
        let service = try getCurrentService()
        return try await service.analyzeImage(request)
    }

    public func supportedModels() -> [AIModel] {
        do {
            let service = try getCurrentService()
            return service.supportedModels()
        } catch {
            return []
        }
    }

    public func isServiceAvailable() async -> Bool {
        do {
            let service = try getCurrentService()
            return await service.isAvailable()
        } catch {
            return false
        }
    }

    // MARK: Private

    private var openAIService: OpenAIService?
    private var ollamaService: OllamaService?

    private func getCurrentService() throws -> AIService {
        switch currentProvider {
        case .openAI:
            guard let service = openAIService else {
                throw AIServiceError.apiKeyMissing
            }
            return service
        case .ollama:
            guard let service = ollamaService else {
                throw AIServiceError.serviceUnavailable
            }
            return service
        }
    }

    private func checkAvailability() async {
        do {
            let service = try getCurrentService()
            isAvailable = await service.isAvailable()
        } catch {
            isAvailable = false
        }
    }
}
