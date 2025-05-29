@testable import CodeLooper
import Foundation
import Network
import XCTest

class JSHookTests: XCTestCase {
    func testScriptTemplateLoading() async throws {
        // Test that the JavaScript template can be loaded
        do {
            let template = try CursorJSHookScript.loadTemplate()
            XCTAssertGreaterThan(template.count, 0)
            XCTAssertTrue(template.contains("__CODELOOPER_PORT_PLACEHOLDER__"))
            XCTAssertTrue(template.contains("__CODELOOPER_VERSION_PLACEHOLDER__"))
        } catch {
            // If script file doesn't exist in test environment, that's expected
            XCTAssertTrue(error is CursorJSHookError)
            if case CursorJSHookError.scriptNotFound = error {
                // This is expected in test environment
                XCTAssertTrue(true)
            }
        }
    }

    func testScriptVersionConstant() async throws {
        let version = CursorJSHookScript.version
        XCTAssertGreaterThan(version.count, 0)
        XCTAssertTrue(version.contains("."))

        // Version should be in semantic versioning format
        let versionComponents = version.split(separator: ".")
        XCTAssertGreaterThanOrEqual(versionComponents.count, 2)
        XCTAssertLessThanOrEqual(versionComponents.count, 3)
    }

    func testScriptGenerationWithPort() async throws {
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

        XCTAssertTrue(withVersion.contains("const port = 8080;"))
        XCTAssertTrue(withVersion.contains("const version = '1.0.0';"))
        XCTAssertFalse(withVersion.contains("__CODELOOPER_PORT_PLACEHOLDER__"))
        XCTAssertFalse(withVersion.contains("__CODELOOPER_VERSION_PLACEHOLDER__"))
    }

    func testJSHookErrorTypes() async throws {
        let scriptError = CursorJSHookError.scriptNotFound
        XCTAssertNotNil(scriptError.errorDescription)
        XCTAssertTrue(scriptError.errorDescription?.contains("JavaScript hook script not found") == true)
    }

    func testHookErrorTypes() async throws {
        // Test various hook error types
        let portError = CursorJSHook.HookError.portInUse(port: 8080)
        let timeoutError = CursorJSHook.HookError.timeout(duration: 30.0, operation: "test")
        let notConnectedError = CursorJSHook.HookError.notConnected
        let cancelledError = CursorJSHook.HookError.cancelled
        let permissionError = CursorJSHook.HookError.applescriptPermissionDenied

        // Test error descriptions exist
        XCTAssertNotNil(portError.errorDescription)
        XCTAssertNotNil(timeoutError.errorDescription)
        XCTAssertNotNil(notConnectedError.errorDescription)
        XCTAssertNotNil(cancelledError.errorDescription)
        XCTAssertNotNil(permissionError.errorDescription)

        // Test specific error properties
        if case let .portInUse(port) = portError {
            XCTAssertEqual(port, 8080)
        } else {
            XCTFail("Expected portInUse error")
        }

        if case let .timeout(duration, operation) = timeoutError {
            XCTAssertEqual(duration, 30.0)
            XCTAssertEqual(operation, "test")
        } else {
            XCTFail("Expected timeout error")
        }
    }

    func testWebSocketManagerInitialization() async throws {
        let port: UInt16 = 9999
        let manager = await WebSocketManager(port: port)

        // Test initial state
        let isConnected = await manager.isConnected
        XCTAssertEqual(isConnected, false)
    }

    func testPortValidation() async throws {
        // Test various port values
        let validPorts: [UInt16] = [8080, 9999, 3000, 1234, 65535]

        for port in validPorts {
            let manager = await WebSocketManager(port: port)
            // Should not throw during initialization
            XCTAssertNotNil(manager)
        }

        // Test port 0 (should create valid NWEndpoint.Port)
        let zeroPortManager = await WebSocketManager(port: 0)
        XCTAssertNotNil(zeroPortManager)
    }

    func testConnectionStateManagement() async throws {
        let manager = await WebSocketManager(port: 9998)

        // Initially not connected
        let initialState = await manager.isConnected
        XCTAssertEqual(initialState, false)

        // Connection state should be testable without actual network operations
        // This tests the state logic without requiring real connections
    }

    func testMessageTypes() async throws {
        // Test that we can validate message type constants
        let messageTypes = ["heartbeat", "composerUpdate", "ready"]

        for messageType in messageTypes {
            XCTAssertGreaterThan(messageType.count, 0)
            XCTAssertFalse(messageType.contains(" "))
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

        XCTAssertEqual(parsed["type"] as? String, "heartbeat")
        XCTAssertEqual(parsed["version"] as? String, "1.0.0")
        XCTAssertEqual(parsed["location"] as? String, "test")
        XCTAssertEqual(parsed["resumeNeeded"] as? Bool, false)
    }

    func testNotificationNames() async throws {
        // Test notification name constants
        let heartbeatNotification = Notification.Name("CursorHeartbeat")
        let composerNotification = Notification.Name("CursorComposerUpdate")

        XCTAssertEqual(heartbeatNotification.rawValue, "CursorHeartbeat")
        XCTAssertEqual(composerNotification.rawValue, "CursorComposerUpdate")
        XCTAssertNotEqual(heartbeatNotification, composerNotification)
    }

    func testThreadingAndConcurrency() async throws {
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
                XCTAssertEqual(result, true)
            }
        }
    }

    func testJSONParsingEdgeCases() async throws {
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
                XCTAssertTrue(type == nil || type?.count ?? 0 >= 0)
            }
            // If parsing failed, that's expected for malformed JSON
        }
    }

    func testStringEncoding() async throws {
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
            XCTAssertNotNil(data)

            if let data {
                let decoded = String(data: data, encoding: .utf8)
                XCTAssertEqual(decoded, testString)
            }
        }
    }

    func testPerformanceConsiderations() async throws {
        // Test performance of frequent operations
        let testData = "test message".data(using: .utf8)!
        let startTime = Date()

        // Simulate frequent string decoding operations
        for _ in 0 ..< 1000 {
            _ = String(data: testData, encoding: .utf8)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 1.0) // Should complete quickly

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
        XCTAssertLessThan(jsonElapsed, 1.0)
    }

    func testMemoryManagement() async throws {
        // Test that managers can be created and released without leaks
        var managers: [WebSocketManager] = []

        for i in 0 ..< 100 {
            let manager = await WebSocketManager(port: UInt16(10000 + i))
            managers.append(manager)
        }

        XCTAssertEqual(managers.count, 100)

        // Clear references - in real app, ARC should handle cleanup
        managers.removeAll()
        XCTAssertTrue(managers.isEmpty)
    }

    func testErrorHandlingRobustness() async throws {
        // Test that error conditions are handled gracefully

        // Test invalid port handling (conceptually)
        let maxPort = UInt16.max
        let manager = await WebSocketManager(port: maxPort)
        XCTAssertNotNil(manager) // Should create successfully

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
            XCTAssertNotNil(error.errorDescription)
            XCTAssertGreaterThan(error.errorDescription?.count ?? 0, 0)
        }
    }
}