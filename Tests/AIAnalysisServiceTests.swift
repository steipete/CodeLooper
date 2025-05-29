import Testing
import Foundation
import AppKit
@testable import CodeLooper

@Test("AIProvider - Enum Cases")
func testAIProviderEnumCases() async throws {
    let allCases = AIProvider.allCases
    #expect(allCases.count == 2)
    #expect(allCases.contains(.openAI))
    #expect(allCases.contains(.ollama))
    
    // Test raw values
    #expect(AIProvider.openAI.rawValue == "OpenAI")
    #expect(AIProvider.ollama.rawValue == "Ollama")
    
    // Test display names
    #expect(AIProvider.openAI.displayName == "OpenAI")
    #expect(AIProvider.ollama.displayName == "Ollama (Local)")
    
    // Test Identifiable conformance
    #expect(AIProvider.openAI.id == "OpenAI")
    #expect(AIProvider.ollama.id == "Ollama")
}

@Test("AIModel - OpenAI Models")
func testAIModelOpenAIModels() async throws {
    let openAIModels: [AIModel] = [.gpt4o, .gpt4TurboVision, .gpt4oMini, .o1, .clipVitL14]
    
    for model in openAIModels {
        #expect(model.provider == .openAI)
    }
    
    // Test specific model properties
    #expect(AIModel.gpt4o.rawValue == "gpt-4o")
    #expect(AIModel.gpt4o.displayName == "GPT-4o (Flagship)")
    #expect(AIModel.gpt4o.id == "gpt-4o")
    
    #expect(AIModel.gpt4TurboVision.rawValue == "gpt-4-turbo-2024-04-09")
    #expect(AIModel.gpt4TurboVision.displayName == "GPT-4 Turbo with Vision")
    
    #expect(AIModel.gpt4oMini.rawValue == "gpt-4o-mini")
    #expect(AIModel.gpt4oMini.displayName == "GPT-4o-mini")
    
    #expect(AIModel.o1.rawValue == "o1")
    #expect(AIModel.o1.displayName == "o1")
}

@Test("AIModel - Ollama Models")
func testAIModelOllamaModels() async throws {
    let ollamaModels: [AIModel] = [.llava, .bakllava, .llava13b, .llava34b]
    
    for model in ollamaModels {
        #expect(model.provider == .ollama)
    }
    
    // Test specific model properties
    #expect(AIModel.llava.rawValue == "llava")
    #expect(AIModel.llava.displayName == "LLaVA")
    
    #expect(AIModel.bakllava.rawValue == "bakllava")
    #expect(AIModel.bakllava.displayName == "BakLLaVA")
    
    #expect(AIModel.llava13b.rawValue == "llava:13b")
    #expect(AIModel.llava13b.displayName == "LLaVA 13B")
    
    #expect(AIModel.llava34b.rawValue == "llava:34b")
    #expect(AIModel.llava34b.displayName == "LLaVA 34B")
}

@Test("ImageAnalysisRequest - Creation")
func testImageAnalysisRequestCreation() async throws {
    // Create a test image
    let image = NSImage(size: NSSize(width: 100, height: 100))
    let prompt = "Analyze this image"
    let model = AIModel.gpt4o
    
    let request = ImageAnalysisRequest(image: image, prompt: prompt, model: model)
    
    #expect(request.image.size.width == 100)
    #expect(request.image.size.height == 100)
    #expect(request.prompt == "Analyze this image")
    #expect(request.model == .gpt4o)
}

@Test("ImageAnalysisResponse - Creation")
func testImageAnalysisResponseCreation() async throws {
    let response1 = ImageAnalysisResponse(text: "Test response", model: .gpt4o, tokensUsed: 100)
    #expect(response1.text == "Test response")
    #expect(response1.model == .gpt4o)
    #expect(response1.tokensUsed == 100)
    
    let response2 = ImageAnalysisResponse(text: "Another response", model: .llava)
    #expect(response2.text == "Another response")
    #expect(response2.model == .llava)
    #expect(response2.tokensUsed == nil)
}

@Test("AIServiceError - Error Cases")
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
        .noVisionModelsInstalled
    ]
    
    for error in errors {
        #expect(error.errorDescription != nil)
        #expect((error.errorDescription?.count ?? 0) > 0)
    }
}

