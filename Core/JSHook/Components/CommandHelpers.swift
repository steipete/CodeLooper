import Foundation

// MARK: - Command Helpers

public extension CursorJSHook {
    /// Get system information from the browser
    func getSystemInfo() async throws -> String {
        try await sendCommand(["type": "getSystemInfo"])
    }

    /// Query for an element using a CSS selector
    func querySelector(_ selector: String) async throws -> String {
        try await sendCommand(["type": "querySelector", "selector": selector])
    }

    /// Get detailed information about an element
    func getElementInfo(_ selector: String) async throws -> String {
        try await sendCommand(["type": "getElementInfo", "selector": selector])
    }

    /// Click an element
    func clickElement(_ selector: String) async throws -> String {
        try await sendCommand(["type": "clickElement", "selector": selector])
    }

    /// Get information about the currently focused element
    func getActiveElement() async throws -> String {
        try await sendCommand(["type": "getActiveElement"])
    }

    /// Show a notification in Cursor
    func showNotification(
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
            "browserNotification": browserNotification,
        ]

        if let title {
            command["title"] = title
        }

        return try await sendCommand(command)
    }

    /// Check if a rule action is needed (if the "resume conversation" link is visible)
    func checkRuleNeeded() async throws -> String {
        try await sendCommand(["type": "checkRuleNeeded"])
    }

    /// Click the "resume conversation" link if it's available
    func clickResume() async throws -> String {
        try await sendCommand(["type": "clickResume"])
    }

    /// Check if a rule action is needed and return as a boolean
    func isRuleNeeded() async throws -> Bool {
        let result = try await checkRuleNeeded()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ruleNeeded = json["ruleNeeded"] as? Bool
        else {
            return false
        }
        return ruleNeeded
    }

    /// Perform a rule action (click the resume link)
    func performRule() async throws -> String {
        try await sendCommand(["type": "performRule"])
    }

    /// Attempt to resume Cursor if needed
    func attemptResume() async throws -> Bool {
        let result = try await clickResume()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool
        else {
            return false
        }
        return success
    }

    // MARK: - Composer Bar Observation

    /// Start observing the composer bar for changes
    func startComposerObserver() async throws -> String {
        try await sendCommand(["type": "startComposerObserver"])
    }

    /// Stop observing the composer bar
    func stopComposerObserver() async throws -> String {
        try await sendCommand(["type": "stopComposerObserver"])
    }

    /// Get the current content of the composer bar
    func getComposerContent() async throws -> String {
        try await sendCommand(["type": "getComposerContent"])
    }

    /// Start observing composer bar and return success status
    func startObservingComposer() async throws -> Bool {
        let result = try await startComposerObserver()
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool
        else {
            return false
        }
        return success
    }
}
