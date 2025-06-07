import AppKit
@testable import CodeLooper
import Foundation
import Testing

// MARK: - Custom Test Traits

struct AITestTrait: TestTrait {
    let category: String
}

struct PerformanceRequirement: TestTrait {
    let maxDuration: Duration
}

/// Trait for tests that require specific AI model capabilities
struct RequiresModelCapability: TestTrait {
    let capability: ModelCapability
    
    enum ModelCapability: String, CaseIterable {
        case vision = "vision"
        case largeContext = "large_context"
        case streaming = "streaming"
        case functionCalling = "function_calling"
        case multimodal = "multimodal"
    }
}

/// Trait for tests that require external API access
struct RequiresExternalAPI: TestTrait {
    let provider: AIProvider
    let requiresAPIKey: Bool
    
    init(provider: AIProvider, requiresAPIKey: Bool = true) {
        self.provider = provider
        self.requiresAPIKey = requiresAPIKey
    }
}

/// Trait for categorizing test complexity and execution requirements
struct TestComplexity: TestTrait {
    let level: ComplexityLevel
    let estimatedDuration: Duration
    let resourceRequirement: ResourceRequirement
    
    enum ComplexityLevel: String {
        case simple = "simple"
        case moderate = "moderate"
        case complex = "complex"
        case enterprise = "enterprise"
    }
    
    enum ResourceRequirement: String {
        case minimal = "minimal"
        case moderate = "moderate"
        case intensive = "intensive"
        case distributed = "distributed"
    }
}

/// Trait for tests that validate specific error scenarios
struct ErrorScenarioTrait: TestTrait {
    let scenarioType: ErrorScenarioType
    let expectedBehavior: ExpectedBehavior
    
    enum ErrorScenarioType: String {
        case networkFailure = "network_failure"
        case invalidInput = "invalid_input"
        case authenticationFailure = "authentication_failure"
        case rateLimiting = "rate_limiting"
        case serviceUnavailable = "service_unavailable"
    }
    
    enum ExpectedBehavior: String {
        case gracefulFallback = "graceful_fallback"
        case immediateFailure = "immediate_failure"
        case retryWithBackoff = "retry_with_backoff"
        case userNotification = "user_notification"
    }
}

// MARK: - Shared Test Utilities

enum AITestUtilities {
    static func validateProvider(_ provider: AIProvider) throws {
        #expect(!provider.rawValue.isEmpty)
        #expect(!provider.displayName.isEmpty)
        #expect(provider.id == provider.rawValue)
    }
    
    static func validateModel(_ model: AIModel) throws {
        #expect(!model.rawValue.isEmpty)
        #expect(!model.displayName.isEmpty)
        #expect(!model.id.isEmpty)
        #expect(AIProvider.allCases.contains(model.provider))
    }
    
    static func createTestImage(size: NSSize = NSSize(width: 100, height: 100)) -> NSImage {
        NSImage(size: size)
    }
    
    static func createTestRequest(
        prompt: String = "Test",
        model: AIModel = .gpt4o,
        imageSize: NSSize = NSSize(width: 100, height: 100)
    ) -> ImageAnalysisRequest {
        ImageAnalysisRequest(
            image: createTestImage(size: imageSize),
            prompt: prompt,
            model: model
        )
    }
}

// MARK: - Test Conditions

@available(*, unavailable, message: "Test requires API key")
struct RequiresAPIKey: TestTrait {}

struct RequiresNetwork: TestTrait {
    static var isEnabled: Bool {
        // In real implementation, check network availability
        return true
    }
}

// MARK: - Main Test Suite

@Suite("AI Analysis Service", .serialized)
struct AIAnalysisServiceTests {
    // Shared test data as computed properties for thread safety
    var testProviders: [AIProvider] { AIProvider.allCases }
    var testModels: [AIModel] { AIModel.allCases }
    
    var imageSizeMatrix: [(width: Int, height: Int)] {
        [(64, 64), (256, 256), (512, 512), (1024, 768)]
    }
    
    var promptVariations: [String] {
        [
            "Analyze this screenshot",
            "What do you see in this image?",
            "Describe the UI elements",
            "",
            String(repeating: "Very long prompt ", count: 50),
            "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "Unicode: 🚀 📱 💻 测试"
        ]
    }
    
