import AppKit // For pid_t, NSNumber
import AXorcist // For AXPropertyNode, AXAttributeNames, Element
import SwiftUI // For @MainActor, @Published (though props are in main class)

// AXorcist import already includes logging utilities
import Defaults // ADD for Defaults

// Helper to convert [String: String] criteria to [Criterion]
func axConvertStringCriteriaToCriterionArray(_ stringCriteria: [String: String]) -> [Criterion] {
    var criteriaArray: [Criterion] = []
    for (key, value) in stringCriteria {
        // Basic determination of match type for Criterion. AXpector might need more sophisticated logic.
        let matchType: JSONPathHintComponent
            .MatchType = (value.hasPrefix("(") && value.hasSuffix(")") && value.contains("|")) ? .regex : .exact
        criteriaArray.append(Criterion(attribute: key, value: value, matchType: matchType))
    }
    return criteriaArray
}

// Helper to convert [String]? path hints to [JSONPathHintComponent]?
// This is a simplified version. Assumes strings are role names and path hints imply AXRole.
// A more robust parser would be needed if path strings are complex (e.g., "title=Foo[0]").
func axConvertStringPathHintsToComponentArray(_ stringHints: [String]?) -> [JSONPathHintComponent]? {
    guard let hints = stringHints else { return nil }
    return hints.compactMap { hintString in
        // Example: "AXWindow[0]" -> value: "AXWindow", attribute: "AXRole"
        // This simplified logic assumes the string is the ROLE value.
        // For "AXWindow[0]", we might need to extract "AXWindow" as value and use kAXRoleAttribute.
        // If hintString is more complex like "title=My Window", this needs parsing.
        // For now, assume hintString is a value for an implied AXRole attribute for path components.
        // This is a common pattern for simple path hints but might not cover all AXpector cases.

        // Basic parsing for "RoleName[index]" format, extracting RoleName
        var roleName = hintString
        if let range = hintString.range(of: "[") {
            roleName = String(hintString[..<range.lowerBound])
        }
        // Use kAXRoleAttribute for path hints by default if not specified otherwise.
        return JSONPathHintComponent(attribute: AXAttributeNames.kAXRoleAttribute, value: roleName, matchType: .exact)
    }
}

// MARK: - Attribute Editing Methods

