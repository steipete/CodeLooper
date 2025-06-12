import Foundation
import AppKit
import AXorcist
import Diagnostics

/// Shared service for mapping TTY devices to terminal windows
/// 
/// This service provides consistent TTY-to-window resolution that is used by:
/// - ClaudeTerminalTitleManager: To update terminal window titles based on Claude instance state
/// - ClaudeInstancesList: To raise/focus the correct terminal window when clicking on an instance
///
/// The service uses lsof to determine which processes have a TTY device open,
/// then matches those processes to terminal applications and their windows.
/// This ensures that both title updates and window raising use the same logic
/// for finding the correct terminal window.
@MainActor
final class TTYWindowMappingService: Loggable {
    
    // MARK: - Singleton
    
    static let shared = TTYWindowMappingService()
    
    private let iTermHelper = ITermAppleScriptHelper()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Find the terminal window that owns the given TTY device
    /// - Parameter ttyPath: The TTY device path (e.g., "/dev/ttys003")
    /// - Returns: The Element representing the window, or nil if not found
    func findWindowForTTY(_ ttyPath: String) -> Element? {
        logger.debug("Looking for window that owns TTY: \(ttyPath)")
        
        // Get the TTY device name (e.g., "ttys003" from "/dev/ttys003")
        let ttyName = URL(fileURLWithPath: ttyPath).lastPathComponent
        
        // Use lsof to find processes that have this TTY open
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-t", ttyPath]  // -t for terse output (PIDs only)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                logger.debug("No output from lsof for TTY \(ttyPath)")
                return nil
            }
            
            // Parse PIDs from output
            let pids = output.components(separatedBy: .newlines)
                .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            
            logger.debug("Found \(pids.count) processes using TTY \(ttyPath): \(pids)")
            
            // Check each PID to see if it's a terminal application
            for pid in pids {
                if let app = NSRunningApplication(processIdentifier: pid) {
                    logger.debug("Process \(pid) is app: \(app.bundleIdentifier ?? "unknown")")
                    
                    // Check if this is a known terminal app
                    if isTerminalApp(app) {
                        // Find the window in this terminal app that owns our TTY
                        if let window = findWindowInApp(app, forTTY: ttyName) {
                            return window
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to run lsof: \(error)")
        }
        
        return nil
    }
    
    /// Find all terminal windows and their associated TTYs
    /// - Returns: Dictionary mapping TTY paths to window Elements
    func getAllTerminalWindowTTYMappings() -> [String: Element] {
        var mappings: [String: Element] = [:]
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps where isTerminalApp(app) {
            guard let appElement = Element.application(for: app.processIdentifier) else {
                logger.warning("Could not get application element for \(app.bundleIdentifier ?? "unknown")")
                continue
            }
            
            guard let windows = appElement.windows() else {
                logger.debug("No windows found for \(app.bundleIdentifier ?? "unknown")")
                continue
            }
            
            for window in windows {
                if let ttyPath = extractTTYFromWindow(window, app: app) {
                    mappings[ttyPath] = window
                    logger.debug("Mapped TTY \(ttyPath) to window in \(app.bundleIdentifier ?? "unknown")")
                }
            }
        }
        
        return mappings
    }
    
    // MARK: - Private Helpers
    
    private func isTerminalApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        
        let terminalBundleIDs = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.github.wez.wezterm",
            "dev.warp.Warp-Stable",
            "net.kovidgoyal.kitty",
            "co.zeit.hyper",
            "com.mitchellh.ghostty",
            "com.brave.Browser",
            "com.google.Chrome",
            "org.mozilla.firefox"
        ]
        
        return terminalBundleIDs.contains(bundleID)
    }
    