@Test("AIServiceError - Specific Error Messages")
func testAIServiceErrorSpecificMessages() async throws {
    #expect(AIServiceError.apiKeyMissing.errorDescription?.contains("API key is missing") == true)
    #expect(AIServiceError.invalidImage.errorDescription?.contains("Invalid image") == true)
    #expect(AIServiceError.invalidResponse.errorDescription?.contains("Invalid response") == true)
    #expect(AIServiceError.unsupportedModel.errorDescription?.contains("not supported") == true)
    #expect(AIServiceError.serviceUnavailable.errorDescription?.contains("unavailable") == true)
    
    let connectionError = AIServiceError.connectionFailed("Test details")
    #expect(connectionError.errorDescription?.contains("Connection failed") == true)
    #expect(connectionError.errorDescription?.contains("Test details") == true)
    
    let modelNotFoundError = AIServiceError.modelNotFound("gpt-4")
    #expect(modelNotFoundError.errorDescription?.contains("gpt-4") == true)
    #expect(modelNotFoundError.errorDescription?.contains("not found") == true)
}

@Test("AIServiceError - Network Error Handling")
func testAIServiceErrorNetworkErrorHandling() async throws {
    let noInternetError = AIServiceError.networkError(URLError(.notConnectedToInternet))
    #expect(noInternetError.errorDescription?.contains("No internet connection") == true)
    
    let hostNotFoundError = AIServiceError.networkError(URLError(.cannotFindHost))
    #expect(hostNotFoundError.errorDescription?.contains("Cannot connect") == true)
    
    let timeoutError = AIServiceError.networkError(URLError(.timedOut))
    #expect(timeoutError.errorDescription?.contains("timed out") == true)
    
    let genericURLError = AIServiceError.networkError(URLError(.badURL))
    #expect(genericURLError.errorDescription?.contains("Network error") == true)
    
    let nonURLError = AIServiceError.networkError(NSError(domain: "test", code: 1))
    #expect(nonURLError.errorDescription?.contains("Network error") == true)
}

@Test("AIServiceError - Recovery Suggestions")
func testAIServiceErrorRecoverySuggestions() async throws {
    #expect(AIServiceError.apiKeyMissing.recoverySuggestion?.contains("Settings") == true)
    #expect(AIServiceError.networkError(URLError(.notConnectedToInternet)).recoverySuggestion?.contains("internet connection") == true)
    #expect(AIServiceError.serviceUnavailable.recoverySuggestion?.contains("Ollama") == true)
    #expect(AIServiceError.connectionFailed("test").recoverySuggestion?.contains("ollama serve") == true)
    
    let modelNotFoundError = AIServiceError.modelNotFound("llava")
    #expect(modelNotFoundError.recoverySuggestion?.contains("ollama pull llava") == true)
    
    #expect(AIServiceError.ollamaNotRunning.recoverySuggestion?.contains("ollama serve") == true)
    #expect(AIServiceError.noVisionModelsInstalled.recoverySuggestion?.contains("ollama pull") == true)
    
    // Some errors should not have recovery suggestions
    #expect(AIServiceError.invalidImage.recoverySuggestion == nil)
    #expect(AIServiceError.invalidResponse.recoverySuggestion == nil)
}

@Test("AIServiceManager - Singleton")
func testAIServiceManagerSingleton() async throws {
    let manager1 = await AIServiceManager.shared
    let manager2 = await AIServiceManager.shared
    
    #expect(manager1 === manager2)
}

@Test("AIServiceManager - Provider Configuration")
func testAIServiceManagerProviderConfiguration() async throws {
    let manager = await AIServiceManager.shared
    
    // Test provider configuration
    await manager.configure(provider: .openAI, apiKey: "test-key")
    let openAIProvider = await manager.currentProvider
    #expect(openAIProvider == .openAI)
    
    await manager.configure(provider: .ollama, baseURL: URL(string: "http://localhost:11434"))
    let ollamaProvider = await manager.currentProvider
    #expect(ollamaProvider == .ollama)
}