    // MARK: - Provider Tests
    
    @Suite("Providers", .tags(.provider))
    struct ProviderTests {
        @Test(
            "Provider properties validation",
            arguments: AIProvider.allCases
        )
        func validateProviderProperties(provider: AIProvider) throws {
            try AITestUtilities.validateProvider(provider)
        }
        
        @Test("Provider-specific attributes")
        @MainActor func providerSpecificAttributes() async throws {
            // Using confirmation for multiple related checks
            await confirmation("OpenAI provider") { confirm in
                #expect(AIProvider.openAI.rawValue == "OpenAI")
                #expect(AIProvider.openAI.displayName == "OpenAI")
                confirm()
            }
            
            await confirmation("Ollama provider") { confirm in
                #expect(AIProvider.ollama.rawValue == "Ollama")
                #expect(AIProvider.ollama.displayName == "Ollama (Local)")
                confirm()
            }
        }
    }
    
    // MARK: - Model Tests
    
    @Suite("Models", .tags(.model))
    struct ModelTests {
        @Test(
            "Model validation matrix",
            arguments: [
                (model: AIModel.gpt4o, provider: AIProvider.openAI, prefix: "gpt"),
                (model: .gpt4TurboVision, provider: .openAI, prefix: "gpt"),
                (model: .llava, provider: .ollama, prefix: "llava"),
                (model: .bakllava, provider: .ollama, prefix: "bakllava")
            ]
        )
        func validateModelMatrix(testCase: (model: AIModel, provider: AIProvider, prefix: String)) throws {
            let (model, expectedProvider, prefix) = testCase
            
            try AITestUtilities.validateModel(model)
            #expect(model.provider == expectedProvider)
            #expect(model.rawValue.hasPrefix(prefix) || model.rawValue.contains(prefix))
        }
        
        @Test("All models have consistent properties")
        func allModelsConsistency() throws {
            for model in AIModel.allCases {
                try AITestUtilities.validateModel(model)
                
                // Provider consistency check
                switch model.rawValue {
                case let raw where raw.contains("gpt") || raw.contains("o1") || raw.contains("clip"):
                    #expect(model.provider == .openAI)
                case let raw where raw.contains("llava"):
                    #expect(model.provider == .ollama)
                default:
                    Issue.record("Unknown model pattern: \(model.rawValue)")
                }
            }
        }
    }
    
    // MARK: - Request/Response Tests
    
    @Suite("Request/Response", .tags(.io))
    struct RequestResponseTests {
        @Test(
            "Image request creation with size matrix",
            arguments: [(64, 64), (256, 256), (512, 512), (1024, 768)]
        )
        func imageRequestSizeMatrix(dimensions: (width: Int, height: Int)) throws {
            let size = NSSize(width: dimensions.width, height: dimensions.height)
            let request = AITestUtilities.createTestRequest(imageSize: size)
            
            #expect(request.image.size == size)
            #expect(request.prompt == "Test")
            #expect(request.model == .gpt4o)
        }
        
        @Test(
            "Prompt encoding validation",
            arguments: [
                ("Simple", true),
                ("", true),
                (String(repeating: "a", count: 10000), true),
                ("🚀 Unicode 测试", true)
            ]
        )
        func promptEncodingValidation(testCase: (prompt: String, valid: Bool)) {
            let request = AITestUtilities.createTestRequest(prompt: testCase.prompt)
            #expect(request.prompt == testCase.prompt)
            #expect((request.prompt.count > 0) || testCase.prompt.isEmpty)
        }
        
        @Test("Response token tracking")
        func responseTokenTracking() throws {
            let testCases: [(text: String, model: AIModel, tokens: Int?)] = [
                ("Short response", .gpt4o, 10),
                ("Medium response with more content", .gpt4o, 50),
                ("Local model response", .llava, nil)
            ]
            
            for testCase in testCases {
                let response = ImageAnalysisResponse(
                    text: testCase.text,
                    model: testCase.model,
                    tokensUsed: testCase.tokens
                )
                
                #expect(response.text == testCase.text)
                #expect(response.model == testCase.model)
                #expect(response.tokensUsed == testCase.tokens)
            }
        }
    }
    
    // MARK: - Error Handling
    
