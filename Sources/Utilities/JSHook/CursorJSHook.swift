import Foundation
import Network

@MainActor
public final class CursorJSHook {
    // MARK: Lifecycle

    /// Spin up the hook (starts listener, injects JS, waits for the renderer).
    /// - Parameters:
    ///   - applicationName: The name of the application to target (e.g., "Cursor").
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
        self.port = NWEndpoint.Port(rawValue: port)!
        try await startListener()
        if !skipInjection {
            try injectViaAppleScript() // Changed to synchronous throw
            try await waitForRendererHandshake()
        }
    }

    // MARK: Public

    public enum HookError: Error {
        case notConnected
        case injectionFailed(Error?)
        case connectionLost(underlyingError: Error)
        case cancelled
        case portInUse(port: UInt16)
        // Consider adding case handshakeTimeout if a timeout mechanism is implemented
    }

    /// Returns true if the WebSocket connection is active and the handshake is complete.
    public var isHooked: Bool {
        conn != nil && conn?.state == .ready && handshakeCompleted
    }

    /// Get the port number for this hook
    public var portNumber: UInt16 {
        port.rawValue
    }

    /// Probe for an existing hook by waiting for a connection
    /// - Parameter timeout: How long to wait for a connection (in seconds)
    /// - Returns: True if a hook connected within the timeout
    public func probeForExistingHook(timeout: TimeInterval = 2.0) async -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if isHooked {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000) // 0.02 second (reduced from 0.1)
        }

        return false
    }

    /// Eval JS inside Cursor and get the JSON-encoded result
    public func runJS(_ source: String) async throws -> String {
        guard let conn, handshakeCompleted else { throw HookError.notConnected }
        return try await send(source, over: conn)
    }

    // MARK: Private

    // ──────────────────────────────  public API  ──────────────────────────────
    private let applicationName: String
    private let targetWindowTitle: String?
    private var handshakeCompleted: Bool = false

    // ──────────────────────────────  internals  ──────────────────────────────
    private let port: NWEndpoint.Port
    private var listener: NWListener!
    private var conn: NWConnection?
    private var pending: CheckedContinuation<String, Error>?

    // 1️⃣ Web-Socket listener
    private func startListener() async throws {
        let params = NWParameters.tcp
        let wsOpt = NWProtocolWebSocket.Options()
        wsOpt.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOpt, at: 0)

        do {
            listener = try NWListener(using: params, on: port)
        } catch {
            // Port might be in use
            print("❌ Failed to create listener on port \(port): \(error)")
            throw HookError.portInUse(port: port.rawValue)
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            print("🌀 Listener received new connection attempt.")
            Task { @MainActor in
                self?.adopt(connection)
            }
        }
        
        var listenerStarted = false
        let startContinuation = await withCheckedContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] newState in
                Task { @MainActor in
                    guard self != nil else { return }
                    print("🌀 Listener state updated: \(newState)")
                    
                    switch newState {
                    case .ready:
                        if !listenerStarted {
                            listenerStarted = true
                            continuation.resume(returning: true)
                        }
                    case let .failed(error):
                        print("🌀 Listener failed: \(error)")
                        if !listenerStarted {
                            listenerStarted = true
                            continuation.resume(returning: false)
                        }
                    default:
                        break
                    }
                }
            }
            
            listener.start(queue: .main)
        }
        
        if !startContinuation {
            throw HookError.portInUse(port: port.rawValue)
        }
        
        print("🌀  Listening on ws://127.0.0.1:\(port) for \(self.applicationName)")
    }

    // 2️⃣ AppleScript UI-drive
    private func injectViaAppleScript() throws {
        print("🎯 Starting AppleScript injection for \(self.applicationName)")

        let js = generateJavaScriptHook()
        let script = buildAppleScript(javascript: js)

        try executeAppleScript(script)
    }

    private func generateJavaScriptHook() -> String {
        """
        (function() {
            // Check if hook already exists
            if (window.__codeLooperHook && window.__codeLooperHook.readyState === WebSocket.OPEN) {
                console.log('🔄 CodeLooper: Hook already active on port ' + window.__codeLooperHook.url);
                return 'CodeLooper hook already active';
            }
            
            const port = \(port);
            const url = 'ws://127.0.0.1:' + port;
            let reconnectAttempts = 0;
            const maxReconnectAttempts = 5;
            const reconnectDelay = 3000; // 3 seconds
            
            function connect() {
                console.log('🔄 CodeLooper: Attempting to connect to ' + url);
                
                try {
                    const ws = new WebSocket(url);
                    
                    ws.onopen = () => {
                        console.log('🔄 CodeLooper: Connected to ' + url);
                        ws.send('ready');
                        reconnectAttempts = 0; // Reset on successful connection
                    };
                    
                    ws.onerror = (e) => {
                        console.log('🔄 CodeLooper: WebSocket error', e);
                    };
                    
                    ws.onclose = (e) => {
                        console.log('🔄 CodeLooper: WebSocket closed', e);
                        window.__codeLooperHook = null;
                        
                        // Auto-reconnect logic
                        if (reconnectAttempts < maxReconnectAttempts) {
                            reconnectAttempts++;
                            console.log(`🔄 CodeLooper: Reconnecting in ${reconnectDelay/1000}s... (attempt ${reconnectAttempts}/${maxReconnectAttempts})`);
                            setTimeout(connect, reconnectDelay);
                        } else {
                            console.log('🔄 CodeLooper: Max reconnection attempts reached. Hook disabled.');
                        }
                    };
                    
                    ws.onmessage = (e) => {
                        let result;
                        try {
                            // Try using Function constructor as a fallback for eval
                            const AsyncFunction = (async function() {}).constructor;
                            const fn = new AsyncFunction('return (' + e.data + ')');
                            result = fn();
                            
                            // Handle promises
                            if (result && typeof result.then === 'function') {
                                result.then(r => ws.send(JSON.stringify(r)))
                                       .catch(err => ws.send(JSON.stringify({ error: err.message, stack: err.stack })));
                                return;
                            }
                        } catch(error) {
                            // If Function constructor also fails, try to execute as a simple expression
                            try {
                                // For simple property access, we can use a safer approach
                                if (e.data.match(/^[\\w\\.\\[\\]'"]+$/)) {
                                    result = Function('"use strict"; return ' + e.data)();
                                } else {
                                    result = { 
                                        error: 'Trusted Types policy prevents eval. Code execution limited.', 
                                        attempted: e.data,
                                        actualError: error.message 
                                    };
                                }
                            } catch(innerError) {
                                result = { error: innerError.message, stack: innerError.stack };
                            }
                        }
                        ws.send(JSON.stringify(result));
                    };
                    
                    // Store reference globally
                    window.__codeLooperHook = ws;
                    window.__codeLooperPort = port;
                    
                } catch(err) {
                    console.error('🔄 CodeLooper: Failed to create WebSocket', err);
                    return 'CodeLooper hook failed: ' + err.message;
                }
            }
            
            // Start connection
            connect();
            
            return 'CodeLooper hook installing on port ' + port + '...';
        })();
        """
    }

    private func buildAppleScript(javascript js: String) -> String {
        let windowTarget = targetWindowTitle != nil ? "window \"\(targetWindowTitle!)\"" : "front window"

        return """
        tell application "\(self.applicationName)"
            activate
            delay 0.5
        end tell

        tell application "System Events"
            tell process "\(self.applicationName)"
                # Target specific window by name if provided, otherwise use front window
                set targetWindow to \(windowTarget)
                
                # Focus the window
                set frontmost to true
                set focused of targetWindow to true
                delay 0.5
                
                # Toggle developer tools console
                keystroke "P" using {shift down, command down}
                delay 1.0
                keystroke ">Developer: Toggle Developer Tools"
                delay 0.5
                key code 36 # Enter
                delay 2.0
                
                # Clear any existing content
                keystroke "a" using {command down}
                delay 0.2
                key code 117 # Delete
                delay 0.2
                
                # Paste the JavaScript
                set the clipboard to "\(js)"
                delay 0.3
                keystroke "v" using {command down}
                delay 0.5
                
                # Execute
                key code 36 # Enter
                delay 0.5
            end tell
        end tell
        """
    }


    private func executeAppleScript(_ script: String) throws {
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)

        if result == nil || errorDict != nil {
            if let error = errorDict {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                print("🍎 AppleScript injection failed: \(errorMessage) (Code: \(errorNumber))")

                // Check for specific error codes
                if errorNumber == -1743 {
                    print(
                        "⚠️  User denied automation permission. Please grant permission in System Settings > Privacy & Security > Automation"
                    )
                } else if errorNumber == -600 {
                    print("⚠️  Application not running or not found")
                } else if errorNumber == -10004 {
                    print("⚠️  A privilege violation occurred")
                }

                // Create a custom error or use a generic one
                let nsError = NSError(
                    domain: "AppleScriptError",
                    code: errorNumber,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                throw HookError.injectionFailed(nsError)
            } else {
                print("🍎 AppleScript injection failed with no error info.")
                throw HookError.injectionFailed(nil)
            }
        }
        print("🍏 AppleScript executed successfully for \(self.applicationName).")
    }

    // 3️⃣ Wait for renderer's "ready"
    private func waitForRendererHandshake() async throws {
        print("⏳ Waiting for renderer handshake...")

        // Use a simpler approach with Task.sleep and polling
        let startTime = Date()
        let timeout: TimeInterval = 10

        while Date().timeIntervalSince(startTime) < timeout {
            if handshakeCompleted {
                print("🤝 Renderer handshake complete.")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        // Timeout occurred
        throw HookError.connectionLost(underlyingError: NSError(
            domain: "TimeoutError",
            code: -1001,
            userInfo: [NSLocalizedDescriptionKey: "Handshake timeout after \(timeout) seconds"]
        ))
    }

    // adopt a new WS connection
    private func adopt(_ connection: NWConnection) {
        self.conn = connection
        self.handshakeCompleted = false // Reset on new connection attempt
        print("🌀 WS Connection adopted. Waiting for state updates.")

        connection.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                print("🌀 WS Connection state: \(newState)")
                switch newState {
                case .ready:
                    print("🌀 WS Connection is ready. Starting pump.")
                    self.pump(connection)
                case let .failed(error):
                    print("🌀 WS Connection failed: \(error.localizedDescription)")
                    self.cleanupConnection(error: HookError.connectionLost(underlyingError: error))
                case .cancelled:
                    print("🌀 WS Connection cancelled.")
                    self.cleanupConnection(error: HookError.cancelled)
                default:
                    // Other states like .preparing, .waiting are transient
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func cleanupConnection(error: HookError) {
        conn?.cancel()
        conn = nil
        handshakeCompleted = false
        if let pendingContinuation = self.pending {
            self.pending = nil
            pendingContinuation.resume(throwing: error)
        }
        // Optional: Notify listener or attempt to re-establish if appropriate for the use case
    }
    
    deinit {
        // Clean up listener and connection
        listener?.cancel()
        conn?.cancel()
    }

    // pump is already @MainActor isolated
    private func pump(_ connection: NWConnection) {
        print("🌀 Setting up receiveMessage on connection \(connection.debugDescription)")
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            // This closure is @Sendable. We must dispatch to MainActor to interact with self
            Task { @MainActor in
                guard let self else {
                    print("泵 CursorJSHook self is nil, cannot process message.")
                    return
                }
                // Ensure the connection being processed is still the active one.
                guard self.conn === connection else {
                    print(
                        "泵 Stale connection \(connection.debugDescription), current is \(self.conn?.debugDescription ?? "nil"). Ignoring message."
                    )
                    return
                }

                var shouldContinuePumping = true

                if let error {
                    print(
                        "🌀 WS Receive error on \(connection.debugDescription): \(error.localizedDescription). Cleaning up connection."
                    )
                    self.cleanupConnection(error: .connectionLost(underlyingError: error))
                    shouldContinuePumping = false // Stop pumping on error
                }

                if shouldContinuePumping, let messageData = data, !messageData.isEmpty,
                   let txt = String(data: messageData, encoding: .utf8)
                {
                    print("🌀 WS Received on \(connection.debugDescription): \(txt)")
                    if txt == "ready" {
                        if !self.handshakeCompleted {
                            self.handshakeCompleted = true
                            print("🤝 Handshake 'ready' message processed for \(connection.debugDescription).")
                        } else {
                            print(
                                "⚠️ Received 'ready' message again on \(connection.debugDescription), but handshake already completed."
                            )
                        }
                    } else {
                        if let pendingContinuation = self.pending {
                            self.pending = nil
                            pendingContinuation.resume(returning: txt)
                            print("🌀 Resumed pending continuation with: \(txt) for \(connection.debugDescription)")
                        } else {
                            print(
                                "⚠️ Received data '\(txt)' on \(connection.debugDescription) but no pending continuation."
                            )
                        }
                    }
                } else if shouldContinuePumping, isComplete {
                    print("🌀 WS Received complete message but no valid text data on \(connection.debugDescription).")
                }

                // Continue the loop by re-calling pump if no terminal error occurred and connection is still active
                if shouldContinuePumping, self.conn === connection { // Check conn again before re-pumping
                    print("🌀 Re-pumping for \(connection.debugDescription)")
                    self.pump(connection) // Re-call pump to set up the next receive
                } else if shouldContinuePumping, self.conn !== connection {
                    print(
                        "🌀 Not re-pumping for stale connection \(connection.debugDescription). Current is \(self.conn?.debugDescription ?? "nil")"
                    )
                } else {
                    print("🌀 Not re-pumping for \(connection.debugDescription) as shouldContinuePumping is false.")
                }
            }
        }
    }

    private func send(_ txt: String, over c: NWConnection) async throws -> String {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "cmd", metadata: [meta])

        return try await withCheckedThrowingContinuation { continuation in
            self.pending = continuation // Store continuation before sending
            c.send(content: txt.data(using: .utf8),
                   contentContext: ctx,
                   isComplete: true,
                   completion: .contentProcessed { [weak self] (sendError: NWError?) in
                       guard let self else { return }
                       Task { @MainActor in // Ensure operations on self are on MainActor
                           if let sendError {
                               print("🌀 WS Send error: \(sendError.localizedDescription)")
                               // If send fails, resume the stored pending continuation with the error
                               // and clear it to prevent reuse or double resume.
                               if let p = self.pending {
                                   self.pending = nil
                                   p.resume(throwing: sendError)
                               } else {
                                   // This case should ideally not happen if pending was set correctly before send
                                   // and not cleared by another path.
                                   print("⚠️ WS Send error but no pending continuation to resume or already resumed.")
                               }
                               // Optionally, call cleanupConnection if a send error implies the connection is dead
                               // self.cleanupConnection(error: .connectionLost(underlyingError: sendError))
                           } else {
                               print("🌀 WS Sent: \(txt). Waiting for response via pump.")
                               // If send is successful, the pending continuation remains stored.
                               // It will be resumed by the pump() method when a response is received.
                           }
                       }
                   })
        }
    }
}
