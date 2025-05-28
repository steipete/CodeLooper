import AXorcist
import Defaults
import Diagnostics
import Foundation

@MainActor
class InterventionStateChecker {
    // MARK: Lifecycle

    init(
        axorcist: AXorcist,
        locatorManager: LocatorManager,
        instanceStateManager: CursorInstanceStateManager,
        monitor: CursorMonitor?
    ) {
        self.axorcist = axorcist
        self.locatorManager = locatorManager
        self.instanceStateManager = instanceStateManager
        self.monitor = monitor
    }

    // MARK: Internal

    func checkBasicStates(for pid: pid_t) -> CursorInterventionEngine.InterventionType? {
        // Check if manually paused
        if self.instanceStateManager.isManuallyPaused(pid: pid) {
            return .manualPause
        }

        // Check if monitoring is globally paused
        if let monitor = self.monitor, !monitor.isMonitoringActive {
            return .monitoringPaused
        }

        // Check for consecutive recovery failures
        if self.instanceStateManager.getConsecutiveRecoveryFailures(for: pid) >= InterventionConstants
            .maxConsecutiveRecoveryFailures
        {
            return .unrecoverableError
        }

        // Check if intervention limit reached
        if self.instanceStateManager.getAutomaticInterventions(for: pid) >= InterventionConstants
            .maxAutomaticInterventions
        {
            return .interventionLimitReached
        }

        return nil
    }

    func performAXQueries(for pid: pid_t) async -> CursorInterventionEngine.InterventionType? {
        // Check for positive working state
        if let positiveState = await checkPositiveWorkingState(for: pid) {
            return positiveState
        }

        // Check for error messages
        if let errorState = await checkErrorMessages(for: pid) {
            return errorState
        }

        // Check sidebar activity if enabled
        if let sidebarState = await checkSidebarActivity(for: pid) {
            return sidebarState
        }

        // Check for connection issues if enabled
        if let connectionState = await checkConnectionIssues(for: pid) {
            return connectionState
        }

        return nil
    }

    func checkPositiveWorkingState(for pid: pid_t) async -> CursorInterventionEngine.InterventionType? {
        guard let generatingIndicatorLocator = await self.locatorManager.getLocator(
            for: .generatingIndicatorText,
            pid: pid
        ) else { return nil }

        let queryCommand = QueryCommand(
            appIdentifier: nil,
            locator: generatingIndicatorLocator,
            attributesToReturn: nil,
            maxDepthForSearch: 5
        )
        let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)

        if let axData = response.payload?.value {
            let textContent = getTextFromAXElement(AnyCodable(axData))
            if !textContent.isEmpty {
                self.logger.info("PID \(String(describing: pid)): Generating indicator found: \(textContent)")
                if InterventionConstants.positiveWorkKeywords
                    .contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) })
                {
                    return .positiveWorkingState
                }
            }
        }
        return nil
    }

    func checkErrorMessages(for pid: pid_t) async -> CursorInterventionEngine.InterventionType? {
        guard let errorMessageLocator = await self.locatorManager.getLocator(for: .errorMessagePopup, pid: pid) else {
            return nil
        }

        let queryCommand = QueryCommand(
            appIdentifier: nil,
            locator: errorMessageLocator,
            attributesToReturn: nil,
            maxDepthForSearch: 5
        )
        let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)

        if let axData = response.payload?.value {
            let textContent = getTextFromAXElement(AnyCodable(axData))
            if InterventionConstants.errorIndicatingKeywords
                .contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) })
            {
                return .generalError
            }
        }
        return nil
    }

    func checkSidebarActivity(for pid: pid_t) async -> CursorInterventionEngine.InterventionType? {
        guard let sidebarLocator = await self.locatorManager.getLocator(for: .sidebarActivityArea, pid: pid)
        else {
            return nil
        }

        let queryCommand = QueryCommand(
            appIdentifier: nil,
            locator: sidebarLocator,
            attributesToReturn: nil,
            maxDepthForSearch: 5
        )
        let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)

        if let axData = response.payload?.value {
            let sidebarTextRepresentation = getTextualRepresentation(
                for: AnyCodable(axData),
                depth: 0,
                maxDepth: 1
            )
            if !sidebarTextRepresentation.isEmpty {
                self.logger.info(
                    "PID \(String(describing: pid)): Sidebar activity detected: \(sidebarTextRepresentation.prefix(200))..."
                )
                return .sidebarActivityDetected
            }
        }
        return nil
    }

    func checkConnectionIssues(for pid: pid_t) async -> CursorInterventionEngine.InterventionType? {
        guard Defaults[.enableConnectionIssuesRecovery],
              let connectionErrorLocator = await self.locatorManager.getLocator(
                  for: .connectionErrorIndicator,
                  pid: pid
              )
        else {
            return nil
        }

        let queryCommand = QueryCommand(
            appIdentifier: nil,
            locator: connectionErrorLocator,
            attributesToReturn: nil,
            maxDepthForSearch: 5
        )
        let response = self.axorcist.handleQuery(command: queryCommand, maxDepth: 5)

        if let axData = response.payload?.value {
            let textContent = getTextFromAXElement(AnyCodable(axData))
            if InterventionConstants.connectionIssueKeywords
                .contains(where: { keyword in textContent.localizedCaseInsensitiveContains(keyword) })
            {
                return .connectionIssue
            }
        }
        return nil
    }

    func checkStuckTimeout(for pid: pid_t) -> CursorInterventionEngine.InterventionType? {
        guard Defaults[.enableCursorStopsRecovery],
              let lastActive = self.instanceStateManager.getLastActivityTimestamp(for: pid)
        else {
            return nil
        }

        let timeoutThreshold = InterventionConstants.stuckDetectionTimeout
        if Date().timeIntervalSince(lastActive) > timeoutThreshold {
            return .generalError
        }

        return nil
    }

    // MARK: Private

    private let axorcist: AXorcist
    private let locatorManager: LocatorManager
    private let instanceStateManager: CursorInstanceStateManager
    private let monitor: CursorMonitor?
    private let logger = Logger(category: .interventionEngine)

    // MARK: - Helper Methods

    private func getTextFromAXElement(_ axData: AnyCodable?) -> String {
        guard let axData else { return "" }

        // Try to extract text from Element
        if let element = axData.value as? Element {
            if let attributes = element.attributes,
               let valueAttr = attributes[AXAttributeNames.kAXValueAttribute],
               let text = valueAttr.value as? String
            {
                return text
            }
        }

        // Try direct string extraction
        if let text = axData.value as? String {
            return text
        }

        // Try array of elements
        if let elements = axData.value as? [Element] {
            return elements.compactMap { element in
                if let attributes = element.attributes,
                   let valueAttr = attributes[AXAttributeNames.kAXValueAttribute],
                   let text = valueAttr.value as? String
                {
                    return text
                }
                return nil
            }.joined(separator: " ")
        }

        return ""
    }

    private func getTextualRepresentation(for axData: AnyCodable?, depth: Int, maxDepth: Int) -> String {
        guard let axData, depth <= maxDepth else { return "" }

        var result = ""

        if let element = axData.value as? Element {
            if let attributes = element.attributes {
                for (key, attribute) in attributes {
                    if key == AXAttributeNames.kAXValueAttribute || key == AXAttributeNames.kAXTitleAttribute {
                        if let text = attribute.value as? String {
                            result += text + " "
                        }
                    }
                }
            }
        } else if let elements = axData.value as? [Element] {
            for element in elements {
                result += getTextualRepresentation(for: AnyCodable(element), depth: depth + 1, maxDepth: maxDepth)
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
