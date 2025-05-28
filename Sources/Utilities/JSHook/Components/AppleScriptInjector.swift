import Foundation
import AppKit
import Diagnostics

@MainActor
final class AppleScriptInjector {
    private let applicationName: String
    private let targetWindowTitle: String?
    private let port: UInt16
    
    init(applicationName: String, targetWindowTitle: String?, port: UInt16) {
        self.applicationName = applicationName
        self.targetWindowTitle = targetWindowTitle
        self.port = port
    }
    
    func inject() throws {
        Logger(category: .jshook).info("🎯 Starting AppleScript injection for \(applicationName)")
        
        let isConsoleOpen = JSHookDevConsoleDetector.isDevConsoleOpen(in: applicationName)
        Logger(category: .jshook).debug("🔍 Dev console already open: \(isConsoleOpen)")
        
        let js = try CursorJSHookScript.generate(port: port)
        let script = buildAppleScript(javascript: js, skipDevToolsToggle: isConsoleOpen)
        
        try executeAppleScript(script)
    }
    
    private func buildAppleScript(javascript js: String, skipDevToolsToggle: Bool) -> String {
        let windowTarget = targetWindowTitle != nil ? "window \"\(targetWindowTitle!)\"" : "front window"
        
        let devToolsToggleScript = if !skipDevToolsToggle {
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
        
        return """
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
                
                Logger(category: .jshook)
                    .error("🍎 AppleScript injection failed: \(errorMessage) (Code: \(errorNumber))")
                
                // Check for specific error codes
                switch errorNumber {
                case -1743:
                    Logger(category: .jshook).error("⚠️ User denied automation permission")
                case -600:
                    Logger(category: .jshook).error("⚠️ Application not running or not found")
                case -10004:
                    Logger(category: .jshook).error("⚠️ A privilege violation occurred")
                default:
                    break
                }
                
                let nsError = NSError(
                    domain: "AppleScriptError",
                    code: errorNumber,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                throw CursorJSHook.HookError.injectionFailed(nsError)
            } else {
                throw CursorJSHook.HookError.injectionFailed(nil)
            }
        }
        
        Logger(category: .jshook).info("🍏 AppleScript executed successfully for \(applicationName).")
    }
}

// MARK: - String Extension

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