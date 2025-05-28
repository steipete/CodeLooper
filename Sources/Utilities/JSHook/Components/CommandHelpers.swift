import Foundation

// MARK: - Command Helpers

extension CursorJSHook {
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
    
    /// Check if the "resume conversation" link is visible
    public func checkResumeNeeded() async throws -> String {
        try await sendCommand(["type": "checkResumeNeeded"])
    }
    
    /// Click the "resume conversation" link if it's available
    public func clickResume() async throws -> String {
        try await sendCommand(["type": "clickResume"])
    }
    
    /// Check if resume is needed and return as a boolean
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
    public func startComposerObserver() async throws -> String {
        try await sendCommand(["type": "startComposerObserver"])
    }
    
    /// Stop observing the composer bar
    public func stopComposerObserver() async throws -> String {
        try await sendCommand(["type": "stopComposerObserver"])
    }
    
    /// Get the current content of the composer bar
    public func getComposerContent() async throws -> String {
        try await sendCommand(["type": "getComposerContent"])
    }
    
    /// Start observing composer bar and return success status
    public func startObservingComposer() async throws -> Bool {
        let result = try await startComposerObserver()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else {
            return false
        }
        return success
    }
}