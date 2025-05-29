import AppKit
import Defaults
import Diagnostics
import Foundation

/// Service that executes automation rules using JavaScript hooks
@MainActor
public class RuleExecutor {
    // MARK: Lifecycle
    
    public init() {
        logger.info("RuleExecutor initialized")
    }
    
    // MARK: Public
    
    /// Execute all enabled rules for all hooked windows
    public func executeEnabledRules() async {
        // Only execute if global monitoring is enabled
        guard Defaults[.isGlobalMonitoringEnabled] else {
            return
        }
        
        let jsHookService = JSHookService.shared
        let windowIds = jsHookService.getAllHookedWindowIds()
        
        // Execute StopAfter25LoopsRule if enabled
        if Defaults[.enableCursorForceStoppedRecovery] {
            await executeStopAfter25LoopsRule(for: windowIds, jsHookService: jsHookService)
        }
        
        // Future rules can be added here
    }
    
    // MARK: Private
    
    private let logger = Logger(category: .intervention)
    private let stopAfter25LoopsRule = StopAfter25LoopsRule()
    
    /// Execute the StopAfter25LoopsRule for all windows
    private func executeStopAfter25LoopsRule(for windowIds: [String], jsHookService: JSHookService) async {
        for windowId in windowIds {
            let success = await stopAfter25LoopsRule.execute(windowId: windowId, jsHookService: jsHookService)
            if success {
                logger.info("StopAfter25LoopsRule executed successfully for window \(windowId)")
            } else {
                logger.info("StopAfter25LoopsRule stopped execution for window \(windowId) (reached limit or no intervention needed)")
            }
        }
    }
}
