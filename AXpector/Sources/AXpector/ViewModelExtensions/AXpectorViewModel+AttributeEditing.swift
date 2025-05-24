import SwiftUI // For @MainActor, @Published (though props are in main class)
import AXorcist // For AXPropertyNode, AXAttributeNames, Element
import AppKit // For pid_t, NSNumber
// AXorcist import already includes logging utilities
import Defaults // ADD for Defaults

// MARK: - Attribute Editing Methods
extension AXpectorViewModel {
    func prepareAttributeForEditing(node: AXPropertyNode?, attributeKey: String) {
        guard let node = node else { return }
        self.attributeUpdateStatusMessage = nil 
        self.attributeIsCurrentlySettable = false 

        Task {
            await GlobalAXLogger.shared.updateOperationDetails(commandID: "prepareEdit_\(attributeKey)", appName: String(node.pid))

            let axElement = Element(node.axElementRef)
            let settable = axElement.isAttributeSettable(named: attributeKey) // Added named: label
            self.attributeIsCurrentlySettable = settable 

            if Defaults[.verboseLogging_axpector] {
                let collectedLogs = await axGetLogEntries()
                for logEntry in collectedLogs {
                    axDebugLog("AXorcist (IsSettable Prep) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \(logEntry.message) Details: \(logEntry.details ?? [:])")
                }
                await axClearLogs()
            }

            if settable {
                let currentValue = node.attributes[attributeKey]?.value
                var stringValue = ""
                if let val = currentValue {
                    if let str = val as? String { stringValue = str }
                    else if let num = val as? NSNumber { stringValue = num.stringValue }
                    // else if let boolVal = val as? Bool { stringValue = boolVal ? "true" : "false" } // Handle Bool explicitly if needed
                    else if let anyCodable = val as? AnyCodable { stringValue = String(describing: anyCodable.value) }
                    else { stringValue = String(describing: val) }
                }
                self.editingAttributeKey = attributeKey
                self.editingAttributeValueString = stringValue
                axInfoLog("Preparing to edit attribute '\(attributeKey)' for node \(node.displayName) with current value: \(stringValue)")
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
            await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
        }
    }

    func commitAttributeEdit(node: AXPropertyNode?, originalAttributeKey: String?) {
        guard let node = node, let key = originalAttributeKey ?? editingAttributeKey else {
            attributeUpdateStatusMessage = "Error: Node or attribute key missing for commit."
            axWarningLog("Attempted to commit edit for node or key missing.")
            clearAttributeEditingState()
            Task { try? await Task.sleep(for: .seconds(3)); if self.attributeUpdateStatusMessage?.contains("missing") == true {self.attributeUpdateStatusMessage = nil} }
            return
        }
        
        guard attributeIsCurrentlySettable else {
            attributeUpdateStatusMessage = "Error: Attribute '\(key)' is not settable or status unknown."
            axWarningLog("Attempted to commit edit for non-settable attribute '\(key)' on node \(node.displayName)")
            clearAttributeEditingState()
            Task { try? await Task.sleep(for: .seconds(3)); if self.attributeUpdateStatusMessage?.contains(key) == true {self.attributeUpdateStatusMessage = nil} }
            return
        }

        axInfoLog("Committing edit for attribute '\(key)' on node \(node.displayName) with new value: \(self.editingAttributeValueString)")

        Task {
            let appIdentifier = String(node.pid)
            await GlobalAXLogger.shared.updateOperationDetails(commandID: "commitEdit_\(key)", appName: appIdentifier)
            
            // Construct Locator for node
            var criteria: [String: String] = [:]
            if let role = node.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String { criteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = node.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String { criteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String { criteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if criteria.isEmpty { criteria[AXAttributeNames.kAXTitleAttribute] = node.displayName } // Fallback

            let locator = Locator(criteria: criteria, rootElementPathHint: node.fullPathArrayForLocator)
            
            // Value needs to be parsed into its actual type if possible, not just string.
            // For now, sending as string; AXorcist side might need to handle parsing.
            // A more robust solution would involve knowing the attribute's type.
            let response = await axorcist.handlePerformAction(
                for: appIdentifier,
                locator: locator,
                actionName: key, // The attribute name is the "action" for setting
                actionValue: AnyCodable(self.editingAttributeValueString) // Send new value
            )
            
            if Defaults[.verboseLogging_axpector] {
                let collectedLogs = await axGetLogEntries()
                for logEntry in collectedLogs {
                    axDebugLog("AXorcist (SetAttribute) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \(logEntry.message) Details: \(logEntry.details ?? [:])")
                }
                await axClearLogs()
            }

            if response.error == nil, let responseData = response.data?.value as? PerformResponse, responseData.success {
                self.attributeUpdateStatusMessage = "Attribute '\(key)' updated successfully."
                axInfoLog("Successfully updated attribute '\(key)' for node \(node.displayName)")
                Task { await refreshSelectedNodeAttributes(node: node) }
            } else {
                let errorMessage = response.error ?? "Failed to update attribute '\(key)'"
                self.attributeUpdateStatusMessage = "Failed to update attribute '\(key)': \(errorMessage)."
                axErrorLog("Failed to update attribute '\(key)' for node \(node.displayName). Error: \(errorMessage)")
            }
            clearAttributeEditingState()
            
            Task {
                try? await Task.sleep(for: .seconds(4))
                if self.attributeUpdateStatusMessage?.contains(key) == true { self.attributeUpdateStatusMessage = nil }
            }
            await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
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
        await GlobalAXLogger.shared.updateOperationDetails(commandID: "refreshNodeAttrs_\(node.id.uuidString.prefix(8))", appName: appIdentifier)

        // Construct Locator for the node
        var criteria: [String: String] = [:]
        if let role = node.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String { criteria[AXAttributeNames.kAXRoleAttribute] = role }
        if let title = node.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String { criteria[AXAttributeNames.kAXTitleAttribute] = title }
        if let identifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String { criteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
        if criteria.isEmpty { criteria[AXAttributeNames.kAXTitleAttribute] = node.displayName } // Fallback
        let locator = Locator(criteria: criteria, rootElementPathHint: node.fullPathArrayForLocator)

        let response = await axorcist.handleQuery(
            for: appIdentifier,
            locator: locator,
            pathHint: nil,
            maxDepth: 0,
            requestedAttributes: AXpectorViewModel.defaultFetchAttributes,
            outputFormat: .smart
        )

        if Defaults[.verboseLogging_axpector] {
            let collectedLogs = await axGetLogEntries()
            for logEntry in collectedLogs {
                axDebugLog("AXorcist (RefreshNode) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \(logEntry.message) Details: \(logEntry.details ?? [:])")
            }
            await axClearLogs()
        }

        if response.error == nil, let axElementData = response.data?.value as? AXElement { // AXElement is from CommandModels
            if let newAttrs = axElementData.attributes {
                node.attributes = newAttrs // Update the node's attributes directly
                // Update individual @Published properties if they are derived from attributes
                node.role = newAttrs[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? node.role
                node.title = newAttrs[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? node.title
                node.descriptionText = newAttrs[AXAttributeNames.kAXDescriptionAttribute]?.value as? String ?? node.descriptionText
                node.value = newAttrs[AXAttributeNames.kAXValueAttribute]?.value as? String ?? node.value
                // Assuming actions are also part of AXElement or a separate field in HandlerResponse if needed.
                // For now, actions are not directly updated here from handleQuery response.
                axInfoLog("Refreshed attributes for node \(node.displayName).")
            } else {
                axWarningLog("No attributes returned on refresh for node \(node.displayName). Node attributes not changed.")
            }
        } else {
            axErrorLog("Failed to refresh attributes for node \(node.displayName): \(response.error ?? "Unknown error")")
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
    }

    func fetchSettableStatusForAttributeDisplay(node: AXPropertyNode, attributeKey: String) async -> String {
        if node.id != cachedNodeIDForSettableStatus {
            attributeSettableStatusCache.removeAll()
            cachedNodeIDForSettableStatus = node.id
        }
        if let cachedStatus = attributeSettableStatusCache[attributeKey] { return cachedStatus ? " (W)" : "" }

        await GlobalAXLogger.shared.updateOperationDetails(commandID: "fetchSettableStatus_\(attributeKey)", appName: String(node.pid))
        
        let axElement = Element(node.axElementRef)
        let settable = axElement.isAttributeSettable(named: attributeKey) // Added named: label
        
        if Defaults[.verboseLogging_axpector] {
            let collectedLogs = await axGetLogEntries()
            for logEntry in collectedLogs {
                axDebugLog("AXorcist (IsSettable Display) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \(logEntry.message) Details: \(logEntry.details ?? [:])")
            }
            await axClearLogs()
        }
        
        if node.id == cachedNodeIDForSettableStatus { attributeSettableStatusCache[attributeKey] = settable }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
        return settable ? " (W)" : ""
    }

    // Method to be called by UI for navigation
    func navigateToElementInTree(axElementRef: AXUIElement, currentAppPID: pid_t) {
        axInfoLog("Attempting to navigate to element: \(axElementRef)")
        // First, ensure the main tree (accessibilityTree) is for the correct application.
        // If selectedApplicationPID is different from currentAppPID, this navigation might be cross-app or context is wrong.
        // This logic assumes we are navigating within the currently selected/focused app context.
        guard let appTreeRoot = self.accessibilityTree.first(where: { $0.pid == currentAppPID }) else {
            axWarningLog("Cannot navigate: No tree loaded for PID \(currentAppPID).")
            // Optionally, inform the user or try to load the tree for currentAppPID if it differs from selectedApplicationPID.
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
            // TODO: Consider targeted fetch for this element if not found, then select.
            // For now, just log. User might need to expand tree or refresh.
            self.actionStatusMessage = "Navigation target not found in current tree view."
            Task { try? await Task.sleep(for: .seconds(3)); self.actionStatusMessage = nil }
        }
        // CFRelease(axElementRef) // Caller (AttributeRowView) should not pass ownership if it obtained a copy for this call.
                                 // This method receives a ref, doesn't own it unless it copies it.
    }

    // RESTORED FUNCTION
    internal func fetchAttributeUIDisplayInfo(node: AXPropertyNode, attributeKey: String, rawAttributeValue: AnyCodable?) async -> AttributeDisplayInfo {
        if node.id != self.cachedNodeIDForDisplayInfo { 
            self.attributeDisplayInfoCache.removeAll() 
            self.cachedNodeIDForDisplayInfo = node.id 
        }
        if let cachedInfo = self.attributeDisplayInfoCache[attributeKey] {
            return cachedInfo
        }

        let tempElement = Element(node.axElementRef)
        let valueType = tempElement.getValueType(forAttribute: attributeKey) 
        let isSettableStatus = tempElement.isAttributeSettable(named: attributeKey)
        let settableString = isSettableStatus ? " (W)" : "" 

        var displayStr = "<Error fetching value>"
        var navRef: AXUIElement? = nil

        // Simplified display logic from original AttributeRowView intentions
        if let val = rawAttributeValue?.value {
            if valueType == .axElement, let ref = tempElement.attribute(Attribute<AXUIElement>(attributeKey)) {
                displayStr = axorcist.getPreviewString(forElement: ref) ?? "<AXUIElement>"
                navRef = ref // Keep for navigation
            } else if valueType == .arrayOfAXElements, let arr = tempElement.attribute(Attribute<[AXUIElement]>(attributeKey)), !arr.isEmpty {
                let firstElementPreview = axorcist.getPreviewString(forElement: arr[0]) ?? "<AXUIElement>"
                displayStr = "[\(firstElementPreview), ...] (count: \(arr.count))"
                navRef = arr[0] // Keep first for navigation
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
            valueType: valueType,
            isSettable: isSettableStatus,
            settableDisplayString: settableString,
            navigatableElementRef: navRef
        )
        
        if node.id == self.cachedNodeIDForDisplayInfo { // Check again in case of race or if node.id changed
             self.attributeDisplayInfoCache[attributeKey] = info
        }
        return info
    }
} 