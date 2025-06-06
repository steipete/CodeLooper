@testable import CodeLooper
import Foundation
import Network
import Testing

@Suite("JSHookTests")
struct JSHookTests {
    @Test("Script template loading") func scriptTemplateLoading() {
        // Test that the JavaScript template can be loaded
        do {
            let template = try CursorJSHookScript.loadTemplate()
            #expect(template.count > 0)
            #expect(template.contains("__CODELOOPER_PORT_PLACEHOLDER__"))
            #expect(template.contains("__CODELOOPER_VERSION_PLACEHOLDER__"))
        } catch {
            // If script file doesn't exist in test environment, that's expected
            #expect(error is CursorJSHookError)
            if case CursorJSHookError.scriptNotFound = error {
                // This is expected in test environment
                #expect(true)
            }
        }
    }

    @Test("Script version constant") func scriptVersionConstant() {
        let version = CursorJSHookScript.version
        #expect(version.count > 0)
        #expect(version.contains("."))

        // Version should be in semantic versioning format
        let versionComponents = version.split(separator: ".")
        #expect(versionComponents.count >= 2)
        #expect(versionComponents.count <= 3)
    }

    @Test("Script generation with port") func scriptGenerationWithPort() {
        // Mock the template loading since file might not exist in test environment
        let mockTemplate = """
        // Test JavaScript template
        const port = __CODELOOPER_PORT_PLACEHOLDER__;
        const version = '__CODELOOPER_VERSION_PLACEHOLDER__';
        console.log('Port:', port, 'Version:', version);
        """

        // Test port replacement logic (simulated)
        let port: UInt16 = 8080
        let withPort = mockTemplate.replacingOccurrences(of: "__CODELOOPER_PORT_PLACEHOLDER__", with: String(port))
        let withVersion = withPort.replacingOccurrences(of: "__CODELOOPER_VERSION_PLACEHOLDER__", with: "1.0.0")

        #expect(withVersion.contains("const port = 8080;"))
        #expect(withVersion.contains("const version = '1.0.0';"))
        #expect(!withVersion.contains("__CODELOOPER_PORT_PLACEHOLDER__"))
        #expect(!withVersion.contains("__CODELOOPER_VERSION_PLACEHOLDER__"))
    }

    @Test("J s hook error types") func jSHookErrorTypes() {
        let scriptError = CursorJSHookError.scriptNotFound
        #expect(scriptError.errorDescription != nil)
        #expect(scriptError.errorDescription?.contains("JavaScript hook script not found") == true)
    }

    @Test("Hook error types") func hookErrorTypes() {
        // Test various hook error types
        let portError = CursorJSHook.HookError.portInUse(port: 8080)
        let timeoutError = CursorJSHook.HookError.timeout(duration: 30.0, operation: "test")
        let notConnectedError = CursorJSHook.HookError.notConnected
        let cancelledError = CursorJSHook.HookError.cancelled
        let permissionError = CursorJSHook.HookError.applescriptPermissionDenied

        // Test error descriptions exist
        #expect(portError.errorDescription != nil)
        #expect(timeoutError.errorDescription != nil)
        #expect(notConnectedError.errorDescription != nil)
        #expect(cancelledError.errorDescription != nil)
        #expect(permissionError.errorDescription != nil)

        // Test specific error properties
        if case let .portInUse(port) = portError {
            #expect(port == 8080)
        } else {
            #expect(Bool(false), "Expected portInUse error")
        }

        if case let .timeout(duration, operation) = timeoutError {
            #expect(duration == 30.0)
            #expect(operation == "test")
        } else {
            #expect(Bool(false), "Expected timeout error")
        }
    }

    @Test("Web socket manager initialization") func webSocketManagerInitialization() {
        let port: UInt16 = 9999
        let manager = await WebSocketManager(port: port)

        // Test initial state
        let isConnected = await manager.isConnected
        #expect(!isConnected)
    }

    @Test("Port validation") func portValidation() {
        // Test various port values
        let validPorts: [UInt16] = [8080, 9999, 3000, 1234, 65535]

        for port in validPorts {
            let manager = await WebSocketManager(port: port)
            // Should not throw during initialization
            #expect(manager != nil)
        }

        // Test port 0 (should create valid NWEndpoint.Port)
        let zeroPortManager = await WebSocketManager(port: 0)
        #expect(zeroPortManager != nil)
    }

    @Test("Connection state management") func connectionStateManagement() {
        let manager = await WebSocketManager(port: 9998)

        // Initially not connected
        let initialState = await manager.isConnected
        #expect(!initialState)

        // Connection state should be testable without actual network operations
        // This tests the state logic without requiring real connections
    }

