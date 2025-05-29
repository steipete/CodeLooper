import Defaults
import Diagnostics
import Foundation

/// Manages execution counters for all automation rules
@MainActor
public class RuleCounterManager: ObservableObject {
    public static let shared = RuleCounterManager()
    
    @Published public private(set) var ruleCounters: [String: Int] = [:]
    
    private let logger = Logger(category: .intervention)
    
    private init() {
        loadCounters()
    }
    
    /// Increment the counter for a specific rule
    public func incrementCounter(for ruleName: String) {
        let currentCount = ruleCounters[ruleName] ?? 0
        ruleCounters[ruleName] = currentCount + 1
        
        logger.info("Rule '\(ruleName)' executed. Total count: \(ruleCounters[ruleName] ?? 0)")
        
        // Save to UserDefaults
        saveCounters()
        
        // Send notification for UI updates
        NotificationCenter.default.post(
            name: .ruleCounterUpdated,
            object: nil,
            userInfo: [
                "ruleName": ruleName,
                "count": ruleCounters[ruleName] ?? 0
            ]
        )
    }
    
    /// Get the count for a specific rule
    public func getCount(for ruleName: String) -> Int {
        return ruleCounters[ruleName] ?? 0
    }
    
    /// Get total count across all rules
    public var totalRuleExecutions: Int {
        return ruleCounters.values.reduce(0, +)
    }
    
    /// Reset counters for a specific rule
    public func resetCounter(for ruleName: String) {
        ruleCounters[ruleName] = 0
        saveCounters()
        logger.info("Reset counter for rule '\(ruleName)'")
    }
    
    /// Reset all counters
    public func resetAllCounters() {
        ruleCounters.removeAll()
        saveCounters()
        logger.info("Reset all rule counters")
    }
    
    /// Get all rule names that have been executed
    public var executedRuleNames: [String] {
        return Array(ruleCounters.keys).sorted()
    }
    
    // MARK: - Private Methods
    
    private func saveCounters() {
        UserDefaults.standard.set(ruleCounters, forKey: "ruleExecutionCounters")
    }
    
    private func loadCounters() {
        if let saved = UserDefaults.standard.object(forKey: "ruleExecutionCounters") as? [String: Int] {
            ruleCounters = saved
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ruleCounterUpdated = Notification.Name("ruleCounterUpdated")
}

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let showRuleExecutionCounters = Key<Bool>("showRuleExecutionCounters", default: true)
}
