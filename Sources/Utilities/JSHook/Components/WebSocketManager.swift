import Foundation
import Network
import Diagnostics

@MainActor
final class WebSocketManager {
    // MARK: - Properties
    
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var connection: NWConnection?
    private var handshakeCompleted = false
    private var pending: CheckedContinuation<String, Error>?
    
    var isConnected: Bool {
        connection != nil && connection?.state == .ready && handshakeCompleted
    }
    
    // MARK: - Initialization
    
    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }
    
    deinit {
        listener?.cancel()
        connection?.cancel()
    }
    
    // MARK: - Public Methods
    
    func startListener() async throws {
        let params = NWParameters.tcp
        let wsOpt = NWProtocolWebSocket.Options()
        wsOpt.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOpt, at: 0)
        
        do {
            listener = try NWListener(using: params, on: port)
        } catch {
            Logger(category: .jshook).error("❌ Failed to create listener on port \(port): \(error)")
            throw CursorJSHook.HookError.portInUse(port: port.rawValue)
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            Logger(category: .jshook).info("🌀 Listener received new connection attempt.")
            Task { @MainActor in
                self?.adoptConnection(connection)
            }
        }
        
        let startedSuccessfully = await startListenerAndWait()
        if !startedSuccessfully {
            throw CursorJSHook.HookError.portInUse(port: port.rawValue)
        }
        
        Logger(category: .jshook).info("🌀 Listening on ws://127.0.0.1:\(port)")
    }
    
    func waitForHandshake(timeout: TimeInterval = 10) async throws {
        Logger(category: .jshook).info("⏳ Waiting for renderer handshake...")
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if handshakeCompleted {
                Logger(category: .jshook).info("🤝 Renderer handshake complete.")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        
        throw CursorJSHook.HookError.connectionLost(
            underlyingError: NSError(
                domain: "TimeoutError",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "Handshake timeout after \(timeout) seconds"]
            )
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
    
    // MARK: - Private Methods
    
    private func startListenerAndWait() async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false
            listener?.stateUpdateHandler = { state in
                Task { @MainActor in
                    Logger(category: .jshook).debug("🌀 Listener state updated: \(state)")
                    
                    switch state {
                    case .ready:
                        if !resumed {
                            resumed = true
                            continuation.resume(returning: true)
                        }
                    case .failed:
                        if !resumed {
                            resumed = true
                            continuation.resume(returning: false)
                        }
                    default:
                        break
                    }
                }
            }
            listener?.start(queue: .main)
        }
    }
    
    private func adoptConnection(_ newConnection: NWConnection) {
        connection = newConnection
        handshakeCompleted = false
        
        Logger(category: .jshook).info("🌀 WS Connection adopted.")
        
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
        isComplete: Bool,
        error: Error?
    ) {
        guard self.connection === connection else {
            Logger(category: .jshook).debug("🌀 Ignoring message from stale connection.")
            return
        }
        
        if let error {
            Logger(category: .jshook).error("🌀 WS Receive error: \(error.localizedDescription)")
            cleanupConnection(error: .connectionLost(underlyingError: error))
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
        // Handle handshake
        if text == "ready" && !handshakeCompleted {
            handshakeCompleted = true
            Logger(category: .jshook).info("🤝 Handshake 'ready' message received.")
            return
        }
        
        // Handle heartbeat and other JSON messages
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            
            switch type {
            case "heartbeat":
                handleHeartbeat(json)
                return
            case "composerUpdate":
                handleComposerUpdate(json)
                return
            default:
                Logger(category: .jshook).warning("⚠️ Unknown message type '\(type)'")
            }
        }
        
        // Handle command responses
        if let pending = self.pending {
            self.pending = nil
            pending.resume(returning: text)
        }
    }
    
    private func handleHeartbeat(_ json: [String: Any]) {
        let version = json["version"] as? String ?? "unknown"
        let location = json["location"] as? String ?? "unknown"
        let resumeNeeded = json["resumeNeeded"] as? Bool ?? false
        
        Logger(category: .jshook).debug("💓 Heartbeat from v\(version) at \(location)")
        
        NotificationCenter.default.post(
            name: Notification.Name("CursorHeartbeat"),
            object: nil,
            userInfo: [
                "port": port.rawValue,
                "location": location,
                "version": version,
                "resumeNeeded": resumeNeeded
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
                "mutations": mutations
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