    private func findWindowInApp(_ app: NSRunningApplication, forTTY ttyName: String) -> Element? {
        guard let appElement = Element.application(for: app.processIdentifier) else {
            logger.warning("Could not get application element for \(app.bundleIdentifier ?? "unknown")")
            return nil
        }
        
        guard let windows = appElement.windows() else {
            logger.debug("No windows found for \(app.bundleIdentifier ?? "unknown")")
            return nil
        }
        
        logger.debug("Checking \(windows.count) windows in \(app.bundleIdentifier ?? "unknown") for TTY \(ttyName)")
        
        // Special handling for iTerm2
        if app.bundleIdentifier == "com.googlecode.iterm2" {
            return findITermWindowForTTY(windows: windows, ttyName: ttyName)
        }
        
        // For each window, check if it's associated with our TTY
        for window in windows {
                // Different terminals expose TTY info differently
                // Terminal.app often includes TTY in the title
                if let title = window.title() {
                    if title.contains(ttyName) || title.contains("ttys\(ttyName.dropFirst(4))") {
                        logger.debug("Found window by title containing TTY: '\(title)'")
                        return window
                    }
                }
                
                // Some terminals might expose it as an accessibility attribute
                // This would need terminal-specific handling
                
                // Additional heuristic: Check if the window's shell process is using this TTY
                if let windowPID = getShellPIDForWindow(window, app: app) {
                    if isProcessUsingTTY(pid: windowPID, ttyPath: "/dev/\(ttyName)") {
                        logger.debug("Found window by shell process \(windowPID) using TTY")
                        return window
                    }
                }
            }
        
        return nil
    }
    
    private func extractTTYFromWindow(_ window: Element, app: NSRunningApplication) -> String? {
        // Try to extract TTY from window title
        if let title = window.title() {
            // Look for TTY patterns in the title
            let ttyPattern = #"ttys\d+"#
            if let regex = try? NSRegularExpression(pattern: ttyPattern, options: .caseInsensitive) {
                let range = NSRange(title.startIndex..., in: title)
                if let match = regex.firstMatch(in: title, options: [], range: range) {
                    if let matchRange = Range(match.range, in: title) {
                        let ttyName = String(title[matchRange])
                        return "/dev/\(ttyName)"
                    }
                }
            }
        }
        
        // Try to get TTY from window's shell process
        if let shellPID = getShellPIDForWindow(window, app: app) {
            if let ttyPath = getTTYForProcess(pid: shellPID) {
                return ttyPath
            }
        }
        
        return nil
    }
    
    private func getShellPIDForWindow(_ window: Element, app: NSRunningApplication) -> Int32? {
        // This is terminal-specific and would need custom implementation
        // For now, returning nil as a placeholder
        return nil
    }
    
    private func isProcessUsingTTY(pid: Int32, ttyPath: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-p", "\(pid)", "-a", ttyPath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                return true
            }
        } catch {
            logger.error("Failed to check if process \(pid) is using TTY \(ttyPath): \(error)")
        }
        
        return false
    }
    
    private func getTTYForProcess(pid: Int32) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-p", "\(pid)", "-a", "-d", "0"]  // Check stdin (fd 0)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse lsof output to find TTY device
                let lines = output.components(separatedBy: .newlines)
                for line in lines where line.contains("/dev/ttys") {
                    // Extract the device path
                    let components = line.components(separatedBy: .whitespaces)
                    for component in components where component.hasPrefix("/dev/ttys") {
                        return component
                    }
                }
            }
        } catch {
            logger.error("Failed to get TTY for process \(pid): \(error)")
        }
        
        return nil
    }
    
    /// Find iTerm window that contains a session with the given TTY
    private func findITermWindowForTTY(windows: [Element], ttyName: String) -> Element? {
        logger.debug("Using iTerm-specific logic to find window for TTY \(ttyName)")
        
        // iTerm2 windows have unique IDs that we can use
        // First, try to match by window title (some users configure iTerm to show paths)
        for window in windows {
            if let title = window.title() {
                // Check if title contains the TTY name
                if title.contains(ttyName) {
                    logger.debug("Found iTerm window by title containing TTY \(ttyName)")
                    return window
                }
                
                // Also check if title contains path segments that might match
                let ttyShortName = ttyName.replacingOccurrences(of: "/dev/", with: "")
                if title.contains(ttyShortName) {
                    logger.debug("Found iTerm window by title containing short TTY name \(ttyShortName)")
                    return window
                }
            }
        }
        
        // For iTerm2, we often can't determine the exact window from TTY alone
        // Return the first window that seems active (has focus or is frontmost)
        for window in windows {
            if let isFocused = window.isFocused(), isFocused {
                logger.debug("Returning focused iTerm window for TTY \(ttyName)")
                return window
            }
        }
        
        // Fall back to the first window
        if let firstWindow = windows.first {
            logger.debug("Returning first iTerm window as likely container for TTY \(ttyName)")
            return firstWindow
        }
        
        return nil
    }
}