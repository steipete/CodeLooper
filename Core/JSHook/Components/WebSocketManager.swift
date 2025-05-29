import Diagnostics
import Foundation
import Network
import Utilities

/// Manages WebSocket connections for JavaScript hook communication with Cursor.
///
/// WebSocketManager provides:
/// - WebSocket server functionality listening on a specified port
/// - Bidirectional communication channel between CodeLooper and injected JavaScript
/// - Message handling for commands and responses
/// - Connection state management and heartbeat monitoring
/// - Automatic reconnection handling
///
/// This is a core component of the JavaScript injection system, enabling
/// real-time control and monitoring of Cursor's web-based UI through
/// injected JavaScript code.
@MainActor
final class WebSocketManager: Loggable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    deinit {
        listener?.cancel()
        connection?.cancel()
    }

    // MARK: Internal

    var isConnected: Bool {
        connection != nil && connection?.state == .ready && handshakeCompleted
    }

    // MARK: - Public Methods

    func startListener() async throws {
        logger.info("🌐 Starting WebSocket listener on port \(port)...")

        let params = NWParameters.tcp
        let wsOpt = NWProtocolWebSocket.Options()
        wsOpt.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOpt, at: 0)

        do {
            listener = try NWListener(using: params, on: port)
            logger.debug("🔧 Created NWListener with WebSocket protocol")
        } catch {
            logger.error("❌ Failed to create listener on port \(port): \(error)")
            
            // Map specific errors to appropriate hook errors
            if let posixError = error as? POSIXError {
                switch posixError.code {
                case .EADDRINUSE:
                    throw CursorJSHook.HookError.portInUse(port: port.rawValue)
                case .EACCES:
                    throw CursorJSHook.HookError.applescriptPermissionDenied
                default:
                    throw CursorJSHook.HookError.networkError(URLError(.cannotConnectToHost))
                }
            } else {
                throw CursorJSHook.HookError.portInUse(port: port.rawValue)
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            logger.info("🌀 Browser connecting...")
            Task { @MainActor in
                self?.adoptConnection(connection)
            }
        }

        logger.info("👂 Starting listener...")
        let startedSuccessfully = await startListenerAndWait()
        if !startedSuccessfully {
            logger.error("🚫 Failed to start listener - port may be in use")
            throw CursorJSHook.HookError.portInUse(port: port.rawValue)
        }

        logger.info("🌀 Listening on ws://127.0.0.1:\(port) - ready for connections")
    }

    func waitForHandshake(timeout: TimeInterval = 120.0) async throws {
        logger.info("⏳ Waiting for browser to connect...")

        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if handshakeCompleted {
                let elapsed = Date().timeIntervalSince(startTime)
                logger.info("🤝 Connection established after \(String(format: "%.1f", elapsed))s")
                return
            }

            try await Task.sleep(seconds: TimingConfiguration.pollInterval)
        }

        logger.error("❌ Handshake timeout after \(timeout)s")
        throw CursorJSHook.HookError.timeout(
            duration: timeout,
            operation: "WebSocket handshake"
        )
    }

    func send(_ text: String) async throws -> String {
        guard let connection, handshakeCompleted else {
            throw CursorJSHook.HookError.notConnected
        }

        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "cmd", metadata: [meta])

        return try await withCheckedThrowingContinuation { continuation in
            self.pending = continuation
            connection.send(
                content: text.data(using: .utf8),
                contentContext: ctx,
                isComplete: true,
                completion: .contentProcessed { [weak self] error in
                    Task { @MainActor in
                        self?.handleSendCompletion(error: error)
                    }
                }
            )
        }
    }

    // MARK: Private

    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var connection: NWConnection?
    private var handshakeCompleted = false
    private var pending: CheckedContinuation<String, Error>?

    // MARK: - Private Methods

    private func startListenerAndWait() async -> Bool {
        await withCheckedContinuation { continuation in
            let resumedBox = ThreadSafeBox(false)
            
            listener?.stateUpdateHandler = { state in
                // Already on main queue, no need for Task creation
                self.logger.debug("🌀 Listener state updated: \(state)")

                switch state {
                case .ready:
                    if !resumedBox.get() {
                        resumedBox.set(true)
                        continuation.resume(returning: true)
                    }
                case .failed:
                    if !resumedBox.get() {
                        resumedBox.set(true)
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            listener?.start(queue: .main)
        }
    }

    private func adoptConnection(_ newConnection: NWConnection) {
        connection = newConnection
        handshakeCompleted = false

        newConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionStateChange(state, for: newConnection)
            }
        }

        newConnection.start(queue: .main)
    }

    private func handleConnectionStateChange(_ state: NWConnection.State, for connection: NWConnection) {
        Logger(category: .jshook).info("🌀 WS Connection state: \(state)")

        switch state {
        case .ready:
            Logger(category: .jshook).info("🌀 WS Connection is ready. Starting message pump.")
            startMessagePump(for: connection)
        case let .failed(error):
            Logger(category: .jshook).error("🌀 WS Connection failed: \(error.localizedDescription)")
            cleanupConnection(error: .connectionLost(underlyingError: error))
        case .cancelled:
            Logger(category: .jshook).info("🌀 WS Connection cancelled.")
            cleanupConnection(error: .cancelled)
        default:
            break
        }
    }

    private func startMessagePump(for connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                self?.handleReceivedMessage(
                    on: connection,
                    data: data,
                    isComplete: isComplete,
                    error: error
                )
            }
        }
    }

    private func handleReceivedMessage(
        on connection: NWConnection,
        data: Data?,
        isComplete _: Bool,
        error: Error?
    ) {
        guard self.connection === connection else {
            Logger(category: .jshook).debug("🌀 Ignoring message from stale connection.")
            return
        }

        if let error {
            let hookError: CursorJSHook.HookError
            
            // Map specific network errors to appropriate hook errors
            if let nwError = error as? NWError {
                switch nwError {
                case .posix(let code) where code == .ECONNREFUSED:
                    hookError = .connectionLost(underlyingError: error)
                case .posix(let code) where code == .ETIMEDOUT:
                    hookError = .timeout(duration: 0, operation: "message receive")
                case .posix(let code) where code == .EPIPE:
                    hookError = .connectionLost(underlyingError: error)
                default:
                    hookError = .networkError(URLError(.networkConnectionLost))
                }
            } else if let urlError = error as? URLError {
                hookError = .networkError(urlError)
            } else {
                hookError = .connectionLost(underlyingError: error)
            }
            
            Logger(category: .jshook).error("🌀 WS Receive error: \(hookError.errorDescription ?? error.localizedDescription)")
            cleanupConnection(error: hookError)
            return
        }

        if let data, let text = String(data: data, encoding: .utf8) {
            processReceivedText(text)
        }

        // Continue receiving messages
        if self.connection === connection {
            startMessagePump(for: connection)
        }
    }

    private func processReceivedText(_ text: String) {
        let logger = Logger(category: .jshook)

        // Handle handshake
        if text == "ready", !handshakeCompleted {
            handshakeCompleted = true
            logger.info("🤝 Handshake 'ready' message received - JS hook is now active!")
            logger.info("✅ WebSocket connection fully established on port \(port)")
            return
        }

        // Handle heartbeat and other JSON messages with specific types
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String
        {
            // Only handle known message types from JavaScript to Swift
            switch type {
            case "heartbeat":
                handleHeartbeat(json)
                return
            case "composerUpdate":
                handleComposerUpdate(json)
                return
            default:
                // If we have a pending command response, this might be it
                if let pending = self.pending {
                    self.pending = nil
                    pending.resume(returning: text)
                    return
                } else {
                    // Only warn about truly unknown message types
                    Logger(category: .jshook).warning("⚠️ Unknown message type '\(type)'")
                }
            }
        }

        // Handle command responses (messages without a type field)
        if let pending = self.pending {
            self.pending = nil
            pending.resume(returning: text)
        }
    }

    private func handleHeartbeat(_ json: [String: Any]) {
        let version = json["version"] as? String ?? "unknown"
        let location = json["location"] as? String ?? "unknown"
        let resumeNeeded = json["resumeNeeded"] as? Bool ?? false

        // Only log heartbeat in debug mode to reduce noise
        // Logger(category: .jshook).debug("💓 Heartbeat from v\(version) at \(location)")

        NotificationCenter.default.post(
            name: Notification.Name("CursorHeartbeat"),
            object: nil,
            userInfo: [
                "port": port.rawValue,
                "location": location,
                "version": version,
                "resumeNeeded": resumeNeeded,
            ]
        )
    }

    private func handleComposerUpdate(_ json: [String: Any]) {
        let content = json["content"] as? String ?? ""
        let timestamp = json["timestamp"] as? String ?? ""
        let isInitial = json["initial"] as? Bool ?? false
        let mutations = json["mutations"] as? Int ?? 0

        Logger(category: .jshook).info("📝 Composer update: \(mutations) mutations")

        NotificationCenter.default.post(
            name: Notification.Name("CursorComposerUpdate"),
            object: nil,
            userInfo: [
                "content": content,
                "timestamp": timestamp,
                "initial": isInitial,
                "mutations": mutations,
            ]
        )
    }

    private func handleSendCompletion(error: NWError?) {
        if let error {
            Logger(category: .jshook).error("🌀 WS Send error: \(error.localizedDescription)")
            if let pending = self.pending {
                self.pending = nil
                pending.resume(throwing: error)
            }
        } else {
            Logger(category: .jshook).debug("🌀 WS Send completed successfully")
        }
    }

    private func cleanupConnection(error: CursorJSHook.HookError) {
        connection?.cancel()
        connection = nil
        handshakeCompleted = false

        if let pending = self.pending {
            self.pending = nil
            pending.resume(throwing: error)
        }
    }
}
