import Testing

// MARK: - Centralized Test Tags

extension Tag {
    // MARK: Feature Tags
    @Tag static var monitoring: Self
    @Tag static var intervention: Self
    @Tag static var aiAnalysis: Self
    @Tag static var settings: Self
    @Tag static var statusBar: Self
    @Tag static var onboarding: Self
    @Tag static var gitTracking: Self
    @Tag static var mcpIntegration: Self
    @Tag static var rules: Self
    @Tag static var accessibility: Self
    @Tag static var jsHook: Self
    @Tag static var diagnostics: Self
    
    // MARK: Test Type Tags
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var performance: Self
    @Tag static var regression: Self
    @Tag static var smoke: Self
    
    // MARK: Execution Tags
    @Tag static var fast: Self
    @Tag static var slow: Self
    @Tag static var flaky: Self
    @Tag static var requiresNetwork: Self
    @Tag static var requiresPermissions: Self
    @Tag static var offline: Self
    
    // MARK: Component Tags
    @Tag static var ui: Self
    @Tag static var networking: Self
    @Tag static var database: Self
    @Tag static var threading: Self
    @Tag static var async: Self
    @Tag static var utilities: Self
    @Tag static var core: Self
    
    // MARK: Priority Tags
    @Tag static var critical: Self
    @Tag static var high: Self
    @Tag static var medium: Self
    @Tag static var low: Self
    
    // MARK: Special Tags
    @Tag static var basic: Self
    @Tag static var advanced: Self
    @Tag static var edgeCases: Self
    @Tag static var errorHandling: Self
    @Tag static var lifecycle: Self
    @Tag static var concurrency: Self
    @Tag static var memory: Self
    @Tag static var timing: Self
    @Tag static var state: Self
    @Tag static var validation: Self
}