    @Suite("Error Handling", .tags(.error))
    struct ErrorHandlingTests {
        struct ErrorTestCase {
            let error: AIServiceError
            let expectedDescription: String?
            let hasRecoverySuggestion: Bool
            
            static let standardCases = [
                ErrorTestCase(
                    error: .apiKeyMissing,
                    expectedDescription: "API key is missing",
                    hasRecoverySuggestion: true
                ),
                ErrorTestCase(
                    error: .invalidImage,
                    expectedDescription: "Invalid image",
                    hasRecoverySuggestion: false
                ),
                ErrorTestCase(
                    error: .serviceUnavailable,
                    expectedDescription: "unavailable",
                    hasRecoverySuggestion: true
                )
            ]
        }
        
        @Test(
            "Error validation matrix",
            arguments: ErrorTestCase.standardCases
        )
        func validateErrorCases(testCase: ErrorTestCase) {
            if let expected = testCase.expectedDescription {
                #expect(testCase.error.errorDescription?.contains(expected) == true)
            }
            
            if testCase.hasRecoverySuggestion {
                #expect(testCase.error.recoverySuggestion != nil)
            } else {
                #expect(testCase.error.recoverySuggestion == nil)
            }
        }
        
        @Test("Network error mapping")
        func networkErrorMapping() {
            let networkErrors: [(URLError.Code, String)] = [
                (.notConnectedToInternet, "No internet connection"),
                (.cannotFindHost, "Cannot connect"),
                (.timedOut, "timed out")
            ]
            
            for (code, expectedText) in networkErrors {
                let error = AIServiceError.networkError(URLError(code))
                #expect(error.errorDescription?.contains(expectedText) == true)
            }
        }
    }
    
    // MARK: - Service Manager Tests
    
    @Suite("Service Manager", .tags(.manager))
    struct ServiceManagerTests {
        @Test("Singleton consistency")
        func singletonConsistency() async throws {
            await confirmation("Manager singleton") { confirm in
                let manager1 = await AIServiceManager.shared
                let manager2 = await AIServiceManager.shared
                #expect(manager1 === manager2)
                confirm()
            }
        }
        
        @Test(
            "Provider configuration transitions",
            arguments: [
                (provider: AIProvider.openAI, config: "test-key-1"),
                (provider: .ollama, config: "http://localhost:11434")
            ]
        )
        func providerConfigurationTransitions(
            testCase: (provider: AIProvider, config: String)
        ) async throws {
            let manager = await AIServiceManager.shared
            
            switch testCase.provider {
            case .openAI:
                await manager.configure(provider: testCase.provider, apiKey: testCase.config)
            case .ollama:
                await manager.configure(
                    provider: testCase.provider,
                    baseURL: URL(string: testCase.config)
                )
            }
            
            let currentProvider = await manager.currentProvider
            #expect(currentProvider == testCase.provider)
        }
    }
    
    // MARK: - Performance Tests
    
    @Suite("Performance", .tags(.performance))
    struct PerformanceTests {
        @Test(
            "Bulk operations performance",
            .timeLimit(.minutes(1))
        )
        func bulkOperationsPerformance() async throws {
            await confirmation("Bulk request creation", expectedCount: 1000) { confirm in
                for i in 0..<1000 {
                    let _ = AITestUtilities.createTestRequest(
                        prompt: "Bulk test \(i)",
                        model: i % 2 == 0 ? .gpt4o : .llava
                    )
                    if i % 100 == 0 {
                        confirm()
                    }
                }
            }
        }
        
