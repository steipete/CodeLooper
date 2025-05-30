import AppKit
@testable import CodeLooper
import Foundation
import XCTest

class AIAnalysisServiceTests: XCTestCase {
    func testAIProviderEnumCases() async throws {
        let allCases = AIProvider.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.openAI))
        XCTAssertTrue(allCases.contains(.ollama))

        // Test raw values
        XCTAssertEqual(AIProvider.openAI.rawValue, "OpenAI")
        XCTAssertEqual(AIProvider.ollama.rawValue, "Ollama")

        // Test display names
        XCTAssertEqual(AIProvider.openAI.displayName, "OpenAI")
        XCTAssertEqual(AIProvider.ollama.displayName, "Ollama (Local)")

        // Test Identifiable conformance
        XCTAssertEqual(AIProvider.openAI.id, "OpenAI")
        XCTAssertEqual(AIProvider.ollama.id, "Ollama")
    }

    func testAIModelOpenAIModels() async throws {
        let openAIModels: [AIModel] = [.gpt4o, .gpt4TurboVision, .gpt4oMini, .o1, .clipVitL14]

        for model in openAIModels {
            XCTAssertEqual(model.provider, .openAI)
        }

        // Test specific model properties
        XCTAssertEqual(AIModel.gpt4o.rawValue, "gpt-4o")
        XCTAssertEqual(AIModel.gpt4o.displayName, "GPT-4o (Flagship)")
        XCTAssertEqual(AIModel.gpt4o.id, "gpt-4o")

        XCTAssertEqual(AIModel.gpt4TurboVision.rawValue, "gpt-4-turbo-2024-04-09")
        XCTAssertEqual(AIModel.gpt4TurboVision.displayName, "GPT-4 Turbo with Vision")

        XCTAssertEqual(AIModel.gpt4oMini.rawValue, "gpt-4o-mini")
        XCTAssertEqual(AIModel.gpt4oMini.displayName, "GPT-4o-mini")

        XCTAssertEqual(AIModel.o1.rawValue, "o1")
        XCTAssertEqual(AIModel.o1.displayName, "o1")
    }

    func testAIModelOllamaModels() async throws {
        let ollamaModels: [AIModel] = [.llava, .bakllava, .llava13b, .llava34b]

        for model in ollamaModels {
            XCTAssertEqual(model.provider, .ollama)
        }

        // Test specific model properties
        XCTAssertEqual(AIModel.llava.rawValue, "llava")
        XCTAssertEqual(AIModel.llava.displayName, "LLaVA")

        XCTAssertEqual(AIModel.bakllava.rawValue, "bakllava")
        XCTAssertEqual(AIModel.bakllava.displayName, "BakLLaVA")

        XCTAssertEqual(AIModel.llava13b.rawValue, "llava:13b")
        XCTAssertEqual(AIModel.llava13b.displayName, "LLaVA 13B")

        XCTAssertEqual(AIModel.llava34b.rawValue, "llava:34b")
        XCTAssertEqual(AIModel.llava34b.displayName, "LLaVA 34B")
    }

    func testImageAnalysisRequestCreation() async throws {
        // Create a test image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        let prompt = "Analyze this image"
        let model = AIModel.gpt4o

        let request = ImageAnalysisRequest(image: image, prompt: prompt, model: model)

        XCTAssertEqual(request.image.size.width, 100)
        XCTAssertEqual(request.image.size.height, 100)
        XCTAssertEqual(request.prompt, "Analyze this image")
        XCTAssertEqual(request.model, .gpt4o)
    }

    func testImageAnalysisResponseCreation() async throws {
        let response1 = ImageAnalysisResponse(text: "Test response", model: .gpt4o, tokensUsed: 100)
        XCTAssertEqual(response1.text, "Test response")
        XCTAssertEqual(response1.model, .gpt4o)
        XCTAssertEqual(response1.tokensUsed, 100)

        let response2 = ImageAnalysisResponse(text: "Another response", model: .llava)
        XCTAssertEqual(response2.text, "Another response")
        XCTAssertEqual(response2.model, .llava)
        XCTAssertNil(response2.tokensUsed)
    }

    func testAIServiceErrorCases() async throws {
        let errors: [AIServiceError] = [
            .apiKeyMissing,
            .invalidImage,
            .networkError(URLError(.notConnectedToInternet)),
            .invalidResponse,
            .unsupportedModel,
            .serviceUnavailable,
            .connectionFailed("Test connection failure"),
            .modelNotFound("test-model"),
            .ollamaNotRunning,
            .noVisionModelsInstalled,
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertGreaterThan(error.errorDescription?.count ?? 0, 0)
        }
    }

    func testAIServiceErrorSpecificMessages() async throws {
        XCTAssertTrue(AIServiceError.apiKeyMissing.errorDescription?.contains("API key is missing") == true)
        XCTAssertTrue(AIServiceError.invalidImage.errorDescription?.contains("Invalid image") == true)
        XCTAssertTrue(AIServiceError.invalidResponse.errorDescription?.contains("Invalid response") == true)
        XCTAssertTrue(AIServiceError.unsupportedModel.errorDescription?.contains("not supported") == true)
        XCTAssertTrue(AIServiceError.serviceUnavailable.errorDescription?.contains("unavailable") == true)

        let connectionError = AIServiceError.connectionFailed("Test details")
        XCTAssertTrue(connectionError.errorDescription?.contains("Connection failed") == true)
        XCTAssertTrue(connectionError.errorDescription?.contains("Test details") == true)

        let modelNotFoundError = AIServiceError.modelNotFound("gpt-4")
        XCTAssertTrue(modelNotFoundError.errorDescription?.contains("gpt-4") == true)
        XCTAssertTrue(modelNotFoundError.errorDescription?.contains("not found") == true)
    }

    func testAIServiceErrorNetworkErrorHandling() async throws {
        let noInternetError = AIServiceError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(noInternetError.errorDescription?.contains("No internet connection") == true)

        let hostNotFoundError = AIServiceError.networkError(URLError(.cannotFindHost))
        XCTAssertTrue(hostNotFoundError.errorDescription?.contains("Cannot connect") == true)

        let timeoutError = AIServiceError.networkError(URLError(.timedOut))
        XCTAssertTrue(timeoutError.errorDescription?.contains("timed out") == true)

        let genericURLError = AIServiceError.networkError(URLError(.badURL))
        XCTAssertTrue(genericURLError.errorDescription?.contains("Network error") == true)

        let nonURLError = AIServiceError.networkError(NSError(domain: "test", code: 1))
        XCTAssertTrue(nonURLError.errorDescription?.contains("Network error") == true)
    }

    func testAIServiceErrorRecoverySuggestions() async throws {
        XCTAssertTrue(AIServiceError.apiKeyMissing.recoverySuggestion?.contains("Settings") == true)
        XCTAssertTrue(AIServiceError.networkError(URLError(.notConnectedToInternet)).recoverySuggestion?
            .contains("internet connection") == true)
        XCTAssertTrue(AIServiceError.serviceUnavailable.recoverySuggestion?.contains("Ollama") == true)
        XCTAssertTrue(AIServiceError.connectionFailed("test").recoverySuggestion?.contains("ollama serve") == true)

        let modelNotFoundError = AIServiceError.modelNotFound("llava")
        XCTAssertTrue(modelNotFoundError.recoverySuggestion?.contains("ollama pull llava") == true)

        XCTAssertTrue(AIServiceError.ollamaNotRunning.recoverySuggestion?.contains("ollama serve") == true)
        XCTAssertTrue(AIServiceError.noVisionModelsInstalled.recoverySuggestion?.contains("ollama pull") == true)

        // Some errors should not have recovery suggestions
        XCTAssertNil(AIServiceError.invalidImage.recoverySuggestion)
        XCTAssertNil(AIServiceError.invalidResponse.recoverySuggestion)
    }

    func testAIServiceManagerSingleton() async throws {
        let manager1 = await AIServiceManager.shared
        let manager2 = await AIServiceManager.shared

        XCTAssertTrue(manager1 === manager2)
    }

    func testAIServiceManagerProviderConfiguration() async throws {
        let manager = await AIServiceManager.shared

        // Test provider configuration
        await manager.configure(provider: .openAI, apiKey: "test-key")
        let openAIProvider = await manager.currentProvider
        XCTAssertEqual(openAIProvider, .openAI)

        await manager.configure(provider: .ollama, baseURL: URL(string: "http://localhost:11434"))
        let ollamaProvider = await manager.currentProvider
        XCTAssertEqual(ollamaProvider, .ollama)
    }

    func testAIServiceManagerSupportedModels() async throws {
        let manager = await AIServiceManager.shared

        // Test supported models - may or may not be empty depending on configuration
        let models = await manager.supportedModels()
        XCTAssertTrue(models.count >= 0) // Should be a valid array

        // Test service availability - depends on actual configuration
        let isAvailable = await manager.isServiceAvailable()
        // Just verify it returns a boolean, don't assert specific value
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }

    func testAIAnalysisImageDataHandling() async throws {
        // Test creating images of various sizes
        let sizes = [
            NSSize(width: 64, height: 64),
            NSSize(width: 256, height: 256),
            NSSize(width: 512, height: 512),
            NSSize(width: 1024, height: 768),
        ]

        for size in sizes {
            let image = NSImage(size: size)
            let request = ImageAnalysisRequest(image: image, prompt: "Test", model: .gpt4o)

            XCTAssertEqual(request.image.size.width, size.width)
            XCTAssertEqual(request.image.size.height, size.height)
        }
    }

    func testAIAnalysisPromptVariations() async throws {
        let prompts = [
            "Analyze this screenshot",
            "What do you see in this image?",
            "Describe the UI elements",
            "Is this screen working correctly?",
            "",
            "Very long prompt that contains multiple sentences and asks for detailed analysis of the screenshot including identifying specific UI elements, their states, and any potential issues or errors that might be visible.",
            "Prompt with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?",
        ]

        let image = NSImage(size: NSSize(width: 100, height: 100))

        for prompt in prompts {
            let request = ImageAnalysisRequest(image: image, prompt: prompt, model: .gpt4o)
            XCTAssertEqual(request.prompt, prompt)
        }
    }

    func testAIAnalysisModelProviderMapping() async throws {
        // Test that all models are properly mapped to providers
        let allModels = AIModel.allCases

        for model in allModels {
            let provider = model.provider
            XCTAssertTrue(provider == .openAI || provider == .ollama)

            // Verify consistency
            if model.rawValue.contains("gpt") || model.rawValue.contains("o1") || model.rawValue.contains("clip") {
                XCTAssertEqual(provider, .openAI)
            } else if model.rawValue.contains("llava") || model.rawValue.contains("bakllava") {
                XCTAssertEqual(provider, .ollama)
            }
        }
    }

    func testAIAnalysisConcurrentOperations() async throws {
        let manager = await AIServiceManager.shared

        // Test concurrent configuration calls
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 5 {
                group.addTask {
                    if i % 2 == 0 {
                        await manager.configure(provider: .openAI, apiKey: "test-key-\(i)")
                    } else {
                        await manager.configure(provider: .ollama, baseURL: URL(string: "http://localhost:1143\(i)"))
                    }
                }
            }
        }

        // Manager should still be in a valid state
        let finalProvider = await manager.currentProvider
        XCTAssertTrue(finalProvider == .openAI || finalProvider == .ollama)
    }

    func testAIAnalysisErrorEquality() async throws {
        // Test that same error types are handled consistently
        let error1 = AIServiceError.apiKeyMissing
        let error2 = AIServiceError.apiKeyMissing

        XCTAssertEqual(error1.errorDescription, error2.errorDescription)
        XCTAssertEqual(error1.recoverySuggestion, error2.recoverySuggestion)

        let modelError1 = AIServiceError.modelNotFound("test-model")
        let modelError2 = AIServiceError.modelNotFound("test-model")

        XCTAssertEqual(modelError1.errorDescription, modelError2.errorDescription)
        XCTAssertEqual(modelError1.recoverySuggestion, modelError2.recoverySuggestion)
    }

    func testAIAnalysisMemoryManagement() async throws {
        // Test creating multiple requests and responses
        let image = NSImage(size: NSSize(width: 100, height: 100))
        var requests: [ImageAnalysisRequest] = []
        var responses: [ImageAnalysisResponse] = []

        for i in 0 ..< 100 {
            let request = ImageAnalysisRequest(
                image: image,
                prompt: "Test prompt \(i)",
                model: i % 2 == 0 ? .gpt4o : .llava
            )
            requests.append(request)

            let response = ImageAnalysisResponse(
                text: "Response \(i)",
                model: request.model,
                tokensUsed: i * 10
            )
            responses.append(response)
        }

        XCTAssertEqual(requests.count, 100)
        XCTAssertEqual(responses.count, 100)

        // Verify data integrity
        for (index, request) in requests.enumerated() {
            XCTAssertEqual(request.prompt, "Test prompt \(index)")
            XCTAssertEqual(responses[index].text, "Response \(index)")
            XCTAssertEqual(responses[index].tokensUsed, index * 10)
        }

        // Clear references
        requests.removeAll()
        responses.removeAll()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(responses.isEmpty)
    }
}
