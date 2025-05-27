import Foundation
import Network

@MainActor
public final class CursorJSHook: Sendable {
    // MARK: Lifecycle

    /// Spin up the hook (starts listener, injects JS, waits for the renderer).
    /// - Parameters:
    ///   - applicationName: The name of the application to target (e.g., "Cursor").
    ///   - port: The port to use for WebSocket connection (default: 9001)
    ///   - skipInjection: If true, only starts listener without injecting (for probing)
    public init(applicationName: String = "Cursor", port: UInt16 = 9001, skipInjection: Bool = false) async throws {
        self.applicationName = applicationName
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

        listener = try NWListener(using: params, on: port)
        listener.newConnectionHandler = { [weak self] c in
            print("🌀 Listener received new connection attempt.")
            Task { @MainActor in
                self?.adopt(c)
            }
        }
        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                print("🌀 Listener state updated: \(newState)")
                if case let .failed(error) = newState {
                    // Handle listener failure - connection cleanup will be handled elsewhere
                    print("🌀 Listener failed: \(error)")
                }
            }
        }
        listener.start(queue: .main)
        print("🌀  Listening on ws://127.0.0.1:\(port) for \(self.applicationName)")
    }

    // 2️⃣ AppleScript UI-drive
    private func injectViaAppleScript() throws {
        print("🎯 Starting AppleScript injection for \(self.applicationName)")
        
        // JavaScript to be injected with debugging. Standard triple quotes are fine.
        let js = """
        (function hook(u=\'ws://127.0.0.1:\(port)\'){ \
        console.log(\'🎯 CodeLooper: Attempting to connect to \' + u); \
        try { \
        const w=new WebSocket(u); \
        w.onopen=()=>{console.log(\'🎯 CodeLooper: Connected to \' + u);w.send(\'ready\');}; \
        w.onerror=(e)=>console.log(\'🎯 CodeLooper: WebSocket error\', e); \
        w.onclose=(e)=>console.log(\'🎯 CodeLooper: WebSocket closed\', e); \
        w.onmessage=e=>{let r;try{r=eval(e.data)}catch(x){r=x.stack}; \
        w.send(JSON.stringify(r));}; \
        return \'CodeLooper hook installing on port \(port)...\'; \
        } catch(err) { \
        console.error(\'🎯 CodeLooper: Failed to create WebSocket\', err); \
        return \'CodeLooper hook failed: \' + err.message; \
        } \
        })();
        """

        // AppleScript content. Raw triple quotes #"""..."""# are used.
        let script = #"""
        tell application "\#(self.applicationName)"
            activate
            delay 0.5 # Increased delay to ensure app is fully activated
        end tell
        tell application "System Events"
            tell process "\#(self.applicationName)"
                # Ensure the application is ready for UI scripting
                delay 0.5 # Wait for window to be responsive after activation

                # Open Command Palette
                keystroke "P" using {shift down, command down}
                delay 1.0 # Wait for palette to appear

                # Clear any existing text and type the full specific command with > prefix
                keystroke "a" using {command down} # Select all existing text
                delay 0.1
                keystroke ">Developer: Toggle Developer Tools" # Full explicit command with > prefix
                delay 0.5 # Wait for search results
                key code 36 # Press Enter to select the command

                delay 2.5 # Wait for Developer Tools to open/become active

                # Now try to focus the console with multiple strategies
                
                # Strategy 1: Try Cmd+Shift+C to open Console directly
                keystroke "c" using {command down, shift down}
                delay 1.5
                
                # Strategy 2: Try pressing Escape to focus console input
                key code 53 -- Esc
                delay 0.5
                
                # Strategy 3: Try Tab to navigate to input field
                key code 48 -- Tab
                delay 0.5
                
                # Strategy 4: Try clicking at bottom of window where console input usually is
                try
                    set windowBounds to bounds of front window
                    set windowWidth to (item 3 of windowBounds) - (item 1 of windowBounds)
                    set windowHeight to (item 4 of windowBounds) - (item 2 of windowBounds)
                    set clickX to (item 1 of windowBounds) + (windowWidth / 2)
                    set clickY to (item 2 of windowBounds) + (windowHeight - 50) # Near bottom
                    click at {clickX, clickY}
                    delay 0.5
                end try
                
                # Clear any existing content in console input
                keystroke "a" using {command down}
                delay 0.2
                key code 117 # Delete key
                delay 0.2

                # Set clipboard and paste our JavaScript
                set the clipboard to "\#(js)" 
                delay 0.3
                keystroke "v" using {command down} # Paste
                delay 1.0 # Wait longer for paste to complete
                
                # Execute the JavaScript - try multiple times to ensure it works
                key code 36 # Press Enter (to execute pasted JS in console)
                delay 0.5
                key code 36 # Press Enter again to be sure
                delay 1.5 # Wait longer for execution

            end tell
        end tell
        """# // End of AppleScript raw string literal

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
                    print("⚠️  User denied automation permission. Please grant permission in System Settings > Privacy & Security > Automation")
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
    private func adopt(_ c: NWConnection) {
        self.conn = c
        self.handshakeCompleted = false // Reset on new connection attempt
        print("🌀 WS Connection adopted. Waiting for state updates.")

        c.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                print("🌀 WS Connection state: \(newState)")
                switch newState {
                case .ready:
                    print("🌀 WS Connection is ready. Starting pump.")
                    self.pump(c)
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
        c.start(queue: .main)
    }

    private func cleanupConnection(error: HookError) {
        conn = nil
        handshakeCompleted = false
        if let pendingContinuation = self.pending {
            self.pending = nil
            pendingContinuation.resume(throwing: error)
        }
        // Optional: Notify listener or attempt to re-establish if appropriate for the use case
    }

    // pump is already @MainActor isolated
    private func pump(_ c: NWConnection) {
        print("🌀 Setting up receiveMessage on connection \(c.debugDescription)")
        c.receiveMessage { [weak self] data, _, isComplete, error in
            // This closure is @Sendable. We must dispatch to MainActor to interact with self
            Task { @MainActor in
                guard let self else {
                    print("泵 CursorJSHook self is nil, cannot process message.")
                    return
                }
                // Ensure the connection being processed is still the active one.
                guard self.conn === c else {
                    print(
                        "泵 Stale connection \(c.debugDescription), current is \(self.conn?.debugDescription ?? "nil"). Ignoring message."
                    )
                    return
                }

                var shouldContinuePumping = true

                if let error {
                    print(
                        "🌀 WS Receive error on \(c.debugDescription): \(error.localizedDescription). Cleaning up connection."
                    )
                    self.cleanupConnection(error: .connectionLost(underlyingError: error))
                    shouldContinuePumping = false // Stop pumping on error
                }

                if shouldContinuePumping, let d = data, !d.isEmpty,
                   let txt = String(data: d, encoding: .utf8)
                {
                    print("🌀 WS Received on \(c.debugDescription): \(txt)")
                    if txt == "ready" {
                        if !self.handshakeCompleted {
                            self.handshakeCompleted = true
                            print("🤝 Handshake 'ready' message processed for \(c.debugDescription).")
                        } else {
                            print(
                                "⚠️ Received 'ready' message again on \(c.debugDescription), but handshake already completed."
                            )
                        }
                    } else {
                        if let p = self.pending {
                            self.pending = nil
                            p.resume(returning: txt)
                            print("🌀 Resumed pending continuation with: \(txt) for \(c.debugDescription)")
                        } else {
                            print("⚠️ Received data '\(txt)' on \(c.debugDescription) but no pending continuation.")
                        }
                    }
                } else if shouldContinuePumping, isComplete {
                    print("🌀 WS Received complete message but no valid text data on \(c.debugDescription).")
                }

                // Continue the loop by re-calling pump if no terminal error occurred and connection is still active
                if shouldContinuePumping, self.conn === c { // Check conn again before re-pumping
                    print("🌀 Re-pumping for \(c.debugDescription)")
                    self.pump(c) // Re-call pump to set up the next receive
                } else if shouldContinuePumping, self.conn !== c {
                    print(
                        "🌀 Not re-pumping for stale connection \(c.debugDescription). Current is \(self.conn?.debugDescription ?? "nil")"
                    )
                } else {
                    print("🌀 Not re-pumping for \(c.debugDescription) as shouldContinuePumping is false.")
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