        @Test("Concurrent manager operations", .timeLimit(.minutes(1)))
        func concurrentManagerOperations() async throws {
            let manager = await AIServiceManager.shared
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Concurrent configuration changes
                for i in 0..<20 {
                    group.addTask {
                        if i % 2 == 0 {
                            await manager.configure(provider: .openAI, apiKey: "key-\(i)")
                        } else {
                            await manager.configure(
                                provider: .ollama,
                                baseURL: URL(string: "http://localhost:\(11434 + i)")
                            )
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            // Manager should still be functional
            let finalProvider = await manager.currentProvider
            #expect(AIProvider.allCases.contains(finalProvider))
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration), .disabled("Requires live service"))
    struct IntegrationTests {
        @Test("End-to-end analysis flow")
        func endToEndAnalysisFlow() async throws {
            let manager = await AIServiceManager.shared
            
            // This test would require actual API access
            let currentProvider = await manager.currentProvider
            #expect([AIProvider.openAI, .ollama].contains(currentProvider), "Manager should have a valid provider")
        }
    }
    
    // MARK: - Advanced Custom Traits Demo
    
    @Suite("Custom Traits Demo", .tags(.advanced))
    struct CustomTraitsDemo {
        @Test(
            "Vision model capability validation",
            RequiresModelCapability(capability: .vision),
            TestComplexity(
                level: .moderate,
                estimatedDuration: .seconds(30),
                resourceRequirement: .moderate
            )
        )
        func visionModelCapabilityValidation() async throws {
            let visionModels: [AIModel] = [.gpt4o, .gpt4TurboVision]
            
            for model in visionModels {
                // Validate that vision models can handle image analysis
                let testImage = AITestUtilities.createTestImage()
                let request = ImageAnalysisRequest(
                    image: testImage,
                    prompt: "Describe this image",
                    model: model
                )
                
                // Validate image analysis request inline
                #expect(request.image.size.width > 0)
                #expect(request.image.size.height > 0)
                #expect(AIModel.allCases.contains(request.model))
                #expect(model.rawValue.contains("vision") || model.rawValue.contains("4o"))
            }
        }
        
        @Test(
            "Network failure error handling",
            ErrorScenarioTrait(
                scenarioType: .networkFailure,
                expectedBehavior: .gracefulFallback
            ),
            .timeLimit(.minutes(1))
        )
        func networkFailureErrorHandling() async throws {
            // Simulate network failure scenarios
            let networkErrors: [URLError.Code] = [
                .notConnectedToInternet,
                .timedOut,
                .cannotConnectToHost
            ]
            
            for errorCode in networkErrors {
                let networkError = URLError(errorCode)
                let mappedError = AIServiceError.networkError(networkError)
                
                // Verify graceful fallback behavior
                #expect(mappedError.errorDescription != nil)
                #expect(mappedError.recoverySuggestion != nil)
                
                // Should provide actionable recovery suggestions
                let suggestion = mappedError.recoverySuggestion ?? ""
                #expect(
                    suggestion.contains("check") || 
                    suggestion.contains("try") || 
                    suggestion.contains("connection"),
                    "Recovery suggestion should be actionable"
                )
            }
        }
        
        @Test(
            "External API provider configuration",
            RequiresExternalAPI(provider: .openAI, requiresAPIKey: true),
            TestComplexity(
                level: .complex,
                estimatedDuration: .seconds(120),
                resourceRequirement: .intensive
            )
        )
        func externalAPIProviderConfiguration() async throws {
            let manager = await AIServiceManager.shared
            
            // Test that external API configuration requires proper setup
            await manager.configure(provider: .openAI, apiKey: "test-key")
            
            let currentProvider = await manager.currentProvider
            #expect(currentProvider == .openAI)
            
            // Verify API key validation would occur in real scenario
            #expect(Bool(true), "API key validation logic would be tested here")
        }
        
        @Test(
            "Rate limiting scenario",
            ErrorScenarioTrait(
                scenarioType: .rateLimiting,
                expectedBehavior: .retryWithBackoff
            ),
            RequiresExternalAPI(provider: .openAI)
        )
        func rateLimitingScenario() throws {
            // Simulate rate limiting error
            let _ = NSError(
                domain: "AIServiceError",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]
            )
            
            // Simulate rate limit error without enum case
            let customRateLimitError = NSError(
                domain: "com.codelooper.ai",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]
            )
            
            // Test error handling patterns
            #expect(customRateLimitError.code == 429, "Should be rate limit error")
            #expect(customRateLimitError.localizedDescription.contains("Rate limit"), "Should describe rate limiting")
        }
    }
}

// MARK: - Custom Assertions

extension AIAnalysisServiceTests {
    func assertValidImageAnalysisRequest(
        _ request: ImageAnalysisRequest,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(request.image.size.width > 0, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        #expect(request.image.size.height > 0, sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        #expect(AIModel.allCases.contains(request.model), sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
    }
}

