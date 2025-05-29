import AppKit
import Defaults
import Diagnostics
import Foundation
import UserNotifications

/// Rule that automatically stops execution after 25 loops to prevent infinite cycles
@MainActor
public class StopAfter25LoopsRule {
    // MARK: Lifecycle
    
    public init() {
        logger.info("StopAfter25LoopsRule initialized")
    }
    
    // MARK: Public
    
    public let displayName = "Stop after 25 loops"
    public let ruleName = "StopAfter25LoopsRule"
    
    /// Execute the rule for a specific window
    func execute(windowId: String, jsHookService: JSHookService) async -> Bool {
        do {
            // Check current execution count
            let currentCount = RuleCounterManager.shared.getCount(for: ruleName)
            
            guard currentCount < 25 else {
                logger.info("🛑 Rule '\(displayName)' has reached 25 executions limit, stopping")
                
                // Play sound if enabled
                if Defaults[.enableRuleSounds] {
                    let soundName = Defaults[.stopAfter25LoopsRuleSound]
                    SoundEngine.playSystemSound(named: soundName)
                }
                
                // Send notification if enabled
                if Defaults[.enableRuleNotifications] {
                    await UserNotificationManager.shared.sendRuleExecutionNotification(
                        ruleName: ruleName,
                        displayName: displayName,
                        executionCount: currentCount,
                        isWarning: false
                    )
                }
                
                return false // Stop execution
            }
            
            // Check if intervention is needed
            let checkCommand: [String: Any] = ["type": "checkInterventionNeeded"]
            let checkResult = try await jsHookService.sendCommand(checkCommand, to: windowId)
            
            // Parse the result
            guard let data = checkResult.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let interventionNeeded = json["interventionNeeded"] as? Bool else {
                logger.warning("Failed to parse intervention check result for window \(windowId)")
                return false
            }
            
            if interventionNeeded {
                logger.info("🔄 Intervention needed detected for window \(windowId)")
                
                // Perform the intervention
                let interventionCommand: [String: Any] = ["type": "performIntervention"]
                let interventionResult = try await jsHookService.sendCommand(interventionCommand, to: windowId)
                
                // Parse intervention result
                if let interventionData = interventionResult.data(using: .utf8),
                   let interventionJson = try? JSONSerialization.jsonObject(with: interventionData) as? [String: Any],
                   let success = interventionJson["success"] as? Bool,
                   success {
                    
                    logger.info("✅ Successfully performed intervention for window \(windowId)")
                    
                    // Log the intervention
                    sessionLogger.log(
                        level: .info,
                        message: "Automated rule: \(displayName) - Performed intervention (execution #\(currentCount + 1))",
                        pid: nil
                    )
                    
                    // Increment rule counter
                    RuleCounterManager.shared.incrementCounter(for: ruleName)
                    
                    // Play success sound if enabled
                    if Defaults[.enableRuleSounds] {
                        let soundName = Defaults[.stopAfter25LoopsRuleSound]
                        SoundEngine.playSystemSound(named: soundName)
                    }
                    
                    // Send warning notification if approaching limit
                    if Defaults[.enableRuleNotifications] && currentCount >= 20 {
                        await UserNotificationManager.shared.sendRuleExecutionNotification(
                            ruleName: ruleName,
                            displayName: displayName,
                            executionCount: currentCount + 1,
                            isWarning: true
                        )
                    }
                    
                    // Send notification
                    NotificationCenter.default.post(
                        name: .ruleExecuted,
                        object: nil,
                        userInfo: [
                            "rule": ruleName,
                            "displayName": displayName,
                            "windowId": windowId,
                            "timestamp": Date(),
                            "success": true,
                            "executionCount": currentCount + 1
                        ]
                    )
                    
                    return true
                } else {
                    logger.warning("Failed to perform intervention for window \(windowId)")
                }
            }
        } catch {
            logger.error("Error executing \(displayName) for window \(windowId): \(error)")
        }
        
        return false
    }
    
    // MARK: Private
    
    private let logger = Logger(category: .intervention)
    private let sessionLogger = SessionLogger.shared
    
}

// MARK: - Notification Names

extension Notification.Name {
    static let ruleExecuted = Notification.Name("ruleExecuted")
}
