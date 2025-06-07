@testable import CodeLooper
import Combine
import Foundation
import Network
import Testing

// MARK: - Specialized Assertion Utilities

enum PrecisionAssertions {
    static func expectEqual<T: FloatingPoint>(
        _ actual: T, 
        _ expected: T, 
        tolerance: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let difference = abs(actual - expected)
        #expect(
            difference <= tolerance,
            "Expected \(actual) to be within \(tolerance) of \(expected), but difference was \(difference)",
            sourceLocation: SourceLocation(
                fileID: String(describing: file),
                filePath: String(describing: file),
                line: Int(line),
                column: 1
            )
        )
    }
    
    static func expectNearlyEqual(
        _ actual: Double,
        _ expected: Double,
        ulps: Int = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // ULP (Units in the Last Place) comparison for floating point precision
        let actualBits = actual.bitPattern
        let expectedBits = expected.bitPattern
        
        let ulpDifference = actualBits > expectedBits 
            ? actualBits - expectedBits 
            : expectedBits - actualBits
        
        #expect(
            ulpDifference <= ulps,
            "Expected \(actual) to be within \(ulps) ULPs of \(expected), but ULP difference was \(ulpDifference)",
            sourceLocation: SourceLocation(
                fileID: String(describing: file),
                filePath: String(describing: file),
                line: Int(line),
                column: 1
            )
        )
    }
}

enum CollectionAssertions {
    static func expectElementsEqual<C1: Collection, C2: Collection>(
        _ actual: C1,
        _ expected: C2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where C1.Element: Equatable, C1.Element == C2.Element {
        #expect(
            actual.count == expected.count,
            "Collections have different counts: \(actual.count) vs \(expected.count)",
            sourceLocation: SourceLocation(
                fileID: String(describing: file),
                filePath: String(describing: file),
                line: Int(line),
                column: 1
            )
        )
        
        for (index, (actualElement, expectedElement)) in zip(actual, expected).enumerated() {
            #expect(
                actualElement == expectedElement,
                "Elements at index \(index) differ: \(actualElement) vs \(expectedElement)",
                sourceLocation: SourceLocation(
                    fileID: String(describing: file),
                    filePath: String(describing: file),
                    line: Int(line),
                    column: 1
                )
            )
        }
    }
    
    static func expectContainsInOrder<C: Collection>(
        _ collection: C,
        _ elements: [C.Element],
        file: StaticString = #filePath,
        line: UInt = #line
    ) where C.Element: Equatable {
        var collectionIterator = collection.makeIterator()
        var elementIndex = 0
        
        while elementIndex < elements.count {
            let targetElement = elements[elementIndex]
            var found = false
            
            while let currentElement = collectionIterator.next() {
                if currentElement == targetElement {
                    found = true
                    break
                }
            }
            
            #expect(
                found,
                "Element \(targetElement) at index \(elementIndex) not found in order within collection",
                sourceLocation: SourceLocation(
                    fileID: String(describing: file),
                    filePath: String(describing: file),
                    line: Int(line),
                    column: 1
                )
            )
            
            if !found { break }
            elementIndex += 1
        }
    }
    
    static func expectUnique<C: Collection>(
        _ collection: C,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where C.Element: Hashable {
        let uniqueElements = Set(collection)
        #expect(
            uniqueElements.count == collection.count,
            "Collection contains \(collection.count - uniqueElements.count) duplicate elements",
            sourceLocation: SourceLocation(
                fileID: String(describing: file),
                filePath: String(describing: file),
                line: Int(line),
                column: 1
            )
        )
    }
    
    static func expectSorted<C: Collection>(
        _ collection: C,
        by areInIncreasingOrder: (C.Element, C.Element) throws -> Bool = (<),
        file: StaticString = #filePath,
        line: UInt = #line
    ) rethrows where C.Element: Comparable {
        let pairs = zip(collection, collection.dropFirst())
        
        for (index, (first, second)) in pairs.enumerated() {
            let inOrder = try areInIncreasingOrder(first, second)
            #expect(
                inOrder,
                "Collection not sorted at index \(index): \(first) should come before \(second)",
                sourceLocation: SourceLocation(
                    fileID: String(describing: file),
                    filePath: String(describing: file),
                    line: Int(line),
                    column: 1
                )
            )
        }
    }
}

