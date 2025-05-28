import Foundation
import AppKit

enum JSHookDevConsoleDetector {
    static func isDevConsoleOpen(in applicationName: String) -> Bool {
        let script = """
        tell application "System Events"
            if exists process "\(applicationName)" then
                tell process "\(applicationName)"
                    set windowList to windows
                    repeat with aWindow in windowList
                        if name of aWindow contains "Developer Tools" then
                            return true
                        end if
                    end repeat
                end tell
            end if
        end tell
        return false
        """
        
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(nil)
        return result?.booleanValue ?? false
    }
}