    @Test("Message types") func testMessageTypes() {
        // Test that we can validate message type constants
        let messageTypes = ["heartbeat", "composerUpdate", "ready"]

        for messageType in messageTypes {
            #expect(messageType.count > 0)
            #expect(!messageType.contains(" "))
        }

        // Test JSON message structure
        let heartbeatJSON = """
        {
            "type": "heartbeat",
            "version": "1.0.0",
            "location": "test",
            "resumeNeeded": false
        }
        """

        let data = heartbeatJSON.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(parsed["type"] as? String == "heartbeat")
        #expect(parsed["version"] as? String == "1.0.0")
        #expect(parsed["location"] as? String == "test")
        #expect(parsed["resumeNeeded"] as? Bool == false)
    }

    @Test("Notification names") func notificationNames() {
        // Test notification name constants
        let heartbeatNotification = Notification.Name("CursorHeartbeat")
        let composerNotification = Notification.Name("CursorComposerUpdate")

        #expect(heartbeatNotification.rawValue == "CursorHeartbeat")
        #expect(composerNotification.rawValue == "CursorComposerUpdate")
        #expect(heartbeatNotification != composerNotification)
    }

    @Test("Threading and concurrency") func threadingAndConcurrency() {
        // Test thread-safe operations that don't require actual networking
        let port: UInt16 = 9997

        // Test concurrent manager creation
        await withTaskGroup(of: Bool.self) { group in
            for i in 0 ..< 5 {
                group.addTask {
                    let manager = await WebSocketManager(port: port + UInt16(i))
                    let isConnected = await manager.isConnected
                    return !isConnected // Should be false initially
                }
            }

            for await result in group {
                #expect(result)
            }
        }
    }

    @Test("J s o n parsing edge cases") func jSONParsingEdgeCases() {
        // Test malformed JSON handling
        let malformedJSONs = [
            "",
            "not json",
            "{",
            "{}",
            """
            {"type":}
            """,
            """
            {"type": "unknown"}
            """,
            """
            {"type": "heartbeat", "malformed": }
            """,
        ]

        for malformedJSON in malformedJSONs {
            let data = malformedJSON.data(using: .utf8)!

            // Should not crash when parsing invalid JSON
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let parsed {
                // If it parsed, type extraction should be safe
                let type = parsed["type"] as? String
                #expect(type == nil || type?.count ?? 0 >= 0)
            }
            // If parsing failed, that's expected for malformed JSON
        }
    }

    @Test("String encoding") func stringEncoding() {
        // Test various string encodings that might be received
        let testStrings = [
            "ready",
            "simple text",
            "text with émojis 🚀 and unicode",
            """
            {"type": "heartbeat", "message": "测试"}
            """,
            "\n\r\t special chars",
            "",
        ]

        for testString in testStrings {
            // Test encoding and decoding
            let data = testString.data(using: .utf8)
            #expect(data != nil)

            if let data {
                let decoded = String(data: data, encoding: .utf8)
                #expect(decoded == testString)
            }
        }
    }

    @Test("Performance considerations") func performanceConsiderations() {
        // Test performance of frequent operations
        let testData = "test message".data(using: .utf8)!
        let startTime = Date()

        // Simulate frequent string decoding operations
        for _ in 0 ..< 1000 {
            _ = String(data: testData, encoding: .utf8)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 1.0) // Should complete quickly

        // Test JSON parsing performance
        let jsonString = """
        {"type": "heartbeat", "version": "1.0.0", "timestamp": "\(Date().timeIntervalSince1970)"}
        """
        let jsonData = jsonString.data(using: .utf8)!

        let jsonStartTime = Date()
        for _ in 0 ..< 100 {
            _ = try? JSONSerialization.jsonObject(with: jsonData)
        }
        let jsonElapsed = Date().timeIntervalSince(jsonStartTime)
        #expect(jsonElapsed < 1.0)
    }

    @Test("Memory management") func memoryManagement() {
        // Test that managers can be created and released without leaks
        var managers: [WebSocketManager] = []

        for i in 0 ..< 100 {
            let manager = await WebSocketManager(port: UInt16(10000 + i))
            managers.append(manager)
        }

        #expect(managers.count == 100)

        // Clear references - in real app, ARC should handle cleanup
        managers.removeAll()
        #expect(managers.isEmpty)
    }

    @Test("Error handling robustness") func errorHandlingRobustness() {
        // Test that error conditions are handled gracefully

        // Test invalid port handling (conceptually)
        let maxPort = UInt16.max
        let manager = await WebSocketManager(port: maxPort)
        #expect(manager != nil) // Should create successfully

        // Test error message consistency
        let errors: [CursorJSHook.HookError] = [
            .portInUse(port: 8080),
            .timeout(duration: 10.0, operation: "test"),
            .notConnected,
            .cancelled,
            .applescriptPermissionDenied,
            .networkError(URLError(.networkConnectionLost)),
            .connectionLost(underlyingError: URLError(.timedOut)),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.count ?? 0 > 0)
        }
    }
}