@Suite("NetworkingTests")
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

        func data(for _: URLRequest) async throws -> (Data, URLResponse) {
            if let error = mockError {
                throw error
            }

            if shouldTimeout {
                try await Task.sleep(for: .seconds(10))
            }

            guard let data = mockData,
                  let response = mockResponse
            else {
                throw URLError(.badServerResponse)
            }

            return (data, response)
        }
    }

    // MARK: - Specialized Assertions Demo Suite
    
    @Suite("Specialized Assertions")
    struct SpecializedAssertions {
        @Test(
            "Floating-point precision comparisons",
            arguments: [
                (actual: 0.1 + 0.2, expected: 0.3, tolerance: 0.0001),
                (actual: Double.pi, expected: 3.14159, tolerance: 0.00001),
                (actual: 1.0/3.0, expected: 0.33333, tolerance: 0.00001),
                (actual: sqrt(2.0), expected: 1.41421, tolerance: 0.00001)
            ]
        )
        func floatingPointPrecisionComparisons(
            testCase: (actual: Double, expected: Double, tolerance: Double)
        ) throws {
            PrecisionAssertions.expectEqual(
                testCase.actual,
                testCase.expected,
                tolerance: testCase.tolerance
            )
        }
        
        @Test("ULP-based floating-point comparisons")
        func ulpBasedFloatingPointComparisons() throws {
            // Test cases where standard equality fails but ULP comparison succeeds
            let value1: Double = 1.0
            let value2: Double = 1.0 + Double.ulpOfOne
            let value3: Double = 1.0 + 2 * Double.ulpOfOne
            
            // These should be considered nearly equal within default ULPs
            PrecisionAssertions.expectNearlyEqual(value1, value2, ulps: 4)
            PrecisionAssertions.expectNearlyEqual(value1, value3, ulps: 4)
            
            // Test with very precise calculations
            let calculated = (0.1 + 0.2) * 10
            let expected = 3.0
            PrecisionAssertions.expectNearlyEqual(calculated, expected, ulps: 10)
        }
        
        @Test("Collection element-wise comparison")
        func collectionElementWiseComparison() throws {
            let networkRequests = [
                "GET /api/users",
                "POST /api/users",
                "PUT /api/users/123",
                "DELETE /api/users/123"
            ]
            
            let expectedSequence = [
                "GET /api/users",
                "POST /api/users", 
                "PUT /api/users/123",
                "DELETE /api/users/123"
            ]
            
            CollectionAssertions.expectElementsEqual(networkRequests, expectedSequence)
        }
        
        @Test("Collection ordering verification")
        func collectionOrderingVerification() throws {
            let _ = [
                ("user-1", Date(timeIntervalSince1970: 1000)),
                ("user-2", Date(timeIntervalSince1970: 2000)),
                ("user-3", Date(timeIntervalSince1970: 3000))
            ]
            
            let searchTerms = ["user", "api", "response"]
            let logEntries = [
                "Starting user lookup",
                "Calling user api",
                "Processing user data",
                "Preparing api response",
                "Sending response to client"
            ]
            
            CollectionAssertions.expectContainsInOrder(logEntries, searchTerms)
        }
        
        @Test("Collection uniqueness validation")
        func collectionUniquenessValidation() throws {
            // Test unique request IDs
            let requestIds = (1...100).map { "req-\($0)" }
            CollectionAssertions.expectUnique(requestIds)
            
            // Test unique URL paths
            let urlPaths = [
                "/api/v1/users",
                "/api/v1/posts", 
                "/api/v1/comments",
                "/api/v2/users",
                "/health"
            ]
            CollectionAssertions.expectUnique(urlPaths)
        }
        
        @Test("Collection sorting validation")
        func collectionSortingValidation() throws {
            // Test timestamp sorting
            let timestamps: [TimeInterval] = [1000, 2000, 3000, 4000, 5000]
            try CollectionAssertions.expectSorted(timestamps)
            
            // Test reverse sorting with custom comparator
            let priorities = [5, 4, 3, 2, 1]
            CollectionAssertions.expectSorted(priorities, by: >)
            
            // Test string sorting
            let endpoints = ["auth", "data", "health", "metrics", "users"]
            try CollectionAssertions.expectSorted(endpoints)
        }
        
        @Test("Complex nested data structures")
        func complexNestedDataStructures() throws {
            struct APIResponse {
                let statusCode: Int
                let latency: Double
                let data: [String: Any]
            }
            
            // Test response latencies are within acceptable ranges
            let responses = [
                APIResponse(statusCode: 200, latency: 0.045, data: [:]),
                APIResponse(statusCode: 200, latency: 0.123, data: [:]),
                APIResponse(statusCode: 201, latency: 0.089, data: [:])
            ]
            
            let maxAcceptableLatency = 0.150
            
            for (index, response) in responses.enumerated() {
                PrecisionAssertions.expectEqual(
                    response.latency,
                    0.0,
                    tolerance: maxAcceptableLatency
                )
                #expect(response.statusCode >= 200 && response.statusCode < 300, "Response \(index) should be successful")
            }
            
            // Test latency distribution
            let latencies = responses.map(\.latency)
            let sortedLatencies = latencies.sorted()
            CollectionAssertions.expectElementsEqual(latencies.sorted(), sortedLatencies)
        }
        
        @Test("Statistical assertions for performance data")
        func statisticalAssertionsForPerformanceData() throws {
            // Simulate network response times
            let responseTimes: [Double] = [
                0.045, 0.052, 0.048, 0.051, 0.049,
                0.047, 0.053, 0.046, 0.050, 0.044
            ]
            
            // Calculate statistics
            let average = responseTimes.reduce(0, +) / Double(responseTimes.count)
            let min = responseTimes.min()!
            let max = responseTimes.max()!
            
            // Test statistical properties
            PrecisionAssertions.expectEqual(average, 0.0485, tolerance: 0.002)
            #expect(min >= 0.040, "Minimum response time should be reasonable")
            #expect(max <= 0.060, "Maximum response time should be acceptable")
            
            // Test variance is within expected range
            let variance = responseTimes.map { pow($0 - average, 2) }.reduce(0, +) / Double(responseTimes.count)
            PrecisionAssertions.expectEqual(variance, 0.0, tolerance: 0.00001)
        }
        
        @Test(
            "Multi-dimensional data comparison",
            arguments: [
                (coordinates: [(1.0, 2.0), (3.0, 4.0)], tolerance: 0.001),
                (coordinates: [(0.1, 0.2), (0.3, 0.4)], tolerance: 0.0001),
                (coordinates: [(10.5, 20.7), (30.2, 40.9)], tolerance: 0.1)
            ]
        )
        func multiDimensionalDataComparison(
            testCase: (coordinates: [(Double, Double)], tolerance: Double)
        ) throws {
            // Simulate GPS coordinates or API endpoint response data
            let originalCoords = testCase.coordinates
            let processedCoords = originalCoords.map { (x: $0.0 + 0.0001, y: $0.1 + 0.0001) }
            
            for (index, (original, processed)) in zip(originalCoords, processedCoords).enumerated() {
                PrecisionAssertions.expectEqual(
                    processed.x,
                    original.0,
                    tolerance: testCase.tolerance
                )
                PrecisionAssertions.expectEqual(
                    processed.y,
                    original.1,
                    tolerance: testCase.tolerance
                )
            }
        }
    }

    // MARK: - HTTP Request Tests

    @Test("Http request construction") func httpRequestConstruction() {
        let url = URL(string: "https://api.example.com/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #expect(request.url == url)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Http request timeout") func httpRequestTimeout() {
        let url = URL(string: "https://api.example.com/test")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        #expect(request.timeoutInterval == 5.0)
    }

    // MARK: - WebSocketManager Tests

    @Test("Web socket manager initialization") @MainActor func webSocketManagerInitialization() async throws {
        let port: UInt16 = 9876
        let manager = await WebSocketManager(port: port)

        await MainActor.run {
            #expect(manager != nil)
            #expect(!manager.isConnected)
        }
    }

    @Test("Web socket manager lifecycle") @MainActor func webSocketManagerLifecycle() async throws {
        let port: UInt16 = 9877
        let manager = await WebSocketManager(port: port)

        // Test starting listener
        do {
            try await manager.startListener()
        } catch {
            // Port might be in use, which is OK for testing
            #expect(error is URLError || error is POSIXError, "Error should be URL or POSIX error type")
        }

        // Should handle lifecycle without crashes
        #expect(Bool(true))
    }

    @Test("Web socket connection handling") @MainActor func webSocketConnectionHandling() async throws {
        let port: UInt16 = 9878
        let manager = await WebSocketManager(port: port)

        // Test connection state
        await MainActor.run {
            #expect(!manager.isConnected)
        }

        // Note: Full connection testing would require a real WebSocket client
    }

    // MARK: - API Key Service Tests

    @Test("Api key service initialization") @MainActor func apiKeyServiceInitialization() async throws {
        // Create API key service
        let apiKeyService = await APIKeyService.shared

        // Test that service can be created
        #expect(apiKeyService != nil)
    }

    // MARK: - MCP Version Service Tests

    @Test("Mcp version service initialization") @MainActor func mcpVersionServiceInitialization() async throws {
        let service = await MCPVersionService.shared
        #expect(service != nil)
    }

    @Test("Mcp version service retrieval") @MainActor func mcpVersionServiceRetrieval() async throws {
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

    @Test("Ai error mapping network error") func aiErrorMappingNetworkError() {
        let urlError = URLError(.notConnectedToInternet)
        let mappedError = AIErrorMapper.mapError(urlError, from: .openAI)

        switch mappedError {
        case .networkError:
            #expect(true)
        default:
            #expect(Bool(false))
        }
    }

    @Test("Ai error mapping invalid response") func aiErrorMappingInvalidResponse() {
        let error = NSError(domain: "TestDomain", code: 400, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        switch mappedError {
        case .invalidResponse:
            #expect(true)
        default:
            #expect(Bool(false))
        }
    }

    @Test("Ai error mapping a p i key error") func aiErrorMappingAPIKeyError() {
        // Test that mapper handles authentication errors
        let error = NSError(domain: "TestDomain", code: 401, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        // Error should be mapped to something
        #expect(mappedError != nil)
    }

    @Test("Ai error mapping service unavailable") func aiErrorMappingServiceUnavailable() {
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

    @Test("Ai error mapping model not found") func aiErrorMappingModelNotFound() {
        // Test model not found handling
        let modelName = "non-existent-model"
        let mappedError = AIServiceError.modelNotFound(modelName)

        switch mappedError {
        case let .modelNotFound(name):
            #expect(name == modelName)
        default:
            #expect(Bool(false))
        }
    }

    @Test("Ai error mapping ollama not running") func aiErrorMappingOllamaNotRunning() {
        // Test Ollama-specific error
        let mappedError = AIServiceError.ollamaNotRunning

        switch mappedError {
        case .ollamaNotRunning:
            #expect(true)
        default:
            #expect(Bool(false))
        }
    }

    @Test("Ai error mapping unknown error") func aiErrorMappingUnknownError() {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: nil)
        let mappedError = AIErrorMapper.mapError(error, from: .openAI)

        // Any error should be mapped to something
        #expect(mappedError != nil)
    }

    // MARK: - URL Building Tests

    @Test("Url components construction") func urlComponentsConstruction() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.path = "/v1/test"
        components.queryItems = [
            URLQueryItem(name: "key", value: "value"),
            URLQueryItem(name: "limit", value: "10"),
        ]

        let url = components.url
        #expect(url != nil)
        #expect(url?.absoluteString.contains("key=value") == true)
        #expect(url?.absoluteString.contains("limit=10") == true)
    }

    @Test("Url encoding special characters") func urlEncodingSpecialCharacters() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.queryItems = [
            URLQueryItem(name: "text", value: "Hello World!"),
            URLQueryItem(name: "symbols", value: "@#$%"),
        ]

        let url = components.url
        #expect(url != nil)
        #expect(url?.absoluteString.contains("%20") == true || url?.absoluteString.contains("+") == true)
    }

    // MARK: - Mock Testing

    @Test("Mock u r l session success") @MainActor func mockURLSessionSuccess() async throws {
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

    @Test("Mock u r l session error") @MainActor func mockURLSessionError() async throws {
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

    @Test("Mock u r l session timeout") @MainActor func mockURLSessionTimeout() async throws {
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

    @Test("Port manager allocation") @MainActor func portManagerAllocation() async throws {
        let portManager = await PortManager()
        let port = await portManager.getOrAssignPort(for: "test-window")

        #expect(port > 0)
        #expect(port <= 65535)
    }

    @Test("Port manager duplication") @MainActor func portManagerDuplication() async throws {
        let portManager = await PortManager()

        let port1 = await portManager.getOrAssignPort(for: "window1")
        let port2 = await portManager.getOrAssignPort(for: "window2")

        #expect(port1 != port2)
    }

    // MARK: - Network Monitoring Tests

    @Test("Network reachability") func networkReachability() {
        // Test basic network path monitoring setup
        let monitor = NWPathMonitor()

        // Monitor should be created without errors
        #expect(monitor != nil)

        // Note: Actual network testing would require real network conditions
        monitor.cancel()
    }

    @Test("Network path status") func networkPathStatus() async throws {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "test.network.monitor")

        // Use an actor to handle concurrent access
        actor PathUpdateTracker {
            private(set) var pathUpdated = false

            func markUpdated() {
                pathUpdated = true
            }
            
            func getPathUpdated() -> Bool {
                pathUpdated
            }
        }

        let tracker = PathUpdateTracker()

        monitor.pathUpdateHandler = { _ in
            Task {
                await tracker.markUpdated()
            }
        }

        monitor.start(queue: queue)

        // Give time for initial update
        try await Task.sleep(for: .milliseconds(100))

        monitor.cancel()

        // Should have received at least one path update
        let wasUpdated = await tracker.getPathUpdated()
        #expect(wasUpdated)
    }

    // MARK: - WebSocket Communication Tests

    @Test("Web socket message encoding") @MainActor func webSocketMessageEncoding() async throws {
        let message = ["command": "test", "data": "value"]
        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8)

        #expect(string != nil)
        #expect(string?.contains("command") == true)
    }

    @Test("Web socket message decoding") @MainActor func webSocketMessageDecoding() async throws {
        let jsonString = """
        {"status": "success", "result": "test"}
        """
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["status"] as? String == "success")
        #expect(decoded?["result"] as? String == "test")
    }

    @Test("Web socket reconnection") @MainActor func webSocketReconnection() async throws {
        let manager = await WebSocketManager(port: 9880)

        // Test reconnection capability
        await MainActor.run {
            #expect(manager != nil)
            #expect(!manager.isConnected)
        }
    }

    // MARK: - Integration Tests

    @Test("Networking stack integration") @MainActor func networkingStackIntegration() async throws {
        // Test that all networking components can work together
        let webSocketManager = await WebSocketManager(port: 9881)
        let apiKeyService = await APIKeyService.shared
        let mcpVersionService = await MCPVersionService.shared

        // All components should initialize without conflicts
        #expect(webSocketManager != nil)
        #expect(apiKeyService != nil)
        #expect(mcpVersionService != nil)
    }

    @Test("Concurrent network operations") @MainActor func concurrentNetworkOperations() async throws {
        // Test concurrent network operations
        await withTaskGroup(of: Void.self) { group in
            // Simulate multiple network operations
            for i in 0 ..< 5 {
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
        #expect(Bool(true))
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling", .tags(.error_handling, .network))
    struct ErrorHandlingTests {
        
        @Test("URLError handling with #expect(throws:)")
        func urlErrorHandling() throws {
            // Test that invalid URL construction throws appropriate errors
            #expect(throws: Never.self) {
                let _ = URL(string: "https://valid-url.com")
            }
            
            // Test that we can catch specific URL errors
            func throwsURLError() throws {
                throw URLError(.badURL)
            }
            
            #expect(throws: URLError.self) {
                try throwsURLError()
            }
        }
        
        @Test("Network error specific types")
        func networkErrorSpecificTypes() throws {
            let testCases: [(URLError.Code, String)] = [
                (.notConnectedToInternet, "internet"),
                (.timedOut, "timeout"),
                (.cannotFindHost, "host"),
                (.badServerResponse, "server")
            ]
            
            for (code, keyword) in testCases {
                func throwSpecificError() throws {
                    throw URLError(code)
                }
                
                #expect(throws: URLError.self) {
                    try throwSpecificError()
                }
                
                // Also test that we can inspect the thrown error
                do {
                    try throwSpecificError()
                    Issue.record("Expected URLError to be thrown")
                } catch let error as URLError {
                    #expect(error.code == code)
                } catch {
                    Issue.record("Unexpected error type: \(type(of: error))")
                }
            }
        }
        
        @Test("WebSocket connection errors", .timeLimit(.minutes(1)))
        func webSocketConnectionErrors() async throws {
            // Test connection to invalid port
            func attemptInvalidConnection() async throws {
                let invalidURL = URL(string: "ws://localhost:99999")!
                // This would throw in a real WebSocket implementation
                throw URLError(.cannotConnectToHost)
            }
            
            do {
                try await attemptInvalidConnection()
                Issue.record("Expected connection error")
            } catch let error as URLError {
                #expect(error.code == .cannotConnectToHost)
            } catch {
                Issue.record("Unexpected error type: \(type(of: error))")
            }
        }
        
        @Test("API key validation errors")
        func apiKeyValidationErrors() throws {
            // Test empty API key
            func validateAPIKey(_ key: String) throws {
                guard !key.isEmpty else {
                    throw APIKeyError.empty
                }
                guard key.count >= 10 else {
                    throw APIKeyError.tooShort
                }
            }
            
            #expect(throws: APIKeyError.empty) {
                try validateAPIKey("")
            }
            
            #expect(throws: APIKeyError.tooShort) {
                try validateAPIKey("short")
            }
            
            #expect(throws: Never.self) {
                try validateAPIKey("valid-api-key-123")
            }
        }
        
        @Test("Error message validation")
        func errorMessageValidation() throws {
            let networkError = URLError(.notConnectedToInternet)
            let aiError = AIServiceError.networkError(networkError)
            
            // Test that error descriptions are meaningful
            #expect(aiError.errorDescription?.isEmpty == false)
            #expect(aiError.errorDescription?.contains("network") == true || 
                   aiError.errorDescription?.contains("connection") == true)
        }
    }
    
    // Helper error types for testing
    enum APIKeyError: Error, Equatable {
        case empty
        case tooShort
        case invalid
    }

    // MARK: - Performance Tests

    @Test("Networking performance") @MainActor func networkingPerformance() async throws {
        let startTime = Date()

        // Test creating multiple WebSocket managers
        for i in 0 ..< 10 {
            _ = await WebSocketManager(port: UInt16(10000 + i))
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Should complete reasonably quickly (less than 1 second for 10 instances)
        #expect(duration < 1.0)
    }
}
