import Foundation
import Network

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

    // swiftlint:disable:next function_body_length
    private func generateJavaScriptHook() -> String {
        """
        (function() {
            // Check if hook already exists and clean it up
            if (window.__codeLooperHook) {
                console.log('🔄 CodeLooper: Cleaning up existing hook on port ' + window.__codeLooperPort);
                try {
                    if (window.__codeLooperHook.readyState === WebSocket.OPEN || 
                        window.__codeLooperHook.readyState === WebSocket.CONNECTING) {
                        window.__codeLooperHook.close();
                    }
                } catch (e) {
                    console.log('🔄 CodeLooper: Error closing existing connection:', e);
                }
                window.__codeLooperHook = null;
                window.__codeLooperPort = null;
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
                        
                        // Show success notification
                        try {
                            // Create a toast notification in Cursor's UI
                            const notification = document.createElement('div');
                            notification.innerHTML = '✅ CodeLooper connected successfully!';
                            notification.style.cssText = 'position: fixed; top: 20px; right: 20px; background: #10b981; color: white; padding: 12px 24px; border-radius: 8px; font-weight: 500; z-index: 999999; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); animation: slideIn 0.3s ease-out; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px;';
                            
                            // Add animation
                            const style = document.createElement('style');
                            style.textContent = '@keyframes slideIn { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }';
                            document.head.appendChild(style);
                            
                            document.body.appendChild(notification);
                            
                            // Remove notification after 5 seconds
                            setTimeout(() => {
                                notification.style.opacity = '0';
                                notification.style.transform = 'translateX(100%)';
                                notification.style.transition = 'all 0.3s ease-out';
                                setTimeout(() => notification.remove(), 300);
                            }, 5000);
                            
                            // Also show in console
                            console.log('%c✅ CodeLooper Hook Active!', 'color: #10b981; font-size: 16px; font-weight: bold;');
                            console.log('Port:', port);
                            console.log('Ready to receive commands');
                            
                        } catch (e) {
                            console.error('Failed to show notification:', e);
                        }
                    };

                    ws.onerror = (e) => {
                        console.log('🔄 CodeLooper: WebSocket error', e);
                    };

                    ws.onclose = (e) => {
                        console.log('🔄 CodeLooper: WebSocket closed', e);
                        window.__codeLooperHook = null;
                        window.__codeLooperPort = null;

                        // Auto-reconnect logic
                        if (reconnectAttempts < maxReconnectAttempts) {
                            reconnectAttempts++;
                            console.log(`🔄 CodeLooper: Reconnecting in ${reconnectDelay/1000}s... ` +
                                `(attempt ${reconnectAttempts}/${maxReconnectAttempts})`);
                            setTimeout(connect, reconnectDelay);
                        } else {
                            console.log('🔄 CodeLooper: Max reconnection attempts reached. Hook disabled.');
                        }
                    };

                    ws.onmessage = async (e) => {
                        let result;
                        try {
                            // Parse message as a command instead of evaluating code
                            const command = JSON.parse(e.data);
                            
                            switch(command.type) {
                                case 'getSystemInfo':
                                    result = {
                                        userAgent: navigator.userAgent,
                                        platform: navigator.platform,
                                        language: navigator.language,
                                        onLine: navigator.onLine,
                                        cookieEnabled: navigator.cookieEnabled,
                                        windowLocation: window.location.href,
                                        timestamp: new Date().toISOString()
                                    };
                                    break;
                                    
                                case 'querySelector':
                                    const element = document.querySelector(command.selector);
                                    result = element ? {
                                        found: true,
                                        tagName: element.tagName,
                                        id: element.id,
                                        className: element.className,
                                        text: element.textContent?.substring(0, 100)
                                    } : { found: false };
                                    break;
                                    
                                case 'getElementInfo':
                                    const el = document.querySelector(command.selector);
                                    if (el) {
                                        const rect = el.getBoundingClientRect();
                                        result = {
                                            found: true,
                                            position: { x: rect.x, y: rect.y },
                                            size: { width: rect.width, height: rect.height },
                                            visible: rect.width > 0 && rect.height > 0,
                                            text: el.textContent?.substring(0, 200)
                                        };
                                    } else {
                                        result = { found: false };
                                    }
                                    break;
                                    
                                case 'clickElement':
                                    const target = document.querySelector(command.selector);
                                    if (target && target instanceof HTMLElement) {
                                        target.click();
                                        result = { success: true, clicked: command.selector };
                                    } else {
                                        result = { success: false, error: 'Element not found or not clickable' };
                                    }
                                    break;
                                    
                                case 'getActiveElement':
                                    const active = document.activeElement;
                                    result = {
                                        tagName: active?.tagName,
                                        id: active?.id,
                                        className: active?.className,
                                        value: active?.value || active?.textContent
                                    };
                                    break;
                                    
                                case 'showNotification':
                                    // Display a notification in the console with custom styling
                                    const message = command.message || 'Hello from CodeLooper!';
                                    const style = command.style || 'background: linear-gradient(45deg, #667eea 0%, #764ba2 100%); color: white; font-size: 14px; padding: 20px; border-radius: 8px; font-weight: bold;';
                                    console.log('%c' + message, style);
                                    
                                    // Try to show a browser notification if permissions allow
                                    if (command.browserNotification && typeof Notification !== 'undefined' && Notification.permission === 'granted') {
                                        new Notification(command.title || 'CodeLooper', {
                                            body: message,
                                            icon: command.icon || 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="%23667eea" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 12a4 4 0 0 0 8 0"/></svg>'
                                        });
                                    }
                                    
                                    // Create a temporary DOM element for visual feedback
                                    if (command.showToast) {
                                        const toast = document.createElement('div');
                                        toast.textContent = message;
                                        toast.style.cssText = 'position: fixed; top: 20px; right: 20px; background: linear-gradient(45deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px 24px; border-radius: 8px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px; font-weight: 500; box-shadow: 0 4px 12px rgba(0,0,0,0.15); z-index: 999999; animation: slideIn 0.3s ease-out;';
                                        
                                        // Add animation
                                        const styleEl = document.createElement('style');
                                        styleEl.textContent = '@keyframes slideIn { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }';
                                        document.head.appendChild(styleEl);
                                        
                                        document.body.appendChild(toast);
                                        
                                        // Remove after delay
                                        setTimeout(() => {
                                            toast.style.animation = 'slideOut 0.3s ease-in forwards';
                                            toast.style.animationName = 'slideOut';
                                            setTimeout(() => {
                                                toast.remove();
                                                styleEl.remove();
                                            }, 300);
                                        }, command.duration || 3000);
                                        
                                        // Add slide out animation
                                        styleEl.textContent += ' @keyframes slideOut { from { transform: translateX(0); opacity: 1; } to { transform: translateX(100%); opacity: 0; } }';
                                    }
                                    
                                    result = { success: true, message: 'Notification shown' };
                                    break;
                                    
                                case 'rawCode':
                                    // Fallback for backward compatibility - will fail with Trusted Types
                                    result = {
                                        error: 'Trusted Types policy prevents eval. Use predefined commands instead.',
                                        suggestion: 'Available commands: getSystemInfo, querySelector, getElementInfo, clickElement, getActiveElement, showNotification'
                                    };
                                    break;
                                    
                                default:
                                    result = {
                                        error: 'Unknown command type',
                                        type: command.type,
                                        availableCommands: ['getSystemInfo', 'querySelector', 'getElementInfo', 'clickElement', 'getActiveElement', 'showNotification']
                                    };
                            }
                        } catch (e) {
                            // Fallback for non-JSON messages (backward compatibility)
                            result = {
                                error: 'Invalid command format. Expected JSON with type field.',
                                received: e.data,
                                actualError: e.message,
                                suggestion: 'Send commands as JSON: {"type": "getSystemInfo"}'
                            };
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
