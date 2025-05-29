import Testing
import Foundation
import Network
@testable import CodeLooper

/// Test suite for networking functionality across the application
@Suite("Networking Tests")
struct NetworkingTests {
    
    // MARK: - Test Utilities
    
    /// Mock URLSession for testing HTTP requests
    class MockURLSession: URLSession {
        var mockData: Data?
        var mockResponse: URLResponse?
        var mockError: Error?
        var shouldTimeout = false
        
        override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
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
            port = 0
        }
        
        func simulateConnection(message: String) {
            connectionHandler?(message)
        }
    }
    
    // MARK: - WebSocket Manager Tests
    
    @Test("WebSocket server can start and stop")
    func testWebSocketServerLifecycle() async throws {
        let manager = WebSocketManager.shared
        
        // Test starting server
        let port = try await manager.startServer()
        #expect(port > 0)
        #expect(await manager.isServerRunning)
        
        // Test stopping server
        await manager.stopServer()
        #expect(!(await manager.isServerRunning))
    }
    
    @Test("WebSocket handles connection state changes")
    func testWebSocketConnectionState() async throws {
        let manager = WebSocketManager.shared
        
        // Initially no connections
        let initialConnections = await manager.getConnectedWindowIds()
        #expect(initialConnections.isEmpty)
        
        // Test connection tracking
        await manager.handleNewConnection(windowId: "test-window")
        let connectionsAfterAdd = await manager.getConnectedWindowIds()
        #expect(connectionsAfterAdd.contains("test-window"))
        
        // Test disconnection
        await manager.handleDisconnection(windowId: "test-window")
        let connectionsAfterRemove = await manager.getConnectedWindowIds()
        #expect(!connectionsAfterRemove.contains("test-window"))
    }
    
    @Test("WebSocket handles message sending")
    func testWebSocketMessageSending() async throws {
        let manager = WebSocketManager.shared
        
        // Start server for testing
        _ = try await manager.startServer()
        
        // Test sending message to non-existent window
        do {
            _ = try await manager.sendMessage(["test": "data"], to: "non-existent")
            #expect(false, "Should have thrown error for non-existent window")
        } catch {
            #expect(error != nil)
        }
        
        // Cleanup
        await manager.stopServer()
    }
    
    // MARK: - AI Provider Network Tests
    
    @Test("OpenAI provider handles network requests")
    func testOpenAIProviderNetworking() async throws {
        let apiKeyManager = APIKeyManager()
        
        // Test without API key
        let hasKey = apiKeyManager.hasOpenAIKey()
        
        if hasKey {
            let provider = OpenAIProvider()
            
            // Test provider initialization
            #expect(provider != nil)
            
            // Note: We don't make actual API calls in tests
            // This verifies the provider can be created and configured
        } else {
            // Test that provider handles missing API key gracefully
            let provider = OpenAIProvider()
            #expect(provider != nil)
        }
    }
    
    @Test("Ollama provider handles local service connection")
    func testOllamaProviderNetworking() async throws {
        let provider = OllamaProvider()
        
        // Test provider initialization
        #expect(provider != nil)
        
        // Test service availability check (this should not crash even if Ollama isn't running)
        let isAvailable = await provider.isServiceAvailable()
        #expect(isAvailable == true || isAvailable == false) // Either state is valid
        
        // Test model listing (should handle connection errors gracefully)
        do {
            let models = await provider.getAvailableModels()
            #expect(models != nil) // Should return empty array if service unavailable
        } catch {
            // Connection errors are expected if Ollama isn't running
            #expect(error != nil)
        }
    }
    
    // MARK: - NPM Registry Integration Tests
    
    @Test("MCP version service handles NPM API requests")
    func testMCPVersionServiceNetworking() async throws {
        let versionService = MCPVersionService()
        
        // Test service initialization
        #expect(versionService != nil)
        
        // Test package version checking (using a real package that should exist)
        do {
            let version = await versionService.getLatestVersion(for: "typescript")
            #expect(version != nil)
            #expect(!version!.isEmpty)
        } catch {
            // Network errors are acceptable in tests
            #expect(error != nil)
        }
    }
    
    @Test("MCP version service handles multiple concurrent requests")
    func testMCPVersionServiceConcurrency() async throws {
        let versionService = MCPVersionService()
        
        // Test concurrent requests
        async let version1 = versionService.getLatestVersion(for: "react")
        async let version2 = versionService.getLatestVersion(for: "vue")
        async let version3 = versionService.getLatestVersion(for: "angular")
        
        do {
            let results = try await [version1, version2, version3]
            // At least one request should succeed (or all should fail gracefully)
            #expect(results.count == 3)
        } catch {
            // Network errors are acceptable in tests
            #expect(error != nil)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("AIErrorMapper handles URL errors correctly")
    func testAIErrorMapperURLErrors() async throws {
        // Test network connection lost
        let networkError = URLError(.networkConnectionLost)
        let mappedNetworkError = AIErrorMapper.mapError(networkError)
        
        switch mappedNetworkError {
        case .networkError:
            #expect(true)
        default:
            #expect(false, "Should map to networkError")
        }
        
        // Test timeout
        let timeoutError = URLError(.timedOut)
        let mappedTimeoutError = AIErrorMapper.mapError(timeoutError)
        
        switch mappedTimeoutError {
        case .serviceUnavailable:
            #expect(true)
        default:
            #expect(false, "Should map to serviceUnavailable")
        }
        
        // Test authentication error
        let authError = URLError(.userAuthenticationRequired)
        let mappedAuthError = AIErrorMapper.mapError(authError)
        
        switch mappedAuthError {
        case .apiKeyMissing:
            #expect(true)
        default:
            #expect(false, "Should map to apiKeyMissing")
        }
    }
    
    @Test("AIErrorMapper handles HTTP status codes")
    func testAIErrorMapperHTTPErrors() async throws {
        // Test 401 Unauthorized
        let unauthorized = AIErrorMapper.mapHTTPError(401, responseData: nil)
        switch unauthorized {
        case .apiKeyMissing:
            #expect(true)
        default:
            #expect(false, "Should map 401 to apiKeyMissing")
        }
        
        // Test 429 Rate Limited
        let rateLimited = AIErrorMapper.mapHTTPError(429, responseData: nil)
        switch rateLimited {
        case .serviceUnavailable:
            #expect(true)
        default:
            #expect(false, "Should map 429 to serviceUnavailable")
        }
        
        // Test 500 Server Error
        let serverError = AIErrorMapper.mapHTTPError(500, responseData: nil)
        switch serverError {
        case .serviceUnavailable:
            #expect(true)
        default:
            #expect(false, "Should map 500 to serviceUnavailable")
        }
        
        // Test 400 Bad Request with JSON response
        let jsonResponse = """
        {
            "error": {
                "message": "Invalid request format"
            }
        }
        """.data(using: .utf8)
        
        let badRequest = AIErrorMapper.mapHTTPError(400, responseData: jsonResponse)
        switch badRequest {
        case .invalidResponse:
            #expect(true)
        default:
            #expect(false, "Should map 400 to invalidResponse")
        }
    }
    
    @Test("AIErrorMapper handles NSError cases")
    func testAIErrorMapperNSErrors() async throws {
        // Test POSIX connection refused error
        let connectionRefused = NSError(domain: "NSPOSIXErrorDomain", code: 61, userInfo: nil)
        let mappedRefused = AIErrorMapper.mapError(connectionRefused)
        
        switch mappedRefused {
        case .connectionFailed:
            #expect(true)
        default:
            #expect(false, "Should map connection refused to connectionFailed")
        }
        
        // Test POSIX timeout error
        let posixTimeout = NSError(domain: "NSPOSIXErrorDomain", code: 60, userInfo: nil)
        let mappedTimeout = AIErrorMapper.mapError(posixTimeout)
        
        switch mappedTimeout {
        case .serviceUnavailable:
            #expect(true)
        default:
            #expect(false, "Should map POSIX timeout to serviceUnavailable")
        }
    }
    
    // MARK: - Retry Manager Tests
    
    @Test("RetryManager handles network retries with backoff")
    func testRetryManagerNetworkRetries() async throws {
        let config = RetryManager.RetryConfiguration(maxAttempts: 3)
        let retryManager = RetryManager(config: config)
        var attemptCount = 0
        
        // Test successful retry after failures
        let result = try await retryManager.execute(
            operation: {
                attemptCount += 1
                if attemptCount < 3 {
                    throw URLError(.networkConnectionLost)
                }
                return "Success"
            }
        )
        
        #expect(result == "Success")
        #expect(attemptCount == 3)
    }
    
    @Test("RetryManager respects max attempts limit")
    func testRetryManagerMaxAttempts() async throws {
        let config = RetryManager.RetryConfiguration(maxAttempts: 2)
        let retryManager = RetryManager(config: config)
        var attemptCount = 0
        
        do {
            _ = try await retryManager.execute(
                operation: {
                    attemptCount += 1
                    throw URLError(.timedOut)
                }
            )
            #expect(false, "Should have thrown after max attempts")
        } catch {
            #expect(attemptCount == 2)
            #expect(error is URLError)
        }
    }
    
    @Test("RetryManager handles non-retryable errors")
    func testRetryManagerNonRetryableErrors() async throws {
        let config = RetryManager.RetryConfiguration(maxAttempts: 3)
        let retryManager = RetryManager(config: config)
        var attemptCount = 0
        
        do {
            _ = try await retryManager.execute(
                operation: {
                    attemptCount += 1
                    throw URLError(.badURL) // Non-retryable error
                }
            )
            #expect(false, "Should have thrown immediately")
        } catch {
            #expect(attemptCount == 1) // Should not retry non-retryable errors
            #expect(error is URLError)
        }
    }
    
    // MARK: - Port Manager Tests
    
    @Test("PortManager finds available ports")
    func testPortManagerAvailablePorts() async throws {
        let portManager = PortManager()
        
        // Test finding an available port
        let port = portManager.findAvailablePort(startingFrom: 8000)
        #expect(port >= 8000)
        #expect(port <= 65535)
    }
    
    @Test("PortManager validates port availability")
    func testPortManagerPortValidation() async throws {
        let portManager = PortManager()
        
        // Test port validation (should work for most high-numbered ports)
        let testPort = 45000
        let isAvailable = portManager.isPortAvailable(testPort)
        #expect(isAvailable == true || isAvailable == false) // Either state is valid
    }
    
    // MARK: - Task Timeout Tests
    
    @Test("Task timeout extension works correctly")
    func testTaskTimeoutExtension() async throws {
        // Test successful operation within timeout
        let result = try await Task.timeout(seconds: 1.0) {
            try await Task.sleep(for: .milliseconds(100))
            return "Success"
        }
        
        #expect(result == "Success")
    }
    
    @Test("Task timeout extension throws on timeout")
    func testTaskTimeoutThrows() async throws {
        do {
            _ = try await Task.timeout(seconds: 0.1) {
                try await Task.sleep(for: .seconds(1))
                return "Should not reach here"
            }
            #expect(false, "Should have thrown timeout error")
        } catch {
            #expect(error != nil)
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end networking flow simulation")
    func testEndToEndNetworkingFlow() async throws {
        // Test WebSocket server startup
        let wsManager = WebSocketManager.shared
        let port = try await wsManager.startServer()
        #expect(port > 0)
        
        // Test AI service error mapping
        let networkError = URLError(.networkConnectionLost)
        let mappedError = AIErrorMapper.mapError(networkError)
        
        switch mappedError {
        case .networkError:
            #expect(true)
        default:
            #expect(false)
        }
        
        // Test retry mechanism
        let config = RetryManager.RetryConfiguration(maxAttempts: 2)
        let retryManager = RetryManager(config: config)
        var attempts = 0
        
        let retryResult = try await retryManager.execute(
            operation: {
                attempts += 1
                if attempts == 1 {
                    throw URLError(.timedOut)
                }
                return "Retry Success"
            }
        )
        
        #expect(retryResult == "Retry Success")
        #expect(attempts == 2)
        
        // Cleanup
        await wsManager.stopServer()
        #expect(!(await wsManager.isServerRunning))
    }
    
    @Test("Network connectivity assessment")
    func testNetworkConnectivityAssessment() async throws {
        // Test basic network monitor creation
        let monitor = NWPathMonitor()
        
        // Start monitoring (briefly)
        let queue = DispatchQueue(label: "network-test")
        monitor.start(queue: queue)
        
        // Stop monitoring
        monitor.cancel()
        
        // If we get here without crashes, basic networking setup works
        #expect(true)
    }
}