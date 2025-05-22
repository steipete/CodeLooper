import Foundation

/// A Sendable-safe context structure for diagnostic operations
/// This replaces dictionaries with type-safe Sendable context values
struct DiagnosticContext: Sendable {
    // Redesigned to be fully Sendable-compatible in Swift 6.1
    // Swift 6.1 automatically makes structures Sendable when all properties are Sendable
    // Instead of using Optional types, use empty strings and 0 values as indicators

    /// Operation name or identifier (empty string if not set)
    var operation: String = ""

    /// Timestamp for request start time (0 if not set)
    var requestTimeInterval: TimeInterval = 0

    /// Timestamp for upload or operation time (0 if not set)
    var uploadTimeInterval: TimeInterval = 0

    /// Timestamp for sync time (0 if not set)
    var syncTimeInterval: TimeInterval = 0

    /// Reason for a failure or behavior (empty string if not set)
    var reason: String = ""

    /// Export type or configuration description (empty string if not set)
    var exportType: String = ""

    /// Upload interval in seconds (0 if not set)
    var scheduleTime: TimeInterval = 0

    /// Time when a failure occurred (0 if not set)
    var failTimeInterval: TimeInterval = 0

    /// Timeout interval that was used (0 if not set)
    var timeoutInterval: TimeInterval = 0

    /// Whether a timer was valid at time of capture (-1 if not set, 0 if false, 1 if true)
    var timeoutTimerValidInt: Int = -1

    // Use helper methods for Date conversions

    /// Get request time as Date
    var requestTime: Date? {
        requestTimeInterval > 0 ? Date(timeIntervalSince1970: requestTimeInterval) : nil
    }

    /// Get upload time as Date
    var uploadTime: Date? {
        uploadTimeInterval > 0 ? Date(timeIntervalSince1970: uploadTimeInterval) : nil
    }

    /// Get sync time as Date
    var syncTime: Date? {
        syncTimeInterval > 0 ? Date(timeIntervalSince1970: syncTimeInterval) : nil
    }

    /// Get fail time as Date
    var failTime: Date? {
        failTimeInterval > 0 ? Date(timeIntervalSince1970: failTimeInterval) : nil
    }

    /// Get timeout timer valid state as Bool
    /// Returns true if valid, false if invalid, or false if not set (check hasTimeoutTimerValue)
    var timeoutTimerValid: Bool {
        timeoutTimerValidInt > 0
    }

    /// Returns true if the timeout timer value has been explicitly set
    var hasTimeoutTimerValue: Bool {
        timeoutTimerValidInt >= 0
    }

    /// Store custom values in a predefined array instead of Dictionary for BitwiseCopyable compliance
    /// Format: [key1, value1, key2, value2, ...]
    var customValuesList: [String] = []

    /// Convert Dictionary<String, Any> context to DiagnosticContext
    static func from(dictionary: [String: Any]) -> DiagnosticContext {
        var context = DiagnosticContext()

        for (key, value) in dictionary {
            context.processKeyValue(key: key, value: value)
        }

        return context
    }

    /// Process individual key-value pairs from dictionary
    private mutating func processKeyValue(key: String, value: Any) {
        switch key {
        case "operation":
            processStringValue(value) { self.operation = $0 }
        case "requestTime":
            processTimeValue(value) { self.requestTimeInterval = $0 }
        case "uploadTime":
            processTimeValue(value) { self.uploadTimeInterval = $0 }
        case "syncTime":
            processTimeValue(value) { self.syncTimeInterval = $0 }
        case "reason":
            processStringValue(value) { self.reason = $0 }
        case "exportType":
            processStringValue(value) { self.exportType = $0 }
        case "scheduleTime":
            processTimeIntervalValue(value) { self.scheduleTime = $0 }
        case "failTime":
            processTimeValue(value) { self.failTimeInterval = $0 }
        case "timeoutInterval":
            processTimeIntervalValue(value) { self.timeoutInterval = $0 }
        case "timeoutTimerValid":
            processBoolValue(value) { self.timeoutTimerValidInt = $0 ? 1 : 0 }
        default:
            // Store as string representation in the array
            customValuesList.append(key)
            customValuesList.append(String(describing: value))
        }
    }

    /// Helper to process string values
    private func processStringValue(_ value: Any, setter: (String) -> Void) {
        if let strValue = value as? String {
            setter(strValue)
        }
    }

    /// Helper to process time values (TimeInterval or Date)
    private func processTimeValue(_ value: Any, setter: (TimeInterval) -> Void) {
        if let timestamp = value as? TimeInterval {
            setter(timestamp)
        } else if let date = value as? Date {
            setter(date.timeIntervalSince1970)
        }
    }

    /// Helper to process TimeInterval values
    private func processTimeIntervalValue(_ value: Any, setter: (TimeInterval) -> Void) {
        if let timeValue = value as? TimeInterval {
            setter(timeValue)
        }
    }

    /// Helper to process boolean values
    private func processBoolValue(_ value: Any, setter: (Bool) -> Void) {
        if let boolValue = value as? Bool {
            setter(boolValue)
        }
    }

    /// Helper to get custom values as dictionary (non-modifying)
    func customValues() -> [String: String] {
        var dict = [String: String]()

        // Iterate through pairs in the array
        for index in stride(from: 0, to: customValuesList.count, by: 2) where index + 1 < customValuesList.count {
            let key = customValuesList[index]
            let value = customValuesList[index + 1]
            dict[key] = value
        }

        return dict
    }

    /// Helper to add a custom value
    mutating func addCustomValue(_ key: String, _ value: String) {
        customValuesList.append(key)
        customValuesList.append(value)
    }

    /// Convert DiagnosticContext to a string representation for logging
    func description() -> String {
        var components: [String] = []

        if !operation.isEmpty {
            components.append("operation: \(operation)")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let requestTime {
            components.append("requestTime: \(dateFormatter.string(from: requestTime))")
        }

        if let uploadTime {
            components.append("uploadTime: \(dateFormatter.string(from: uploadTime))")
        }

        if let syncTime {
            components.append("syncTime: \(dateFormatter.string(from: syncTime))")
        }

        if !reason.isEmpty {
            components.append("reason: \(reason)")
        }

        if !exportType.isEmpty {
            components.append("exportType: \(exportType)")
        }

        if scheduleTime > 0 {
            components.append("scheduleTime: \(String(format: "%.2f", scheduleTime))")
        }

        if let failTime {
            components.append("failTime: \(dateFormatter.string(from: failTime))")
        }

        if timeoutInterval > 0 {
            components.append("timeoutInterval: \(String(format: "%.2f", timeoutInterval))")
        }

        // Include timeoutTimerValid status
        components.append("timeoutTimerValid: \(timeoutTimerValid)")

        // Add custom values from the array
        let customDict = customValues()
        for (key, value) in customDict {
            components.append("\(key): \(value)")
        }

        return components.joined(separator: ", ")
    }
}
