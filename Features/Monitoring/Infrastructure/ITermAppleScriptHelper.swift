import Foundation
import AppKit
import Diagnostics

/// Helper class for extracting text from iTerm2 sessions using AppleScript
@MainActor
final class ITermAppleScriptHelper {
    
    private let logger = Logger(category: .supervision)
    
    /// Get all iTerm sessions with their content
    func getAllITermSessions() async -> [(sessionId: String, tty: String, content: String)] {
        let script = """
        tell application "iTerm"
            set sessionInfoList to {}
            
            repeat with w in windows
                tell w
                    repeat with t in tabs
                        tell t
                            repeat with s in sessions
                                tell s
                                    try
                                        set sessionId to id
                                        set ttyName to tty
                                        set sessionText to text
                                        set end of sessionInfoList to {sessionId:sessionId, tty:ttyName, content:sessionText}
                                    end try
                                end tell
                            end repeat
                        end tell
                    end repeat
                end tell
            end repeat
            
            return sessionInfoList
        end tell
        """
        
        do {
            let sessions = try await runAppleScript(script)
            return parseITermSessions(sessions)
        } catch {
            logger.error("Failed to get iTerm sessions: \(error)")
            return []
        }
    }
    
    /// Get content for a specific iTerm session by TTY
    func getITermSessionByTTY(_ ttyPath: String) async -> String? {
        let ttyName = URL(fileURLWithPath: ttyPath).lastPathComponent
        
        let script = """
        tell application "iTerm"
            repeat with w in windows
                tell w
                    repeat with t in tabs
                        tell t
                            repeat with s in sessions
                                tell s
                                    try
                                        if tty contains "\(ttyName)" then
                                            return text
                                        end if
                                    end try
                                end tell
                            end repeat
                        end tell
                    end repeat
                end tell
            end repeat
            return ""
        end tell
        """
        
        do {
            let result = try await runAppleScript(script)
            guard let content = result as? String, !content.isEmpty else {
                return nil
            }
            return content
        } catch {
            logger.error("Failed to get iTerm session for TTY \(ttyPath): \(error)")
            return nil
        }
    }
    
    /// Get content from iTerm session matching a working directory
    func getITermSessionByDirectory(_ directory: String) async -> String? {
        let script = """
        tell application "iTerm"
            repeat with w in windows
                tell w
                    repeat with t in tabs
                        tell t
                            repeat with s in sessions
                                tell s
                                    try
                                        -- Get session name which often contains the directory
                                        set sessionName to name
                                        if sessionName contains "\(directory)" then
                                            return text
                                        end if
                                    end try
                                end tell
                            end repeat
                        end tell
                    end repeat
                end tell
            end repeat
            return ""
        end tell
        """
        
        do {
            let result = try await runAppleScript(script)
            guard let content = result as? String, !content.isEmpty else {
                return nil
            }
            return content
        } catch {
            logger.error("Failed to get iTerm session for directory \(directory): \(error)")
            return nil
        }
    }
    
    /// Check if iTerm is running
    func isITermRunning() -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.runningApplications.contains { app in
            app.bundleIdentifier == "com.googlecode.iterm2"
        }
    }
    
    // MARK: - Private Helpers
    
    private func runAppleScript(_ script: String) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                    continuation.resume(throwing: NSError(
                        domain: "ITermAppleScriptHelper",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    ))
                } else if let descriptor = result {
                    // For simple string results
                    if descriptor.descriptorType == typeUnicodeText || descriptor.descriptorType == typeUTF8Text {
                        let stringResult = descriptor.stringValue ?? ""
                        continuation.resume(returning: stringResult)
                    } 
                    // For boolean results
                    else if descriptor.descriptorType == typeBoolean {
                        continuation.resume(returning: descriptor.booleanValue)
                    }
                    // For list results (like getAllITermSessions)
                    else if descriptor.descriptorType == typeAEList {
                        var results: [[String: String]] = []
                        let itemCount = descriptor.numberOfItems
                        
                        for i in 1...itemCount {
                            if let recordDescriptor = descriptor.atIndex(i),
                               recordDescriptor.descriptorType == typeAERecord {
                                var record: [String: String] = [:]
                                
                                // Extract sessionId
                                if let sessionIdDesc = recordDescriptor.forKeyword(ITermAppleScriptHelper.FourCharCode(kw: "seid")) {
                                    record["sessionId"] = sessionIdDesc.stringValue ?? ""
                                }
                                
                                // Extract tty
                                if let ttyDesc = recordDescriptor.forKeyword(ITermAppleScriptHelper.FourCharCode(kw: "ttyn")) {
                                    record["tty"] = ttyDesc.stringValue ?? ""
                                }
                                
                                // Extract content
                                if let contentDesc = recordDescriptor.forKeyword(ITermAppleScriptHelper.FourCharCode(kw: "cont")) {
                                    record["content"] = contentDesc.stringValue ?? ""
                                }
                                
                                if !record.isEmpty {
                                    results.append(record)
                                }
                            }
                        }
                        
                        continuation.resume(returning: results)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Helper to create FourCharCode from string
    private nonisolated static func FourCharCode(kw: String) -> AEKeyword {
        var result: AEKeyword = 0
        for (i, char) in kw.utf8.prefix(4).enumerated() {
            result |= AEKeyword(char) << (8 * (3 - i))
        }
        return result
    }
    
    private func parseITermSessions(_ data: Any?) -> [(sessionId: String, tty: String, content: String)] {
        guard let records = data as? [[String: String]] else {
            return []
        }
        
        return records.compactMap { record in
            guard let sessionId = record["sessionId"],
                  let tty = record["tty"],
                  let content = record["content"] else {
                return nil
            }
            return (sessionId: sessionId, tty: tty, content: content)
        }
    }
}