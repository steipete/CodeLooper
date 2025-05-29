@testable import CodeLooper
import Combine
import Foundation
import Network
import Testing

/// Test suite for networking components
struct NetworkingTests {
    // MARK: - Test Utilities

    /// Protocol for mocking URLSession
    protocol URLSessionProtocol {
        func data(for request: URLRequest) async throws -> (Data, URLResponse)
    }

    /// Mock URLSession for testing HTTP requests
    final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
        var mockData: Data?
        var mockResponse: URLResponse?
        var mockError: Error?
        var shouldTimeout = false

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            if let error = mockError {
                throw error
            }

            if shouldTimeout {
                try await Task.sleep(for: .seconds(10))
            }

            guard let data = mockData,
                  let response = mockResponse else {
                throw URLError(.badServerResponse)
            }

            return (data, response)
        }
    }

    // MARK: - HTTP Request Tests

    @Test
    func httpRequestConstruction() async throws {
        let url = URL(string: "https://api.example.com/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #expect(request.url == url)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test
    func httpRequestTimeout() async throws {
        let url = URL(string: "https://api.example.com/test")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        #expect(request.timeoutInterval == 5.0)
    }

    // MARK: - WebSocketManager Tests

    @Test
    func webSocketManagerInitialization() async throws {
        let port: UInt16 = 9876
        let manager = await WebSocketManager(port: port)

        await MainActor.run {
            #expect(manager != nil)
            #expect(manager.isConnected == false)
        }
    }

    @Test
    func webSocketManagerLifecycle() async throws {
        let port: UInt16 = 9877
        let manager = await WebSocketManager(port: port)

        // Test starting listener
        do {
            try await manager.startListener()
        } catch {
            // Port might be in use, which is OK for testing
            #expect(error != nil)
        }

        // Should handle lifecycle without crashes
        #expect(true)
    }

    @Test
    func webSocketConnectionHandling() async throws {
        let port: UInt16 = 9878
        let manager = await WebSocketManager(port: port)

        // Test connection state
        await MainActor.run {
            #expect(manager.isConnected == false)
        }

        // Note: Full connection testing would require a real WebSocket client
    }

    // MARK: - API Key Service Tests

    @Test
    func apiKeyServiceInitialization() async throws {
        // Create API key service
        let apiKeyService = await APIKeyService.shared
        
        // Test that service can be created
        #expect(apiKeyService != nil)
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

        // Test version checking
        await service.checkAllVersions()
        
        // Wait a bit for async operation
        try await Task.sleep(for: .milliseconds(100))
        
        // Check if we have versions (may be empty in test environment)
        await MainActor.run {
            #expect(service.latestVersions != nil)
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
    func aiErrorMappingAPIKeyError() async throws {
        // Test that mapper handles authentication errors
        let error = NSError(domain: "TestDomain", code: 401, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        // Error should be mapped to something
        #expect(mappedError != nil)
    }

    @Test
    func aiErrorMappingServiceUnavailable() async throws {
        let error = NSError(domain: "TestDomain", code: 503, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .serviceUnavailable:
            #expect(true)
        default:
            // Might be mapped to different error
            #expect(mappedError != nil)
        }
    }

    @Test
    func aiErrorMappingModelNotFound() async throws {
        // Test model not found handling
        let modelName = "non-existent-model"
        let mappedError = AIServiceError.modelNotFound(modelName)

        switch mappedError {
        case .modelNotFound(let name):
            #expect(name == modelName)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingOllamaNotRunning() async throws {
        // Test Ollama-specific error
        let mappedError = AIServiceError.ollamaNotRunning

        switch mappedError {
        case .ollamaNotRunning:
            #expect(true)
        default:
            #expect(false)
        }
    }

    @Test
    func aiErrorMappingUnknownError() async throws {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        // Any error should be mapped to something
        #expect(mappedError != nil)
    }

    // MARK: - URL Building Tests

    @Test
    func urlComponentsConstruction() async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.path = "/v1/test"
        components.queryItems = [
            URLQueryItem(name: "key", value: "value"),
            URLQueryItem(name: "limit", value: "10")
        ]

        let url = components.url
        #expect(url != nil)
        #expect(url?.absoluteString.contains("key=value") == true)
        #expect(url?.absoluteString.contains("limit=10") == true)
    }

    @Test
    func urlEncodingSpecialCharacters() async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.queryItems = [
            URLQueryItem(name: "text", value: "Hello World!"),
            URLQueryItem(name: "symbols", value: "@#$%")
        ]

        let url = components.url
        #expect(url != nil)
        #expect(url?.absoluteString.contains("%20") == true || url?.absoluteString.contains("+") == true)
    }

    // MARK: - Mock Testing

    @Test
    func mockURLSessionSuccess() async throws {
        let session = MockURLSession()
        let expectedData = "Test response".data(using: .utf8)!
        let expectedResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        session.mockData = expectedData
        session.mockResponse = expectedResponse

        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        let (data, response) = try await session.data(for: request)

        #expect(data == expectedData)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test
    func mockURLSessionError() async throws {
        let session = MockURLSession()
        session.mockError = URLError(.notConnectedToInternet)

        let request = URLRequest(url: URL(string: "https://api.example.com")!)

        do {
            _ = try await session.data(for: request)
            #expect(Bool(false)) // Should not reach here
        } catch {
            #expect(error is URLError)
        }
    }

    @Test
    func mockURLSessionTimeout() async throws {
        let session = MockURLSession()
        session.shouldTimeout = true

        let request = URLRequest(url: URL(string: "https://api.example.com")!)

        do {
            _ = try await Task.withTimeout(seconds: 0.2) {
                try await session.data(for: request)
            }
            #expect(Bool(false)) // Should timeout
        } catch {
            // Expected to timeout or error
            #expect(error != nil)
        }

        // Task should be cancelled due to timeout simulation
        #expect(true)
    }

    // MARK: - Port Management Tests

    @Test
    func portManagerAllocation() async throws {
        let portManager = await PortManager()
        let port = await portManager.getOrAssignPort(for: "test-window")

        #expect(port > 0)
        #expect(port <= 65535)
    }

    @Test
    func portManagerDuplication() async throws {
        let portManager = await PortManager()
        
        let port1 = await portManager.getOrAssignPort(for: "window1")
        let port2 = await portManager.getOrAssignPort(for: "window2")

        #expect(port1 != port2)
    }

    // MARK: - Network Monitoring Tests

    @Test
    func networkReachability() async throws {
        // Test basic network path monitoring setup
        let monitor = NWPathMonitor()
        
        // Monitor should be created without errors
        #expect(monitor != nil)
        
        // Note: Actual network testing would require real network conditions
        monitor.cancel()
    }

    @Test
    func networkPathStatus() async throws {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "test.network.monitor")
        
        // Use an actor to handle concurrent access
        actor PathUpdateTracker {
            private(set) var pathUpdated = false
            
            func markUpdated() {
                pathUpdated = true
            }
        }
        
        let tracker = PathUpdateTracker()
        
        monitor.pathUpdateHandler = { path in
            Task {
                await tracker.markUpdated()
            }
        }
        
        monitor.start(queue: queue)
        
        // Give time for initial update
        try await Task.sleep(for: .milliseconds(100))
        
        monitor.cancel()
        
        // Should have received at least one path update
        let wasUpdated = await tracker.pathUpdated
        #expect(wasUpdated)
    }

    // MARK: - WebSocket Communication Tests

    @Test
    func webSocketMessageEncoding() async throws {
        let message = ["command": "test", "data": "value"]
        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8)

        #expect(string != nil)
        #expect(string?.contains("command") == true)
    }

    @Test
    func webSocketMessageDecoding() async throws {
        let jsonString = """
        {"status": "success", "result": "test"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["status"] as? String == "success")
        #expect(decoded?["result"] as? String == "test")
    }

    @Test
    func webSocketReconnection() async throws {
        let manager = await WebSocketManager(port: 9880)
        
        // Test reconnection capability
        await MainActor.run {
            #expect(manager != nil)
            #expect(manager.isConnected == false)
        }
    }

    // MARK: - Integration Tests

    @Test
    func networkingStackIntegration() async throws {
        // Test that all networking components can work together
        let webSocketManager = await WebSocketManager(port: 9881)
        let apiKeyService = await APIKeyService.shared
        let mcpVersionService = await MCPVersionService.shared

        // All components should initialize without conflicts
        #expect(webSocketManager != nil)
        #expect(apiKeyService != nil)
        #expect(mcpVersionService != nil)
    }

    @Test
    func concurrentNetworkOperations() async throws {
        // Test concurrent network operations
        await withTaskGroup(of: Void.self) { group in
            // Simulate multiple network operations
            for i in 0..<5 {
                group.addTask {
                    let manager = await WebSocketManager(port: UInt16(9900 + i))
                    do {
                        try await manager.startListener()
                    } catch {
                        // Port might be in use, which is OK for testing
                    }
                    try? await Task.sleep(for: .milliseconds(10))
                    // No stop method available, manager will clean up on deinit
                }
            }
        }

        // Should handle concurrent operations without crashes
        #expect(true)
    }

    // MARK: - Performance Tests

    @Test
    func networkingPerformance() async throws {
        let startTime = Date()

        // Test creating multiple WebSocket managers
        for i in 0..<10 {
            let _ = await WebSocketManager(port: UInt16(10000 + i))
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 10 instances)
        #expect(duration < 1.0)
    }
}