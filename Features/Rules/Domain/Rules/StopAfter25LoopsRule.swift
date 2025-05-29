import AppKit
import Defaults
import Diagnostics
import Foundation
@preconcurrency import UserNotifications

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

    // MARK: Internal

    /// Execute the rule for a specific window
    // swiftlint:disable:next function_body_length
    func execute(windowId: String, jsHookService: JSHookService) async -> Bool {
        do {
            let currentCount = RuleCounterManager.shared.getCount(for: ruleName)
            
            guard currentCount < 25 else {
                await handleRuleLimit(currentCount: currentCount)
                return false
            }

            // Check if rule action is needed
            let checkCommand: [String: Any] = ["type": "checkRuleNeeded"]
            let checkResult = try await jsHookService.sendCommand(checkCommand, to: windowId)

            // Parse the result
            guard let data = checkResult.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ruleNeeded = json["ruleNeeded"] as? Bool
            else {
                logger.warning("Failed to parse rule check result for window \(windowId)")
                return false
            }

            if ruleNeeded {
                logger.info("🔄 Rule action needed detected for window \(windowId)")

                // Perform the rule action
                let ruleCommand: [String: Any] = ["type": "performRule"]
                let ruleResult = try await jsHookService.sendCommand(ruleCommand, to: windowId)

                // Parse rule result
                if let ruleData = ruleResult.data(using: .utf8),
                   let ruleJson = try? JSONSerialization.jsonObject(with: ruleData) as? [String: Any],
                   let success = ruleJson["success"] as? Bool,
                   success
                {
                    logger.info("✅ Successfully performed rule action for window \(windowId)")

                    // Log the rule action
                    sessionLogger.log(
                        level: .info,
                        message: "Automated rule: \(displayName) - Performed rule action (execution #\(currentCount + 1))",
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
                    if Defaults[.enableRuleNotifications], currentCount >= 20 {
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
                            "executionCount": currentCount + 1,
                        ]
                    )

                    return true
                } else {
                    logger.warning("Failed to perform rule action for window \(windowId)")
                }
            }
        } catch {
            logger.error("Error executing \(displayName) for window \(windowId): \(error)")
        }

        return false
    }

    // MARK: Private

    private let logger = Logger(category: .rules)
    private let sessionLogger = SessionLogger.shared
    
    /// Handle when rule limit is reached
    private func handleRuleLimit(currentCount: Int) async {
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
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ruleExecuted = Notification.Name("ruleExecuted")
}