extension AXpectorViewModel {
    func prepareAttributeForEditing(node: AXPropertyNode?, attributeKey: String) {
        guard let node else { return }
        self.attributeUpdateStatusMessage = nil
        self.attributeIsCurrentlySettable = false

        Task {
            axInfoLog(
                "Preparing attribute for editing: \(attributeKey) on \(node.displayName)",
                details: [
                    "commandID": AnyCodable("prepareEdit_\(attributeKey)"),
                    "appName": AnyCodable(String(node.pid)),
                ]
            )

            let axElement = Element(node.axElementRef)
            let settable = axElement.isAttributeSettable(named: attributeKey) // Added named: label
            self.attributeIsCurrentlySettable = settable

            if Defaults[.verboseLoggingAxpector] {
                let collectedLogs = axGetLogEntries()
                for logEntry in collectedLogs {
                    axDebugLog(
                        "AXorcist (IsSettable Prep) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: " +
                            "\(logEntry.message) Details: \(logEntry.details ?? [:])"
                    )
                }
                axClearLogs()
            }

            if settable {
                let currentValue = node.attributes[attributeKey]?.value
                var stringValue = ""
                if let val = currentValue {
                    if let str = val as? String {
                        stringValue = str
                    } else if let num = val as? NSNumber {
                        stringValue = num.stringValue
                    }
                    // else if let boolVal = val as? Bool { stringValue = boolVal ? "true" : "false" } // Handle Bool
                    // explicitly if needed
                    else if let anyCodable = val as? AnyCodable {
                        stringValue = String(describing: anyCodable.value)
                    } else {
                        stringValue = String(describing: val)
                    }
                }
                self.editingAttributeKey = attributeKey
                self.editingAttributeValueString = stringValue
                axInfoLog(
                    "Preparing to edit attribute '\(attributeKey)' for node \(node.displayName) with current value: \(stringValue)"
                )
            } else {
                self.attributeUpdateStatusMessage = "Attribute '\(attributeKey)' is not settable."
                axWarningLog("Attribute '\(attributeKey)' on node \(node.displayName) is not settable.")
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if self.attributeUpdateStatusMessage?.contains(attributeKey) == true {
                        self.attributeUpdateStatusMessage = nil
                    }
                }
            }
            axInfoLog("Finished preparing attribute for editing: \(attributeKey) on \(node.displayName)")
        }
    }

    // swiftlint:disable:next function_body_length
    func commitAttributeEdit(node: AXPropertyNode?, originalAttributeKey: String?) {
        guard let node, let key = originalAttributeKey ?? editingAttributeKey else {
            attributeUpdateStatusMessage = "Error: Node or attribute key missing for commit."
            axWarningLog("Attempted to commit edit for node or key missing.")
            clearAttributeEditingState()
            Task {
                try? await Task.sleep(for: .seconds(3)); if self.attributeUpdateStatusMessage?
                    .contains("missing") == true { self.attributeUpdateStatusMessage = nil }
            }
            return
        }

        guard attributeIsCurrentlySettable else {
            attributeUpdateStatusMessage = "Error: Attribute '\(key)' is not settable or status unknown."
            axWarningLog("Attempted to commit edit for non-settable attribute '\(key)' on node \(node.displayName)")
            clearAttributeEditingState()
            Task {
                try? await Task.sleep(for: .seconds(3)); if self.attributeUpdateStatusMessage?
                    .contains(key) == true { self.attributeUpdateStatusMessage = nil }
            }
            return
        }

        axInfoLog(
            "Committing edit for attribute '\(key)' on node \(node.displayName) with new value: \(self.editingAttributeValueString)"
        )

        Task {
            let appIdentifier = String(node.pid)
            axInfoLog(
                "Committing attribute edit: \(key) on \(node.displayName)",
                details: ["commandID": AnyCodable("commitEdit_\(key)"), "appName": AnyCodable(appIdentifier)]
            )

            var stringCriteria: [String: String] = [:]
            if let role = node.attributes[AXAttributeNames.kAXRoleAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = node.attributes[AXAttributeNames.kAXTitleAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if stringCriteria
                .isEmpty { stringCriteria[AXAttributeNames.kAXTitleAttribute] = node.displayName } // Fallback

            let criteriaForLocator = axConvertStringCriteriaToCriterionArray(stringCriteria)
            let pathHintsForLocator = axConvertStringPathHintsToComponentArray(node.fullPathArrayForLocator)

            let locator = Locator(criteria: criteriaForLocator, rootElementPathHint: pathHintsForLocator)

            let command = PerformActionCommand(
                appIdentifier: appIdentifier,
                locator: locator,
                action: key,
                value: AnyCodable(self.editingAttributeValueString),
                maxDepthForSearch: AXMiscConstants.defaultMaxDepthSearch
            )
            let response = axorcist.handlePerformAction(command: command)

            if Defaults[.verboseLoggingAxpector] {
                let collectedLogs = axGetLogEntries()
                for logEntry in collectedLogs {
                    axDebugLog(
                        "AXorcist (SetAttribute) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: " +
                            "\(logEntry.message) Details: \(logEntry.details ?? [:])"
                    )
                }
                axClearLogs()
            }

            if response.error == nil, let responseData = response.payload?.value as? PerformResponse,
               responseData.success
            {
                self.attributeUpdateStatusMessage = "Attribute '\(key)' updated successfully."
                axInfoLog("Successfully updated attribute '\(key)' for node \(node.displayName)")
                Task { await refreshSelectedNodeAttributes(node: node) }
            } else {
                let errorMessage = response.error?.message ?? "Failed to update attribute '\(key)'"
                self.attributeUpdateStatusMessage = "Failed to update attribute '\(key)': \(errorMessage)."
                axErrorLog("Failed to update attribute '\(key)' for node \(node.displayName). Error: \(errorMessage)")
            }
            clearAttributeEditingState()

            Task {
                try? await Task.sleep(for: .seconds(4))
                if self.attributeUpdateStatusMessage?.contains(key) == true { self.attributeUpdateStatusMessage = nil }
            }
            axInfoLog("Finished committing attribute edit: \(key) on \(node.displayName)")
        }
    }

    func cancelAttributeEdit() {
        axInfoLog("Cancelled attribute edit for key \(self.editingAttributeKey ?? "nil")")
        clearAttributeEditingState()
    }

    private func clearAttributeEditingState() {
        editingAttributeKey = nil
        editingAttributeValueString = ""
        attributeIsCurrentlySettable = false
    }

    private func refreshSelectedNodeAttributes(node: AXPropertyNode) async {
        axInfoLog("Refreshing attributes for node \(node.displayName)")
        let appIdentifier = String(node.pid)
        axInfoLog(
            "Refreshing attributes for node: \(node.displayName)",
            details: [
                "commandID": AnyCodable("refreshNodeAttrs_\(node.id.uuidString.prefix(8))"),
                "appName": AnyCodable(appIdentifier),
            ]
        )

        var stringCriteria: [String: String] = [:]
        if let role = node.attributes[AXAttributeNames.kAXRoleAttribute]?
            .value as? String { stringCriteria[AXAttributeNames.kAXRoleAttribute] = role }
        if let title = node.attributes[AXAttributeNames.kAXTitleAttribute]?
            .value as? String { stringCriteria[AXAttributeNames.kAXTitleAttribute] = title }
        if let identifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?
            .value as? String { stringCriteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
        if stringCriteria.isEmpty { stringCriteria[AXAttributeNames.kAXTitleAttribute] = node.displayName } // Fallback

        let criteriaForLocator = axConvertStringCriteriaToCriterionArray(stringCriteria)
        let pathHintsForLocator = axConvertStringPathHintsToComponentArray(node.fullPathArrayForLocator)

        let locator = Locator(criteria: criteriaForLocator, rootElementPathHint: pathHintsForLocator)

        let queryCommand = QueryCommand(
            appIdentifier: appIdentifier,
            locator: locator,
            attributesToReturn: AXpectorViewModel.defaultFetchAttributes,
            maxDepthForSearch: 0,
            includeChildrenBrief: nil
        )
        let response = axorcist.handleQuery(command: queryCommand, maxDepth: 0)

        if Defaults[.verboseLoggingAxpector] {
            let collectedLogs = axGetLogEntries()
            for logEntry in collectedLogs {
                axDebugLog(
                    "AXorcist (RefreshNode) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: " +
                        "\(logEntry.message) Details: \(logEntry.details ?? [:])"
                )
            }
            axClearLogs()
        }

        if response.error == nil, let axElementData = response.payload?.value as? AXElement {
            if let newAttrs = axElementData.attributes {
                node.attributes = newAttrs
                node.role = newAttrs[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? node.role
                node.title = newAttrs[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? node.title
                node.descriptionText = newAttrs[AXAttributeNames.kAXDescriptionAttribute]?.value as? String ?? node
                    .descriptionText
                node.value = newAttrs[AXAttributeNames.kAXValueAttribute]?.value as? String ?? node.value
                axInfoLog("Refreshed attributes for node \(node.displayName).")
            } else {
                axWarningLog(
                    "No attributes returned on refresh for node \(node.displayName). Node attributes not changed."
                )
            }
        } else {
            axErrorLog(
                "Failed to refresh attributes for node \(node.displayName): \(response.error?.message ?? "Unknown error")"
            )
        }
        axInfoLog("Finished refreshing attributes for node: \(node.displayName)")
    }

    func fetchSettableStatusForAttributeDisplay(node: AXPropertyNode, attributeKey: String) async -> String {
        if node.id != cachedNodeIDForSettableStatus {
            attributeSettableStatusCache.removeAll()
            cachedNodeIDForSettableStatus = node.id
        }
        if let cachedStatus = attributeSettableStatusCache[attributeKey] { return cachedStatus ? " (W)" : "" }

        axInfoLog(
            "Fetching settable status for attribute: \(attributeKey) on \(node.displayName)",
            details: [
                "commandID": AnyCodable("fetchSettableStatus_\(attributeKey)"),
                "appName": AnyCodable(String(node.pid)),
            ]
        )

        let axElement = Element(node.axElementRef)
        let settable = axElement.isAttributeSettable(named: attributeKey) // Added named: label

        if Defaults[.verboseLoggingAxpector] {
            let collectedLogs = axGetLogEntries()
            for logEntry in collectedLogs {
                axDebugLog(
                    "AXorcist (IsSettable Display) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: " +
                        "\(logEntry.message) Details: \(logEntry.details ?? [:])"
                )
            }
            axClearLogs()
        }

        if node.id == cachedNodeIDForSettableStatus { attributeSettableStatusCache[attributeKey] = settable }
        axInfoLog("Finished fetching settable status for attribute: \(attributeKey) on \(node.displayName)")
        return settable ? " (W)" : ""
    }

    // Method to be called by UI for navigation
    func navigateToElementInTree(axElementRef: AXUIElement, currentAppPID: pid_t) {
        axInfoLog("Attempting to navigate to element: \(axElementRef)")
        // First, ensure the main tree (accessibilityTree) is for the correct application.
        // If selectedApplicationPID is different from currentAppPID, this navigation might be cross-app or context is
        // wrong.
        // This logic assumes we are navigating within the currently selected/focused app context.
        guard let appTreeRoot = self.accessibilityTree.first(where: { $0.pid == currentAppPID }) else {
            axWarningLog("Cannot navigate: No tree loaded for PID \(currentAppPID).")
            // Optionally, inform the user or try to load the tree for currentAppPID if it differs from
            // selectedApplicationPID.
            return
        }

        if let targetNode = findNodeByAXElement(axElementRef, in: [appTreeRoot]) {
            axInfoLog("Navigating to node: \(targetNode.displayName)")
            self.selectedNode = targetNode // This will trigger UI update for selection
            if isFocusTrackingModeActive {
                self.temporarilySelectedNodeIDByFocus = targetNode.id // Update focus highlight as well
            } else if isHoverModeActive {
                // If hover is active, navigating might be confusing. Consider behavior.
                // For now, let selection take precedence.
                self.temporarilySelectedNodeIDByHover = nil
            }
            _ = expandParents(for: targetNode.id, in: self.accessibilityTree) // Ensure visibility in the main tree
            // Highlight for selection is handled by selectedNode.didSet calling updateHighlightForNode
        } else {
            axWarningLog("Element \(axElementRef) not found in current tree for PID \(currentAppPID).")
            // swiftlint:disable:next todo
            // TODO: Consider targeted fetch for this element if not found, then select.
            // For now, just log. User might need to expand tree or refresh.
            self.actionStatusMessage = "Navigation target not found in current tree view."
            Task { try? await Task.sleep(for: .seconds(3)); self.actionStatusMessage = nil }
        }
        // CFRelease(axElementRef) // Caller (AttributeRowView) should not pass ownership if it obtained a copy for this
        // call.
        // This method receives a ref, doesn't own it unless it copies it.
    }

    @MainActor
    func fetchAttributeUIDisplayInfo(
        for node: AXPropertyNode,
        attributeKey: String,
        attributeValue: AnyCodable?
    ) -> AttributeDisplayInfo {
        axDebugLog("AXpectorVM.fetchAttributeUIDisplayInfo for \(attributeKey) on node: \(node.id)")

        let tempElement = Element(node.axElementRef)
        let isSettableStatus = tempElement.isAttributeSettable(named: attributeKey)
        let settableString = isSettableStatus ? " (W)" : ""

        var displayStr = "<Unable to display>"
        var navRef: AXUIElement?

        if let val = attributeValue?.value {
            if let ref = tempElement.attribute(Attribute<AXUIElement>(attributeKey)) {
                displayStr = Element(ref).briefDescription()
                navRef = ref
            } else if let arr = tempElement.attribute(Attribute<[AXUIElement]>(attributeKey)), !arr.isEmpty {
                let firstElementPreview = Element(arr[0]).briefDescription()
                displayStr = "[\(firstElementPreview), ...] (count: \(arr.count))"
                navRef = arr[0]
            } else if let str = val as? String {
                displayStr = "\"\(str)\""
            } else if let num = val as? NSNumber {
                displayStr = num.stringValue
            } else if let boolVal = val as? Bool {
                displayStr = boolVal ? "true" : "false"
            } else {
                displayStr = String(describing: val)
            }
        } else {
            displayStr = "<n/a>"
        }

        let info = AttributeDisplayInfo(
            displayString: displayStr,
            isSettable: isSettableStatus,
            settableDisplayString: settableString,
            navigatableElementRef: navRef
        )

        return info
    }
}
