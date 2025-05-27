import Foundation
import Network
import Diagnostics

extension String {
    /// Converts a String to a properly escaped AppleScript string literal
    var appleScriptLiteral: String {
        // Escape backslashes first, then quotes, then newlines
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

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

    deinit {
        // Clean up listener and connection
        listener?.cancel()
        conn?.cancel()
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

    /// Send a command to the JS hook and get the JSON-encoded result
    /// - Parameter command: A dictionary representing the command to send
    /// - Returns: The JSON-encoded result from the browser
    public func sendCommand(_ command: [String: Any]) async throws -> String {
        guard let conn, handshakeCompleted else { throw HookError.notConnected }
        let jsonData = try JSONSerialization.data(withJSONObject: command)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return try await send(jsonString, over: conn)
    }
    
    /// Legacy method - attempts to run raw JS code (will fail with Trusted Types)
    @available(*, deprecated, message: "Use sendCommand or specific helper methods instead")
    public func runJS(_ source: String) async throws -> String {
        let command = ["type": "rawCode", "code": source]
        return try await sendCommand(command)
    }
    
    // MARK: - Command Helpers
    
    /// Get system information from the browser
    public func getSystemInfo() async throws -> String {
        try await sendCommand(["type": "getSystemInfo"])
    }
    
    /// Query for an element using a CSS selector
    public func querySelector(_ selector: String) async throws -> String {
        try await sendCommand(["type": "querySelector", "selector": selector])
    }
    
    /// Get detailed information about an element
    public func getElementInfo(_ selector: String) async throws -> String {
        try await sendCommand(["type": "getElementInfo", "selector": selector])
    }
    
    /// Click an element
    public func clickElement(_ selector: String) async throws -> String {
        try await sendCommand(["type": "clickElement", "selector": selector])
    }
    
    /// Get information about the currently focused element
    public func getActiveElement() async throws -> String {
        try await sendCommand(["type": "getActiveElement"])
    }
    
    /// Show a notification in Cursor
    /// - Parameters:
    ///   - message: The message to display
    ///   - showToast: If true, shows a toast notification in the DOM
    ///   - duration: How long to show the toast (in milliseconds)
    ///   - browserNotification: If true, attempts to show a browser notification
    ///   - title: Title for browser notification
    public func showNotification(
        _ message: String,
        showToast: Bool = true,
        duration: Int = 3000,
        browserNotification: Bool = false,
        title: String? = nil
    ) async throws -> String {
        var command: [String: Any] = [
            "type": "showNotification",
            "message": message,
            "showToast": showToast,
            "duration": duration,
            "browserNotification": browserNotification
        ]
        
        if let title = title {
            command["title"] = title
        }
        
        return try await sendCommand(command)
    }
    
    /// Check if the "resume conversation" link is visible (indicating Cursor has stopped)
    /// - Returns: JSON response with resumeNeeded boolean
    public func checkResumeNeeded() async throws -> String {
        try await sendCommand(["type": "checkResumeNeeded"])
    }
    
    /// Click the "resume conversation" link if it's available
    /// - Returns: JSON response with success boolean
    public func clickResume() async throws -> String {
        try await sendCommand(["type": "clickResume"])
    }
    
    /// Check if resume is needed and return as a boolean
    /// - Returns: True if resume link is found
    public func isResumeNeeded() async throws -> Bool {
        let result = try await checkResumeNeeded()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resumeNeeded = json["resumeNeeded"] as? Bool else {
            return false
        }
        return resumeNeeded
    }
    
    /// Attempt to resume Cursor if needed
    /// - Returns: True if resume was clicked successfully
    public func attemptResume() async throws -> Bool {
        let result = try await clickResume()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else {
            return false
        }
        return success
    }
    
    // MARK: - Composer Bar Observation
    
    /// Start observing the composer bar for changes
    /// - Returns: JSON response with success status
    public func startComposerObserver() async throws -> String {
        try await sendCommand(["type": "startComposerObserver"])
    }
    
    /// Stop observing the composer bar
    /// - Returns: JSON response with success status
    public func stopComposerObserver() async throws -> String {
        try await sendCommand(["type": "stopComposerObserver"])
    }
    
    /// Get the current content of the composer bar
    /// - Returns: JSON response with content
    public func getComposerContent() async throws -> String {
        try await sendCommand(["type": "getComposerContent"])
    }
    
    /// Start observing composer bar and return success status
    /// - Returns: True if observer started successfully
    public func startObservingComposer() async throws -> Bool {
        let result = try await startComposerObserver()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else {
            return false
        }
        return success
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

        let js = try generateJavaScriptHook()
        let script = buildAppleScript(javascript: js)

        try executeAppleScript(script)
    }

    private func generateJavaScriptHook() throws -> String {
        do {
            return try CursorJSHookScript.generate(port: port.rawValue)
        } catch {
            Logger(category: .settings).error("Failed to load JavaScript hook script: \(error)")
            throw HookError.injectionFailed(error)
        }
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

                # Use menu bar to open developer tools
                # Access Help menu and click Toggle Developer Tools
                click menu item "Toggle Developer Tools" of menu 1 of menu bar item "Help" of menu bar 1
                delay 3.0
                
                # Focus on the console tab (if not already selected)
                # Click in the console input area at the bottom
                # Use escape key to ensure we're in the console
                key code 53 # Escape
                delay 0.2
                
                # Clear any existing content in console
                keystroke "l" using {command down} # Cmd+L clears console
                delay 0.5
                
                # Now type/paste the JavaScript
                set the clipboard to \(js.appleScriptLiteral)
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

                self.handleReceivedMessage(
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
        // Ensure the connection being processed is still the active one.
        guard self.conn === connection else {
            print(
                """
                泵 Stale connection \(connection.debugDescription), current is \
                \(self.conn?.debugDescription ?? "nil"). Ignoring message.
                """
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
            processReceivedText(txt, on: connection)
        } else if shouldContinuePumping, isComplete {
            print("🌀 WS Received complete message but no valid text data on \(connection.debugDescription).")
        }

        // Continue the loop by re-calling pump if no terminal error occurred and connection is still active
        if shouldContinuePumping, self.conn === connection { // Check conn again before re-pumping
            print("🌀 Re-pumping for \(connection.debugDescription)")
            self.pump(connection) // Re-call pump to set up the next receive
        } else if shouldContinuePumping, self.conn !== connection {
            print(
                """
                🌀 Not re-pumping for stale connection \(connection.debugDescription). \
                Current is \(self.conn?.debugDescription ?? "nil")
                """
            )
        } else {
            print("🌀 Not re-pumping for \(connection.debugDescription) as shouldContinuePumping is false.")
        }
    }

    private func processReceivedText(_ txt: String, on connection: NWConnection) {
        // Try to parse as JSON first
        if let data = txt.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            
            switch type {
            case "heartbeat":
                // Process heartbeat
                let version = json["version"] as? String ?? "unknown"
                let location = json["location"] as? String ?? "unknown"
                let resumeNeeded = json["resumeNeeded"] as? Bool ?? false
                
                if resumeNeeded {
                    Logger(category: .jshook)
                        .info("⏸️ Cursor stopped - resume needed (hook v\(version))")
                } else {
                    Logger(category: .jshook)
                        .debug("💓 Heartbeat from Cursor hook v\(version) at \(location)")
                }
                
                // Always post heartbeat notification
                NotificationCenter.default.post(
                    name: Notification.Name("CursorHeartbeat"),
                    object: nil,
                    userInfo: [
                        "port": self.port.rawValue,
                        "location": location,
                        "version": version,
                        "resumeNeeded": resumeNeeded
                    ]
                )
                return
                
            case "composerUpdate":
                // Process composer bar update
                let content = json["content"] as? String ?? ""
                let timestamp = json["timestamp"] as? String ?? ""
                let isInitial = json["initial"] as? Bool ?? false
                let mutations = json["mutations"] as? Int ?? 0
                
                if isInitial {
                    Logger(category: .jshook)
                        .info("📝 Initial composer bar content received (length: \(content.count))")
                } else {
                    Logger(category: .jshook)
                        .info("📝 Composer bar updated: \(mutations) mutations, length: \(content.count)")
                }
                
                // Log the actual content (truncated if too long)
                let truncatedContent = content.count > 500 ? 
                    String(content.prefix(500)) + "..." : content
                Logger(category: .jshook)
                    .debug("📝 Composer content: \(truncatedContent)")
                
                // Post notification for other parts of the app
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
                return
                
            default:
                // Unknown message type, fall through to normal processing
                Logger(category: .jshook)
                    .warning("⚠️ Received unknown message type '\(type)' from JS hook: \(txt)")
                break
            }
        }
        
        print("🌀 WS Received on \(connection.debugDescription): \(txt)")
        if txt == "ready" {
            if !self.handshakeCompleted {
                self.handshakeCompleted = true
                print("🤝 Handshake 'ready' message processed for \(connection.debugDescription).")
                Logger(category: .jshook)
                    .info("🤝 Renderer handshake complete. Hook version: \(CursorJSHookScript.version)")
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
