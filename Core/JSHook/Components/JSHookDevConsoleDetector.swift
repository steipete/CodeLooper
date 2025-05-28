import AppKit
import Foundation
import Diagnostics

enum JSHookDevConsoleDetector {
    static func isDevConsoleOpen(in applicationName: String, targetWindowTitle: String? = nil) -> Bool {
        let logger = Logger(category: .jshook)
        logger.debug("🔍 Checking if dev console is open in \(applicationName) - target window: \(targetWindowTitle ?? "any")")
        
        // If we have a specific window, use AppleScript to check that specific window
        if let windowTitle = targetWindowTitle {
            return checkSpecificWindowWithAppleScript(applicationName: applicationName, windowTitle: windowTitle)
        }
        
        // First try using the existing robust WindowTextExtractor + DevConsoleDetector
        do {
            let isOpen = DevConsoleDetector.isDevConsoleOpen(in: applicationName)
            logger.debug("✅ Text-based detection result: \(isOpen)")
            
            if isOpen {
                return true
            }
        } catch {
            logger.warning("⚠️ Text-based detection failed: \(error.localizedDescription)")
        }
        
        // Fallback to AppleScript window detection (improved to target correct window)
        return checkWithAppleScript(applicationName: applicationName)
    }
    
    private static func checkSpecificWindowWithAppleScript(applicationName: String, windowTitle: String) -> Bool {
        let logger = Logger(category: .jshook)
        logger.debug("🍎 Checking specific window '\(windowTitle)' for dev console")
        
        let script = """
        tell application "System Events"
            if exists process "\(applicationName)" then
                tell process "\(applicationName)"
                    try
                        # Find the specific window by title
                        set targetWindow to (first window whose name is "\(windowTitle)")
                        
                        # Get all UI elements in this specific window
                        set allElements to entire contents of targetWindow
                        
                        # Convert to string and check for dev console keywords
                        set elementText to allElements as string
                        
                        # Check for multiple dev console keywords
                        set keywordCount to 0
                        set keywords to {"Console", "Elements", "Network", "Sources", "Lighthouse", "DevTools", "Performance", "Memory", "Application", "Security", "Debugger"}
                        
                        repeat with keyword in keywords
                            if elementText contains keyword then
                                set keywordCount to keywordCount + 1
                            end if
                        end repeat
                        
                        # If we find 3+ keywords, likely dev console is open in this window
                        if keywordCount >= 3 then
                            return true
                        end if
                        
                        return false
                    on error errorMessage
                        # Log error and return false
                        log "Error checking specific window: " & errorMessage
                        return false
                    end try
                end tell
            end if
        end tell
        return false
        """

        return executeAppleScriptDetection(script: script, logger: logger)
    }
    
    private static func checkWithAppleScript(applicationName: String) -> Bool {
        let logger = Logger(category: .jshook)
        logger.debug("🍎 Falling back to AppleScript window detection")
        
        let script = """
        tell application "System Events"
            if exists process "\(applicationName)" then
                tell process "\(applicationName)"
                    # Get all windows
                    set windowList to windows
                    
                    # Check each window for dev console indicators
                    repeat with aWindow in windowList
                        try
                            # Get window name
                            set windowName to name of aWindow
                            
                            # Check if window name contains dev tools indicators
                            if windowName contains "Developer Tools" or windowName contains "DevTools" or windowName contains "Console" then
                                return true
                            end if
                            
                            # Check if this is a Cursor window with inline dev tools
                            # Look for specific UI elements that indicate dev console
                            if windowName contains "Cursor" or windowName contains ".js" or windowName contains ".ts" or windowName contains ".swift" then
                                # Try to get all UI elements in this window
                                set allElements to entire contents of aWindow
                                
                                # Convert to string and check for dev console keywords
                                set elementText to allElements as string
                                
                                # Check for multiple dev console keywords
                                set keywordCount to 0
                                set keywords to {"Console", "Elements", "Network", "Sources", "Lighthouse", "DevTools", "Performance", "Memory", "Application"}
                                
                                repeat with keyword in keywords
                                    if elementText contains keyword then
                                        set keywordCount to keywordCount + 1
                                    end if
                                end repeat
                                
                                # If we find 3+ keywords, likely dev console is open
                                if keywordCount >= 3 then
                                    return true
                                end if
                            end if
                        on error errorMessage
                            # Log error but continue checking other windows
                            log "Error checking window: " & errorMessage
                        end try
                    end repeat
                end tell
            end if
        end tell
        return false
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)
        
        // Handle errors properly
        if let error = errorDict {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
            
            logger.error("🍎 AppleScript dev console detection failed: \(errorMessage) (Code: \(errorNumber))")
            
            // Check for specific error codes
            switch errorNumber {
            case -1743:
                logger.error("⚠️ User denied automation permission")
            case -600:
                logger.error("⚠️ Application \(applicationName) not running or not found")
            case -10004:
                logger.error("⚠️ A privilege violation occurred")
            default:
                logger.error("⚠️ Unexpected AppleScript error: \(errorNumber)")
            }
            
            return false
        }
        
        return executeAppleScriptDetection(script: script, logger: logger)
    }
    
    private static func executeAppleScriptDetection(script: String, logger: Logger) -> Bool {
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)
        
        // Handle errors properly
        if let error = errorDict {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
            
            logger.error("🍎 AppleScript dev console detection failed: \(errorMessage) (Code: \(errorNumber))")
            
            // Check for specific error codes
            switch errorNumber {
            case -1743:
                logger.error("⚠️ User denied automation permission")
            case -600:
                logger.error("⚠️ Application not running or not found")
            case -10004:
                logger.error("⚠️ A privilege violation occurred")
            default:
                logger.error("⚠️ Unexpected AppleScript error: \(errorNumber)")
            }
            
            return false
        }
        
        let isOpen = result?.booleanValue ?? false
        logger.debug("🍎 AppleScript detection result: \(isOpen)")
        return isOpen
    }
}