@Test("AIServiceManager - Supported Models")
func testAIServiceManagerSupportedModels() async throws {
    let manager = await AIServiceManager.shared
    
    // Test supported models (without actual service configuration)
    let models = await manager.supportedModels()
    #expect(models.isEmpty == true) // Should be empty without proper service configuration
    
    // Test service availability
    let isAvailable = await manager.isServiceAvailable()
    #expect(isAvailable == false) // Should be false without proper service configuration
}

@Test("AIAnalysis - Image Data Handling")
func testAIAnalysisImageDataHandling() async throws {
    // Test creating images of various sizes
    let sizes = [
        NSSize(width: 64, height: 64),
        NSSize(width: 256, height: 256),
        NSSize(width: 512, height: 512),
        NSSize(width: 1024, height: 768)
    ]
    
    for size in sizes {
        let image = NSImage(size: size)
        let request = ImageAnalysisRequest(image: image, prompt: "Test", model: .gpt4o)
        
        #expect(request.image.size.width == size.width)
        #expect(request.image.size.height == size.height)
    }
}

@Test("AIAnalysis - Prompt Variations")
func testAIAnalysisPromptVariations() async throws {
    let prompts = [
        "Analyze this screenshot",
        "What do you see in this image?",
        "Describe the UI elements",
        "Is this screen working correctly?",
        "",
        "Very long prompt that contains multiple sentences and asks for detailed analysis of the screenshot including identifying specific UI elements, their states, and any potential issues or errors that might be visible.",
        "Prompt with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?"
    ]
    
    let image = NSImage(size: NSSize(width: 100, height: 100))
    
    for prompt in prompts {
        let request = ImageAnalysisRequest(image: image, prompt: prompt, model: .gpt4o)
        #expect(request.prompt == prompt)
    }
}

@Test("AIAnalysis - Model Provider Mapping")
func testAIAnalysisModelProviderMapping() async throws {
    // Test that all models are properly mapped to providers
    let allModels = AIModel.allCases
    
    for model in allModels {
        let provider = model.provider
        #expect(provider == .openAI || provider == .ollama)
        
        // Verify consistency
        if model.rawValue.contains("gpt") || model.rawValue.contains("o1") || model.rawValue.contains("clip") {
            #expect(provider == .openAI)
        } else if model.rawValue.contains("llava") || model.rawValue.contains("bakllava") {
            #expect(provider == .ollama)
        }
    }
}

@Test("AIAnalysis - Concurrent Operations")
func testAIAnalysisConcurrentOperations() async throws {
    let manager = await AIServiceManager.shared
    
    // Test concurrent configuration calls
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<5 {
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
    #expect(finalProvider == .openAI || finalProvider == .ollama)
}

@Test("AIAnalysis - Error Equality")
func testAIAnalysisErrorEquality() async throws {
    // Test that same error types are handled consistently
    let error1 = AIServiceError.apiKeyMissing
    let error2 = AIServiceError.apiKeyMissing
    
    #expect(error1.errorDescription == error2.errorDescription)
    #expect(error1.recoverySuggestion == error2.recoverySuggestion)
    
    let modelError1 = AIServiceError.modelNotFound("test-model")
    let modelError2 = AIServiceError.modelNotFound("test-model")
    
    #expect(modelError1.errorDescription == modelError2.errorDescription)
    #expect(modelError1.recoverySuggestion == modelError2.recoverySuggestion)
}

@Test("AIAnalysis - Memory Management")
func testAIAnalysisMemoryManagement() async throws {
    // Test creating multiple requests and responses
    let image = NSImage(size: NSSize(width: 100, height: 100))
    var requests: [ImageAnalysisRequest] = []
    var responses: [ImageAnalysisResponse] = []
    
    for i in 0..<100 {
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
    
    #expect(requests.count == 100)
    #expect(responses.count == 100)
    
    // Verify data integrity
    for (index, request) in requests.enumerated() {
        #expect(request.prompt == "Test prompt \(index)")
        #expect(responses[index].text == "Response \(index)")
        #expect(responses[index].tokensUsed == index * 10)
    }
    
    // Clear references
    requests.removeAll()
    responses.removeAll()
    #expect(requests.isEmpty)
    #expect(responses.isEmpty)
}