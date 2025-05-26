import Foundation
import Network

@MainActor
public final class CursorJSHook {

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
            self?.adopt(c)
        }
        listener.stateUpdateHandler = { [weak self] newState in
            // Optional: handle listener state changes, e.g., if the listener itself fails.
            print("🌀 Listener state updated: \\(newState)")
            if case .failed(let error) = newState {
                // If the listener fails, we might need to abort pending initializations
                if let readyContinuation = self?.ready {
                    self?.ready = nil
                    readyContinuation.resume(throwing: error) // Or a custom error
                }
            }
        }
        listener.start(queue: .main)
        print("🌀  Listening on ws://127.0.0.1:\\(port) for \\(self.applicationName)")
    }

    // 2️⃣ AppleScript UI-drive
    private func injectViaAppleScript() throws {
        let js = \"\"\"
        (function hook(u='ws://127.0.0.1:\\(port)'){\
        const w=new WebSocket(u);w.onopen=()=>w.send('ready');\
        w.onmessage=e=>{let r;try{r=eval(e.data)}catch(x){r=x.stack};\
        w.send(JSON.stringify(r));};})();
        \"\"\"
        let script = #\"\"\"
        tell application "\\#(self.applicationName)"
            activate
            delay 0.1 # Give app time to activate
        end tell
        tell application "System Events"
            tell process "\\#(self.applicationName)"
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

                set the clipboard to "\\#(js)"
                delay 0.1
                keystroke "v" using {command down} # Paste
                delay 0.1
                key code 36 # Press Enter (to execute pasted JS in console)
                delay 0.2

                # Optional: Close Developer Tools or Console Drawer if needed
                # key code 53 -- Esc (again, if it closes the drawer)
            end tell
        end tell
        \"\"\"#
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        if appleScript?.executeAndReturnError(&errorDict) == nil {
            if let error = errorDict {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                print("🍎 AppleScript injection failed: \\(errorMessage) (Code: \\(errorNumber))")
                // Create a custom error or use a generic one
                let nsError = NSError(domain: "AppleScriptError", code: errorNumber, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                throw HookError.injectionFailed(nsError)
            } else {
                print("🍎 AppleScript injection failed with no error info.")
                throw HookError.injectionFailed(nil)
            }
        }
        print("🍏 AppleScript executed for \\(self.applicationName).")
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
            guard let self = self else { return }
            print("🌀 WS Connection state: \\(newState)")
            switch newState {
            case .ready:
                print("🌀 WS Connection is ready. Starting pump.")
                self.pump(c)
            case .failed(let error):
                print("🌀 WS Connection failed: \\(error.localizedDescription)")
                self.cleanupConnection(error: HookError.connectionLost(underlyingError: error))
            case .cancelled:
                print("🌀 WS Connection cancelled.")
                self.cleanupConnection(error: HookError.cancelled)
            default:
                // Other states like .preparing, .waiting are transient
                break
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

    private func pump(_ c: NWConnection) {
        func loop() {
            c.receiveMessage { [weak self] data, context, isComplete, error in
                guard let self = self else { return }

                if let error = error {
                    print("🌀 WS Receive error: \\(error.localizedDescription). Cleaning up connection.")
                    self.cleanupConnection(error: .connectionLost(underlyingError: error))
                    return // Stop pumping
                }

                guard let d = data, !d.isEmpty,
                      let txt = String(data: d, encoding: .utf8) else {
                    if isComplete { // If message is complete but no data/text, could be an issue or just empty message
                        print("🌀 WS Received complete message but no valid text data.")
                    }
                    loop() // Continue listening for more messages
                    return
                }

                print("🌀 WS Received: \\(txt)")
                if txt == "ready" {
                    if !self.handshakeCompleted { // Process "ready" only once
                        self.handshakeCompleted = true
                        self.ready?.resume()
                        self.ready = nil
                        print("🤝 Handshake 'ready' message processed.")
                    } else {
                        print("⚠️ Received 'ready' message again, but handshake already completed.")
                    }
                } else {
                    self.pending?.resume(returning: txt)
                    self.pending = nil
                }
                loop() // Continue listening
            }
        }
        print("🌀 Starting pump loop for connection.")
        loop()
    }

    private func send(_ txt: String, over c: NWConnection) async throws -> String {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx  = NWConnection.ContentContext(identifier: "cmd", metadata: [meta])
        
        // Ensure this is called on the connection's queue if it has one, or main for safety.
        // NWConnection.send is thread-safe, but continuations should be managed carefully.
        try await c.send(content: txt.data(using: .utf8), contentContext: ctx, isComplete: true)
        print("🌀 WS Sent: \\(txt)")
        return try await withCheckedThrowingContinuation { continuation in
            self.pending = continuation
        }
    }
} 