import Foundation
import Testing
@testable import CodeLooper

// MARK: - Example of proper error handling with Swift Testing

@Suite("Error Handling Examples", .tags(.error_handling, .advanced))
struct ErrorHandlingExampleTests {
    
    // MARK: - Test Errors
    
    enum TestError: Error, Equatable {
        case invalidInput(String)
        case networkFailure(code: Int)
        case timeout
        case notFound
    }
    
    // MARK: - Mock Service
    
    struct MockService {
        func process(_ input: String) throws -> String {
            switch input {
            case "": throw TestError.invalidInput("Empty input not allowed")
            case "timeout": throw TestError.timeout
            case "404": throw TestError.notFound
            case "500": throw TestError.networkFailure(code: 500)
            default: return "Processed: \(input)"
            }
        }
        
        func asyncProcess(_ input: String) async throws -> String {
            try await Task.sleep(for: .milliseconds(10))
            return try process(input)
        }
    }
    
    // MARK: - Basic Error Testing
    
    @Suite("Basic Error Patterns", .tags(.basic))
    struct BasicErrorPatterns {
        let service = MockService()
        
        @Test("Validates that any error is thrown")
        func anyErrorThrown() {
            #expect(throws: Error.self) {
                try service.process("")
            }
        }
        
        @Test("Validates specific error type")
        func specificErrorType() {
            #expect(throws: TestError.self) {
                try service.process("timeout")
            }
        }
        
        @Test("Validates exact error value")
        func exactErrorValue() {
            #expect(throws: TestError.timeout) {
                try service.process("timeout")
            }
        }
        
        @Test("Validates no error is thrown")
        func noErrorThrown() {
            #expect(throws: Never.self) {
                try service.process("valid input")
            }
        }
    }
    
    // MARK: - Advanced Error Patterns
    
    @Suite("Advanced Error Patterns", .tags(.advanced))
    struct AdvancedErrorPatterns {
        let service = MockService()
        
        @Test("Error inspection with associated values")
        func errorInspection() {
            #expect(throws: TestError.self) {
                try service.process("500")
            } catch: { error in
                guard case let .networkFailure(code) = error else {
                    Issue.record("Expected network failure error")
                    return
                }
                #expect(code == 500, "Error code should be 500")
            }
        }
        
        @Test(
            "Multiple error scenarios",
            arguments: [
                (input: "", expectedError: TestError.invalidInput("Empty input not allowed")),
                (input: "timeout", expectedError: TestError.timeout),
                (input: "404", expectedError: TestError.notFound)
            ]
        )
        func multipleErrorScenarios(testCase: (input: String, expectedError: TestError)) {
            #expect(throws: testCase.expectedError) {
                try service.process(testCase.input)
            }
        }
        
        @Test("Async error handling")
        func asyncErrorHandling() async {
            #expect(throws: TestError.timeout) {
                try await service.asyncProcess("timeout")
            }
        }
    }
    
    // MARK: - Comparison with Old Patterns
    
    @Suite("Pattern Comparison", .tags(.advanced))
    struct PatternComparison {
        let service = MockService()
        
        @Test("Old do-catch pattern (NOT RECOMMENDED)")
        func oldDoCatchPattern() {
            // ❌ Old pattern - verbose and error-prone
            do {
                _ = try service.process("")
                Issue.record("Should have thrown an error")
            } catch let error as TestError {
                switch error {
                case .invalidInput(let message):
                    #expect(message == "Empty input not allowed")
                default:
                    Issue.record("Wrong error type")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
        
        @Test("New #expect(throws:) pattern (RECOMMENDED)")
        func newExpectThrowsPattern() {
            // ✅ New pattern - concise and clear
            #expect(throws: TestError.invalidInput("Empty input not allowed")) {
                try service.process("")
            }
        }
    }
    
    // MARK: - Real-World Patterns
    
    @Suite("Real-World Patterns", .tags(.integration))
    struct RealWorldPatterns {
        @Test("File operation error handling")
        func fileOperationErrors() {
            let invalidPath = "/this/path/does/not/exist/\(UUID().uuidString).txt"
            
            #expect(throws: Error.self) {
                let _ = try Data(contentsOf: URL(fileURLWithPath: invalidPath))
            }
        }
        
        @Test("JSON decoding error handling")
        func jsonDecodingErrors() {
            struct TestModel: Codable {
                let id: Int
                let name: String
            }
            
            let invalidJSON = "{ invalid json }".data(using: .utf8)!
            
            #expect(throws: DecodingError.self) {
                let _ = try JSONDecoder().decode(TestModel.self, from: invalidJSON)
            }
        }
        
        @Test(
            "Network error scenarios",
            arguments: [
                (URLError.notConnectedToInternet, "Network connection lost"),
                (.timedOut, "Request timed out"),
                (.cannotFindHost, "Server not found")
            ]
        )
        func networkErrorScenarios(errorCode: URLError.Code, expectedMessage: String) {
            let urlError = URLError(errorCode)
            
            // Simulate a function that would throw this error
            func simulateNetworkCall() throws {
                throw urlError
            }
            
            #expect(throws: URLError.self) {
                try simulateNetworkCall()
            } catch: { error in
                #expect(error.code == errorCode)
                // Verify error has appropriate description
                #expect(error.localizedDescription.count > 0)
            }
        }
    }
    
    // MARK: - Error Recovery Patterns
    
    @Suite("Error Recovery", .tags(.recovery))
    struct ErrorRecoveryPatterns {
        @Test("Retry on failure pattern")
        func retryOnFailure() async throws {
            var attemptCount = 0
            
            func flakeyOperation() throws -> String {
                attemptCount += 1
                if attemptCount < 3 {
                    throw TestError.networkFailure(code: 503)
                }
                return "Success on attempt \(attemptCount)"
            }
            
            // First two attempts should fail
            #expect(throws: TestError.networkFailure(code: 503)) {
                try flakeyOperation()
            }
            
            #expect(throws: TestError.networkFailure(code: 503)) {
                try flakeyOperation()
            }
            
            // Third attempt should succeed
            #expect(throws: Never.self) {
                let result = try flakeyOperation()
                #expect(result == "Success on attempt 3")
            }
        }
        
        @Test("Fallback value on error")
        func fallbackValueOnError() {
            func operationWithFallback(_ shouldFail: Bool) -> String {
                do {
                    if shouldFail {
                        throw TestError.notFound
                    }
                    return "Primary value"
                } catch {
                    return "Fallback value"
                }
            }
            
            #expect(operationWithFallback(false) == "Primary value")
            #expect(operationWithFallback(true) == "Fallback value")
        }
    }
}

// MARK: - Summary of Best Practices

/*
 Error Handling Best Practices with Swift Testing:
 
 1. Use #expect(throws: Error.self) for any error
 2. Use #expect(throws: SpecificError.self) for error types
 3. Use #expect(throws: SpecificError.value) for exact errors
 4. Use #expect(throws: Never.self) to assert no error
 5. Use the catch: closure for inspecting error details
 6. Combine with parameterized tests for multiple error cases
 7. Avoid verbose do-catch blocks in tests
 8. Let #expect show clear error messages automatically
 */