import Diagnostics
import Foundation
import Network

@MainActor
public final class CursorJSHook {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Spin up the hook (starts listener, injects JS, waits for the renderer)
    /// - Parameters:
    ///   - applicationName: The name of the application to target (e.g., "Cursor")
    ///   - port: The port to use for WebSocket connection (default: 9001)
    ///   - skipInjection: If true, only starts listener without injecting (for probing)
    ///   - targetWindowTitle: Optional window title to target specifically
    public init(
        applicationName: String = "Cursor",
        port: UInt16 = 9001,
        skipInjection: Bool = false,
        targetWindowTitle: String? = nil
    ) async throws {
        self.applicationName = applicationName
        self.targetWindowTitle = targetWindowTitle
        self.port = port
        self.webSocketManager = WebSocketManager(port: port)
        self.injector = AppleScriptInjector(
            applicationName: applicationName,
            targetWindowTitle: targetWindowTitle,
            port: port
        )

        try await webSocketManager.startListener()

        if !skipInjection {
            let logger = Logger(category: .jshook)
            logger.info("💉 Injecting JavaScript hook...")
            try injector.inject()
            
            logger.info("⏳ Waiting for JavaScript to start WebSocket client...")
            // Give the browser time to parse and execute the injected JavaScript
            try await Task.sleep(for: .seconds(2))
            
            logger.info("🤝 Waiting for handshake from browser...")
            try await webSocketManager.waitForHandshake()
        }
    }

    // MARK: Public

    // MARK: - Types

    public enum HookError: Error {
        case notConnected
        case injectionFailed(Error?)
        case connectionLost(underlyingError: Error)
        case cancelled
        case portInUse(port: UInt16)
    }

    /// Returns true if the WebSocket connection is active and the handshake is complete
    public var isHooked: Bool {
        webSocketManager.isConnected
    }

    /// Get the port number for this hook
    public var portNumber: UInt16 {
        port
    }

    // MARK: - Public Methods

    /// Probe for an existing hook by waiting for a connection
    /// - Parameter timeout: How long to wait for a connection (in seconds)
    /// - Returns: True if a hook connected within the timeout
    public func probeForExistingHook(timeout: TimeInterval = 2.0) async -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if isHooked {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000) // 0.02 second
        }

        return false
    }

    /// Send a command to the JS hook and get the JSON-encoded result
    /// - Parameter command: A dictionary representing the command to send
    /// - Returns: The JSON-encoded result from the browser
    public func sendCommand(_ command: [String: Any]) async throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: command)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return try await webSocketManager.send(jsonString)
    }

    /// Legacy method - attempts to run raw JS code (will fail with Trusted Types)
    @available(*, deprecated, message: "Use sendCommand or specific helper methods instead")
    public func runJS(_ source: String) async throws -> String {
        let command = ["type": "rawCode", "code": source]
        return try await sendCommand(command)
    }

    // MARK: Private

    private let applicationName: String
    private let targetWindowTitle: String?
    private let port: UInt16
    private let webSocketManager: WebSocketManager
    private let injector: AppleScriptInjector
}
