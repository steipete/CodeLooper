import Foundation
import Network

@MainActor
public final class CursorJSHook: @unchecked Sendable {

    public enum HookError: Error {
        case notConnected
        case injectionFailed(Error?)
        case connectionLost(underlyingError: Error)
        case cancelled
        // Consider adding case handshakeTimeout if a timeout mechanism is implemented
    }

    // ──────────────────────────────  public API  ──────────────────────────────
    private let applicationName: String
    private var handshakeCompleted: Bool = false

    /// Returns true if the WebSocket connection is active and the handshake is complete.
    public var isHooked: Bool {
        return conn != nil && conn?.state == .ready && handshakeCompleted
    }

    /// Spin up the hook (starts listener, injects JS, waits for the renderer).
    /// - Parameter applicationName: The name of the application to target (e.g., "Cursor").
    public init(applicationName: String = "Cursor") async throws {
        self.applicationName = applicationName
        try await startListener()
        try injectViaAppleScript() // Changed to synchronous throw
        try await waitForRendererHandshake()
    }

    /// Eval JS inside Cursor and get the JSON-encoded result
    public func runJS(_ source: String) async throws -> String {
        guard let conn = conn, handshakeCompleted else { throw HookError.notConnected }
        return try await send(source, over: conn)
    }

    // ──────────────────────────────  internals  ──────────────────────────────
    private let port: NWEndpoint.Port = 9001
    private var listener: NWListener!
    private var conn: NWConnection?
    private var pending: CheckedContinuation<String, Error>?
    private var ready: CheckedContinuation<Void, Error>?

