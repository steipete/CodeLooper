import Testing

// MARK: - Shared Test Tags
// This file defines all test tags used across the test suite to avoid conflicts

extension Tag {
    // MARK: - Core Categories
    @Tag static var core: Self
    @Tag static var utilities: Self
    @Tag static var infrastructure: Self
    @Tag static var configuration: Self
    
    // MARK: - Testing Types
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var performance: Self
    @Tag static var reliability: Self
    @Tag static var edge_cases: Self
    
    // MARK: - Concurrency & Threading
    @Tag static var threading: Self
    @Tag static var async: Self
    @Tag static var synchronous: Self
    @Tag static var concurrent: Self
    
    // MARK: - System Integration
    @Tag static var system: Self
    @Tag static var permissions: Self
    @Tag static var accessibility: Self
    @Tag static var automation: Self
    
    // MARK: - Application Components
    @Tag static var monitoring: Self
    @Tag static var intervention: Self
    @Tag static var analysis: Self
    @Tag static var notifications: Self
    @Tag static var settings: Self
    @Tag static var statusbar: Self
    
    // MARK: - Data & State
    @Tag static var state: Self
    @Tag static var caching: Self
    @Tag static var persistence: Self
    @Tag static var memory: Self
    @Tag static var storage: Self
    
    // MARK: - Operations
    @Tag static var initialization: Self
    @Tag static var operations: Self
    @Tag static var lifecycle: Self
    @Tag static var management: Self
    @Tag static var processing: Self
    
    // MARK: - Error Handling
    @Tag static var error_handling: Self
    @Tag static var error: Self
    @Tag static var validation: Self
    @Tag static var recovery: Self
    @Tag static var diagnostics: Self
    
    // MARK: - External Dependencies
    @Tag static var axorcist: Self
    @Tag static var openai: Self
    @Tag static var ollama: Self
    @Tag static var sparkle: Self
    @Tag static var git: Self
    
    // MARK: - UI & User Experience
    @Tag static var ui: Self
    @Tag static var user_interface: Self
    @Tag static var window_management: Self
    @Tag static var user_defaults: Self
    
    // MARK: - Network & Communication
    @Tag static var network: Self
    @Tag static var websocket: Self
    @Tag static var jshook: Self
    @Tag static var communication: Self
    
    // MARK: - Timing & Performance
    @Tag static var timing: Self
    @Tag static var debouncing: Self
    @Tag static var throttling: Self
    @Tag static var optimization: Self
    
    // MARK: - Specific Features
    @Tag static var rule_execution: Self
    @Tag static var file_monitoring: Self
    @Tag static var cursor_monitoring: Self
    @Tag static var claude_monitoring: Self
    @Tag static var screenshot_analysis: Self
    
    // MARK: - Test Organization
    @Tag static var basic: Self
    @Tag static var advanced: Self
    @Tag static var critical: Self
    @Tag static var optional: Self
    
    // MARK: - Additional Tags (added for existing test compatibility)
    @Tag static var provider: Self
    @Tag static var model: Self
    @Tag static var io: Self
    @Tag static var manager: Self
    @Tag static var `enum`: Self
    @Tag static var singleton: Self
    @Tag static var authorization: Self
    @Tag static var content: Self
    @Tag static var creation: Self
    @Tag static var requests: Self
    @Tag static var setup: Self
    @Tag static var metadata: Self
    @Tag static var source: Self
    @Tag static var debugging: Self
    @Tag static var benchmarks: Self
    @Tag static var security: Self
    @Tag static var end_to_end: Self
    @Tag static var types: Self
    @Tag static var generics: Self
    @Tag static var viewmodel: Self
    @Tag static var logging: Self
    @Tag static var categories: Self
    @Tag static var levels: Self
    @Tag static var global: Self
    @Tag static var defaults: Self
    @Tag static var updates: Self
    @Tag static var apps: Self
    @Tag static var windows: Self
    @Tag static var documents: Self
    @Tag static var interventions: Self
    @Tag static var tracking: Self
    @Tag static var robustness: Self
    @Tag static var cancellation: Self
    @Tag static var context: Self
    @Tag static var filtering: Self
    @Tag static var concurrency: Self
    @Tag static var serialization: Self
    @Tag static var codable: Self
    @Tag static var classification: Self
    @Tag static var logic: Self
    @Tag static var transitions: Self
    @Tag static var type_safety: Self
    @Tag static var collections: Self
    @Tag static var rules: Self
    @Tag static var status: Self
}