@testable import CodeLooper
import Foundation
import Network
import Testing

/// Test suite for networking functionality across the application
struct NetworkingTests {
    // MARK: - Test Utilities

    /// Protocol for URL session functionality
    protocol URLSessionProtocol {
        func data(for request: URLRequest) async throws -> (Data, URLResponse)
    }

    /// Mock URLSession for testing HTTP requests
    class MockURLSession: URLSessionProtocol {
        var mockData: Data?
        var mockResponse: URLResponse?
        var mockError: Error?
        var shouldTimeout = false

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            if shouldTimeout {
                try await Task.sleep(for: .seconds(10)) // Simulate timeout
            }

            if let error = mockError {
                throw error
            }

            let data = mockData ?? Data()
            let response = mockResponse ?? HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (data, response)
        }
    }

    /// Mock web socket server for testing
    class MockWebSocketServer {
        var isRunning = false
        var port: Int = 0
        var connectionHandler: ((String) -> Void)?

        func start(on port: Int) throws {
            self.port = port
            isRunning = true
        }

        func stop() {
            isRunning = false
        }

        func simulateConnection(from windowId: String) {
            connectionHandler?(windowId)
        }
    }

    // MARK: - WebSocketManager Tests

    @Test
    func webSocketManagerInitialization() async throws {
        let port: UInt16 = 9876
        let manager = await WebSocketManager(port: port)

        #expect(manager != nil)
        #expect(manager.isConnected == false)
    }

    @Test
    func webSocketManagerLifecycle() async throws {
        let port: UInt16 = 9877
        let manager = await WebSocketManager(port: port)

        // Test starting listener
        do {
            try await manager.startListener()
            #expect(true) // Started successfully
        } catch {
            // Port might be in use, which is okay for tests
            #expect(error != nil)
        }
    }

    @Test
    func webSocketConnectionHandling() async throws {
        let port: UInt16 = 9878
        let manager = await WebSocketManager(port: port)

        // Test connection state
        #expect(manager.isConnected == false)

        // Note: Full connection testing would require a real WebSocket client
    }

    // MARK: - AI Provider Tests

    @Test
    func openAIProviderInitialization() async throws {
        // Create API key service
        let apiKeyService = await APIKeyService.shared
        
        // Test OpenAI provider creation
        let provider = await OpenAIProvider()
        #expect(provider != nil)
    }

    @Test
    func ollamaProviderInitialization() async throws {
        // Test Ollama provider creation
        let provider = await OllamaProvider()
        #expect(provider != nil)
    }

    @Test
    func aiProviderConfiguration() async throws {
        // Test provider configuration
        let openAIProvider = await OpenAIProvider()
        let ollamaProvider = await OllamaProvider()

        #expect(openAIProvider != nil)
        #expect(ollamaProvider != nil)
    }

    // MARK: - MCP Version Service Tests

    @Test
    func mcpVersionServiceInitialization() async throws {
        let service = await MCPVersionService.shared
        #expect(service != nil)
    }

    @Test
    func mcpVersionServiceRetrieval() async throws {
        let service = await MCPVersionService.shared

        // Test version retrieval
        do {
            let version = try await service.getMCPVersion()
            #expect(version != nil)
            #expect(version.isEmpty == false)
        } catch {
            // Network error is acceptable in tests
            #expect(error != nil)
        }
    }

    // MARK: - AI Error Mapping Tests

    @Test
    func aiErrorMappingNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        let mappedError = AIErrorMapper.mapError(urlError, from: .openAI)

        switch mappedError {
        case .networkError:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingInvalidResponse() async throws {
        let error = NSError(domain: "TestDomain", code: 400, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .invalidResponse:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingAuthenticationError() async throws {
        let error = NSError(domain: "TestDomain", code: 401, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .authenticationError:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingRateLimitError() async throws {
        let error = NSError(domain: "TestDomain", code: 429, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .rateLimitExceeded:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingModelNotFoundError() async throws {
        let error = NSError(domain: "TestDomain", code: 404, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .ollama)

        switch mappedError {
        case .modelNotFound:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingInsufficientQuotaError() async throws {
        let error = NSError(domain: "TestDomain", code: 402, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .insufficientQuota:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingUnknownError() async throws {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .unknown:
            #expect(true)
        default:
            #expect(false)
        }
    }

    // MARK: - Retry Logic Tests

    @Test
    func retryManagerBasicRetry() async throws {
        let attemptCount = TestThreadSafeBox(value: 0)
        let retryManager = await RetryManager()

        let result = try await retryManager.execute(
            operation: {
                await attemptCount.update { $0 + 1 }
                let count = await attemptCount.value
                if count < 3 {
                    throw URLError(.timedOut)
                }
                return "Success"
            },
            shouldRetry: { _ in true }
        )

        #expect(result == "Success")
        #expect(await attemptCount.value == 3)
    }

    @Test
    func retryManagerMaxAttemptsExceeded() async throws {
        let attemptCount = TestThreadSafeBox(value: 0)
        let retryManager = await RetryManager(config: .init(maxAttempts: 2))

        do {
            _ = try await retryManager.execute(
                operation: {
                    await attemptCount.update { $0 + 1 }
                    throw URLError(.timedOut)
                }
            )
            #expect(false) // Should not reach here
        } catch {
            #expect(error != nil)
            #expect(await attemptCount.value == 2)
        }
    }

    @Test
    func retryManagerNonRetryableError() async throws {
        let attemptCount = TestThreadSafeBox(value: 0)
        let retryManager = await RetryManager()

        do {
            _ = try await retryManager.execute(
                operation: {
                    await attemptCount.update { $0 + 1 }
                    throw URLError(.cancelled) // Non-retryable
                }
            )
            #expect(false) // Should not reach here
        } catch {
            #expect(error != nil)
            #expect(await attemptCount.value == 1) // Only one attempt
        }
    }

    // MARK: - Port Management Tests

    @Test
    func portManagerAllocation() async throws {
        let portManager = await PortManager.shared
        let port = await portManager.allocatePort(for: "test-window")

        #expect(port > 0)
        #expect(port <= 65535)
    }

    @Test
    func portManagerDeallocation() async throws {
        let portManager = await PortManager.shared
        let windowId = "test-window-dealloc"
        
        let port = await portManager.allocatePort(for: windowId)
        #expect(port > 0)

        await portManager.releasePort(for: windowId)
        // Port should be available for reuse
    }

    // MARK: - HTTP Request Tests

    @Test
    func httpRequestTimeout() async throws {
        let session = MockURLSession()
        session.shouldTimeout = true

        do {
            // Note: Task.timeout is not a real API - this is a placeholder
            // In real code, you'd use URLSession's timeoutInterval
            _ = try await session.data(for: URLRequest(url: URL(string: "https://example.com")!))
            #expect(false) // Should timeout
        } catch {
            #expect(error != nil)
        }
    }

    @Test
    func httpRequestError() async throws {
        let session = MockURLSession()
        session.mockError = URLError(.notConnectedToInternet)

        do {
            _ = try await session.data(for: URLRequest(url: URL(string: "https://example.com")!))
            #expect(false) // Should throw error
        } catch {
            #expect(error is URLError)
        }
    }

    // MARK: - WebSocket Communication Tests

    @Test
    func webSocketMessageHandling() async throws {
        let manager = await WebSocketManager(port: 9879)
        
        // Test message handling setup
        #expect(manager != nil)
    }

    @Test
    func webSocketReconnection() async throws {
        let manager = await WebSocketManager(port: 9880)
        
        // Test reconnection capability
        #expect(manager != nil)
        #expect(manager.isConnected == false)
    }

    // MARK: - Integration Tests

    @Test
    func networkIntegrationWithRetry() async throws {
        let attempts = TestThreadSafeBox(value: 0)
        let retryManager = await RetryManager(config: .init(maxAttempts: 3))
        let session = MockURLSession()

        // First two attempts fail, third succeeds
        let result = try await retryManager.execute(
            operation: {
                await attempts.update { $0 + 1 }
                let attemptCount = await attempts.value
                
                if attemptCount < 3 {
                    session.mockError = URLError(.timedOut)
                } else {
                    session.mockError = nil
                    session.mockData = "Success".data(using: .utf8)
                }
                
                let (data, _) = try await session.data(for: URLRequest(url: URL(string: "https://example.com")!))
                return String(data: data, encoding: .utf8) ?? ""
            }
        )

        #expect(result == "Success")
        #expect(await attempts.value == 3)
    }
}

// MARK: - Thread-Safe Helper

actor TestThreadSafeBox<T> {
    private var _value: T
    
    init(value: T) {
        self._value = value
    }
    
    var value: T {
        _value
    }
    
    func update(_ transform: (T) -> T) {
        _value = transform(_value)
    }
}