    // 1️⃣ Web-Socket listener
    private func startListener() async throws {
        let params = NWParameters.tcp
        let wsOpt  = NWProtocolWebSocket.Options()
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
                guard let self = self else { return }
                print("🌀 Listener state updated: \(newState)")
                if case .failed(let error) = newState {
                    if let readyContinuation = self.ready {
                        self.ready = nil
                        readyContinuation.resume(throwing: error)
                    }
                }
            }
        }
        listener.start(queue: .main)
        print("🌀  Listening on ws://127.0.0.1:\(port) for \(self.applicationName)")
    }

    // 2️⃣ AppleScript UI-drive
    private func injectViaAppleScript() throws {
        // JavaScript to be injected. Standard triple quotes are fine.
        let js = """
(function hook(u=\'ws://127.0.0.1:\(port)\'){ \
const w=new WebSocket(u);w.onopen=()=>w.send(\'ready\'); \
w.onmessage=e=>{let r;try{r=eval(e.data)}catch(x){r=x.stack}; \
w.send(JSON.stringify(r));};})();
"""

        // AppleScript content. Raw triple quotes #"""..."""# are used.
        let script = #"""
        tell application "\#(self.applicationName)"
            activate
            delay 0.1 # Give app time to activate
        end tell
        tell application "System Events"
            tell process "\#(self.applicationName)"
                # Ensure the application is ready for UI scripting
                # This might need more robust checks depending on the app's responsiveness
                delay 0.5 # Wait for window to be responsive after activation

                # Open Command Palette
                keystroke "P" using {shift down, command down}
                delay 0.5 # Increased delay for palette to appear

                # Type 'Developer: Toggle Developer Tools'
                # Check if dev tools are already open, if possible, or just toggle
                keystroke "Developer: Toggle Developer Tools"
                delay 0.25
                key code 36 # Press Enter

                delay 1.5 # Increased delay for Developer Tools to open and become active

                # Open Console (often ESC toggles a drawer or focuses console)
                # This part is highly dependent on the specific dev tools UI
                key code 53 -- Esc (hoping it opens/focuses console drawer)
                delay 0.5

                set the clipboard to "\#(js)" 
                delay 0.1
                keystroke "v" using {command down} # Paste
                delay 0.1
                key code 36 # Press Enter (to execute pasted JS in console)
                delay 0.2

                # Optional: Close Developer Tools or Console Drawer if needed
                # key code 53 -- Esc (again, if it closes the drawer)
            end tell
        end tell
        """# // End of AppleScript raw string literal
        
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        if appleScript?.executeAndReturnError(&errorDict) == nil {
            if let error = errorDict {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                print("🍎 AppleScript injection failed: \(errorMessage) (Code: \(errorNumber))")
                // Create a custom error or use a generic one
                let nsError = NSError(domain: "AppleScriptError", code: errorNumber, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                throw HookError.injectionFailed(nsError)
            } else {
                print("🍎 AppleScript injection failed with no error info.")
                throw HookError.injectionFailed(nil)
            }
        }
        print("🍏 AppleScript executed for \(self.applicationName).")
    }


    // 3️⃣ Wait for renderer's "ready"
    private func waitForRendererHandshake() async throws {
        print("⏳ Waiting for renderer handshake...")
        try await withCheckedThrowingContinuation { continuation in
            self.ready = continuation
        }
        print("🤝 Renderer handshake complete.")
    }

    // adopt a new WS connection
    private func adopt(_ c: NWConnection) {
        self.conn = c
        self.handshakeCompleted = false // Reset on new connection attempt
        print("🌀 WS Connection adopted. Waiting for state updates.")

        c.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self = self else { return }
                print("🌀 WS Connection state: \(newState)")
                switch newState {
                case .ready:
                    print("🌀 WS Connection is ready. Starting pump.")
                    self.pump(c)
                case .failed(let error):
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
        if let readyContinuation = self.ready {
            self.ready = nil
            readyContinuation.resume(throwing: error)
        }
        if let pendingContinuation = self.pending {
            self.pending = nil
            pendingContinuation.resume(throwing: error)
        }
        // Optional: Notify listener or attempt to re-establish if appropriate for the use case
    }

    // pump is already @MainActor isolated
    private func pump(_ c: NWConnection) {
        print("🌀 Setting up receiveMessage on connection \(c.debugDescription)")
        c.receiveMessage { [weak self] data, context, isComplete, error in
            // This closure is @Sendable. We must dispatch to MainActor to interact with self 
            Task { @MainActor in
                guard let self = self else { 
                    print("泵 CursorJSHook self is nil, cannot process message.")
                    return
                }
                // Ensure the connection being processed is still the active one.
                guard self.conn === c else {
                    print("泵 Stale connection \(c.debugDescription), current is \(self.conn?.debugDescription ?? "nil"). Ignoring message.")
                    return
                }

                var shouldContinuePumping = true

                if let error = error {
                    print("🌀 WS Receive error on \(c.debugDescription): \(error.localizedDescription). Cleaning up connection.")
                    self.cleanupConnection(error: .connectionLost(underlyingError: error))
                    shouldContinuePumping = false // Stop pumping on error
                }

                if shouldContinuePumping, let d = data, !d.isEmpty,
                   let txt = String(data: d, encoding: .utf8) {
                    print("🌀 WS Received on \(c.debugDescription): \(txt)")
                    if txt == "ready" {
                        if !self.handshakeCompleted { 
                            self.handshakeCompleted = true
                            self.ready?.resume()
                            self.ready = nil
                            print("🤝 Handshake 'ready' message processed for \(c.debugDescription).")
                        } else {
                            print("⚠️ Received 'ready' message again on \(c.debugDescription), but handshake already completed.")
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
                } else if shouldContinuePumping && isComplete {
                    print("🌀 WS Received complete message but no valid text data on \(c.debugDescription).")
                }
                
                // Continue the loop by re-calling pump if no terminal error occurred and connection is still active
                if shouldContinuePumping && self.conn === c { // Check conn again before re-pumping
                    print("🌀 Re-pumping for \(c.debugDescription)")
                    self.pump(c) // Re-call pump to set up the next receive
                } else if shouldContinuePumping && self.conn !== c {
                     print("🌀 Not re-pumping for stale connection \(c.debugDescription). Current is \(self.conn?.debugDescription ?? "nil")")
                } else {
                    print("🌀 Not re-pumping for \(c.debugDescription) as shouldContinuePumping is false.")
                }
            }
        }
    }

    private func send(_ txt: String, over c: NWConnection) async throws -> String {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx  = NWConnection.ContentContext(identifier: "cmd", metadata: [meta])
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pending = continuation // Store continuation before sending
            c.send(content: txt.data(using: .utf8), 
                   contentContext: ctx, 
                   isComplete: true, 
                   completion: .contentProcessed { [weak self] (sendError: NWError?) in
                guard let self = self else { return }
                Task { @MainActor in // Ensure operations on self are on MainActor
                    if let sendError = sendError {
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