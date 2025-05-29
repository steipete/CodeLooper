import AppKit
import Defaults
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

            // Check if automatic injection is enabled
            if Defaults[.automaticJSHookInjection] {
                logger.info("💉 Automatically injecting JavaScript hook...")
                try injector.inject()

                logger.info("⏳ Waiting for JavaScript to start WebSocket client...")
                // Give the browser time to parse and execute the injected JavaScript
                try await Task.sleep(for: .seconds(2))

                logger.info("🤝 Waiting for handshake from browser...")
                try await webSocketManager.waitForHandshake()
            } else {
                logger.info("📋 Manual injection mode - preparing script...")

                // Generate the JavaScript hook script
                let js = try CursorJSHookScript.generate(port: port)

                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(js, forType: .string)

                // Show alert with instructions FIRST
                await showManualInjectionAlert(port: port, targetWindow: targetWindowTitle)

                // THEN prepare the window and console after user clicks OK
                try prepareWindowAndConsole()

                logger.info("🤝 Waiting for manual injection and handshake from browser...")
                try await webSocketManager.waitForHandshake()
            }
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

    private func prepareWindowAndConsole() throws {
        let logger = Logger(category: .jshook)
        logger.info("🎯 Preparing Cursor window and console for manual injection")

        // Build AppleScript to activate window and open console
        let windowTarget = if let targetTitle = targetWindowTitle {
            "(first window whose name is \"\(targetTitle)\")"
        } else {
            "front window"
        }

        let isConsoleOpen = JSHookDevConsoleDetector.isDevConsoleOpen(
            in: applicationName,
            targetWindowTitle: targetWindowTitle
        )
        logger.debug("🔍 Dev console already open: \(isConsoleOpen)")

        let devToolsToggleScript = if !isConsoleOpen {
            """
                # Use menu bar to open developer tools
                # Access Help menu and click Toggle Developer Tools
                click menu item "Toggle Developer Tools" of menu 1 of menu bar item "Help" of menu bar 1
                delay 3.0
            """
        } else {
            """
                # Dev console already open, skipping toggle
                delay 0.5
            """
        }

        let script = """
        tell application "\(applicationName)"
            activate
            delay 0.5
        end tell

        tell application "System Events"
            tell process "\(applicationName)"
                # Target specific window by name if provided, otherwise use front window
                set targetWindow to \(windowTarget)

                # Focus the window
                set frontmost to true
                set focused of targetWindow to true
                delay 0.5

                \(devToolsToggleScript)

                # Focus on the console tab (if not already selected)
                # Use escape key to ensure we're in the console
                key code 53 # Escape
                delay 0.2

                # Clear any existing content in console
                keystroke "l" using {command down} # Cmd+L clears console
                delay 0.5
            end tell
        end tell
        """

        logger.info("🚀 Executing window preparation AppleScript...")

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)

        if result == nil || errorDict != nil {
            if let error = errorDict {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                logger.error("🍎 Window preparation failed: \(errorMessage) (Code: \(errorNumber))")

                // Don't throw - continue anyway as user can manually prepare
                logger.info("⚠️ Continuing despite preparation error - user can manually prepare window")
            }
        } else {
            logger.info("✅ Window and console prepared successfully")
        }
    }

    private func showManualInjectionAlert(port: UInt16, targetWindow: String?) async {
        let logger = Logger(category: .jshook)
        logger.info("📢 Showing manual injection alert")

        let alert = NSAlert()
        alert.messageText = "Ready to Connect CodeLooper"
        alert.informativeText = """
        The Cursor window and Developer Console have been prepared for you.
        The JavaScript hook is in your clipboard.

        Simply paste (⌘V) and press Enter in the console to connect.

        Connection Details:
        • Window: \(targetWindow ?? "Front Window")
        • Port: \(port)
        • Status: Waiting for connection...

        Once connected, you'll see the status update in CodeLooper.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK, I'll paste it")
        alert.icon = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Clipboard Ready")

        // Run modal on main thread
        await MainActor.run {
            _ = alert.runModal()
        }

        logger.info("✅ User acknowledged manual injection instructions")
    }
}
