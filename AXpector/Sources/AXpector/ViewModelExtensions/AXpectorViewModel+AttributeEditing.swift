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

            let axElement = AXorcist.Element(node.axElementRef)
            let settable = axElement.isAttributeSettable(attributeKey) // Uses GlobalAXLogger internally
            self.attributeIsCurrentlySettable = settable 

            if Defaults[.verboseLogging] {
                let collectedLogs = await GlobalAXLogger.shared.getLogs()
                for logEntry in collectedLogs {
                    axDebugLog("AXorcist (IsSettable Prep) Log: \(GlobalAXLogger.formatEntriesAsText([logEntry], includeTimestamps: true, includeLevels: true, includeDetails: true).first ?? "")")
                }
                await GlobalAXLogger.shared.clearLogs()
            }

            if settable {
                let currentValue = node.attributes[attributeKey]?.value
                var stringValue = ""
                if let val = currentValue {
                    if let str = val as? String { stringValue = str }
                    else if let num = val as? NSNumber { stringValue = num.stringValue }
                    // else if let boolVal = val as? Bool { stringValue = boolVal ? "true" : "false" } // Handle Bool explicitly if needed
                    else if let anyCodable = val as? AnyCodable { stringValue = String(describing: anyCodable.value ?? "") }
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

        axInfoLog("Committing edit for attribute '\(key)' on node \(node.displayName) with new value: \(editingAttributeValueString)")

        Task {
            let appIdentifier = String(node.pid)
            await GlobalAXLogger.shared.updateOperationDetails(commandID: "commitEdit_\(key)", appName: appIdentifier)
            
            // Construct Locator for node
            var criteria: [String: String] = [:]
            if let role = node.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String { criteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = node.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String { criteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String { criteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if criteria.isEmpty { criteria[AXAttributeNames.kAXTitleAttribute] = node.displayName } // Fallback

            let locator = Locator(criteria: criteria, root_element_path_hint: node.fullPathArrayForLocator)
            
            // Value needs to be parsed into its actual type if possible, not just string.
            // For now, sending as string; AXorcist side might need to handle parsing.
            // A more robust solution would involve knowing the attribute's type.
            let response = await axorcist.handlePerformAction(
                for: appIdentifier,
                locator: locator,
                actionName: key, // The attribute name is the "action" for setting
                actionValue: AnyCodable(editingAttributeValueString) // Send new value
            )
            
            if Defaults[.verboseLogging] {
                let collectedLogs = await GlobalAXLogger.shared.getLogs()
                for logEntry in collectedLogs {
                    axDebugLog("AXorcist (SetAttribute) Log: \(GlobalAXLogger.formatEntriesAsText([logEntry], includeTimestamps: true, includeLevels: true, includeDetails: true).first ?? "")")
                }
                await GlobalAXLogger.shared.clearLogs()
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
        axInfoLog("Cancelled attribute edit for key \(editingAttributeKey ?? "nil")")
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
        let locator = Locator(criteria: criteria, root_element_path_hint: node.fullPathArrayForLocator)

        let response = await axorcist.handleQuery(
            for: appIdentifier,
            locator: locator,
            maxDepth: 0, // We only want attributes of this specific element, not children
            requestedAttributes: AXpectorViewModel.defaultFetchAttributes // Or specific set
        )

        if Defaults[.verboseLogging] {
            let collectedLogs = await GlobalAXLogger.shared.getLogs()
            for logEntry in collectedLogs {
                axDebugLog("AXorcist (RefreshNode) Log: \(GlobalAXLogger.formatEntriesAsText([logEntry], includeTimestamps: true, includeLevels: true, includeDetails: true).first ?? "")")
            }
            await GlobalAXLogger.shared.clearLogs()
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
        
        let axElement = AXorcist.Element(node.axElementRef)
        let settable = axElement.isAttributeSettable(attributeKey) // Uses GlobalAXLogger internally
        
        if Defaults[.verboseLogging] {
            let collectedLogs = await GlobalAXLogger.shared.getLogs()
            for logEntry in collectedLogs {
                axDebugLog("AXorcist (IsSettable Display) Log: \(GlobalAXLogger.formatEntriesAsText([logEntry], includeTimestamps: true, includeLevels: true, includeDetails: true).first ?? "")")
            }
            await GlobalAXLogger.shared.clearLogs()
        }
        
        if node.id == cachedNodeIDForSettableStatus { attributeSettableStatusCache[attributeKey] = settable }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
        return settable ? " (W)" : ""
    }

    // New struct to hold rich display info for an attribute
    struct AttributeDisplayInfo {
        let displayString: String
        let valueType: AXAttributeValueType
        let isSettable: Bool
        let settableDisplayString: String // e.g., " (W)" or ""
        let navigatableElementRef: AXUIElement? // Only non-nil if valueType is .axElement
        // For .arrayOfAXElements, we might need a different structure or handle navigation separately
    }

    // Cache for AttributeDisplayInfo
    private var attributeDisplayInfoCache: [String: AttributeDisplayInfo] = [:] // Keyed by attributeName
    private var cachedNodeIDForDisplayInfo: AXPropertyNode.ID? = nil

    func fetchAttributeUIDisplayInfo(node: AXPropertyNode, attributeKey: String, rawAttributeValue: AnyCodable?) async -> AttributeDisplayInfo {
        if node.id != cachedNodeIDForDisplayInfo {
            attributeDisplayInfoCache.removeAll()
            cachedNodeIDForDisplayInfo = node.id
        }
        if let cachedInfo = attributeDisplayInfoCache[attributeKey] {
            return cachedInfo
        }

        let appNameFromStringPID = String(node.pid) // Get appName from pid
        await GlobalAXLogger.shared.updateOperationDetails(commandID: "fetchAttributeUIDisplayInfo_\(attributeKey)", appName: appNameFromStringPID)

        let tempElement = AXorcist.Element(node.axElementRef)
        let valueType = tempElement.getValueType(forAttribute: attributeKey) 
        
        let isSettableStatus = tempElement.isAttributeSettable(attributeKey)
        let settableStr = isSettableStatus ? " (W)" : ""
        
        var finalDisplayString = String(describing: rawAttributeValue?.value ?? "nil")
        var navElementRef: AXUIElement? = nil
        let actualValue = rawAttributeValue?.value

        switch valueType {
            case .axElement:
                var elementRefCF: CFTypeRef?
                // Use tempElement (AXorcist.Element) to get the attribute, which handles logging
                if let ref = tempElement.attribute(Attribute<AXUIElement>(rawValue: attributeKey)) { 
                    let previewResult = axorcist.getPreviewString(forElement: ref) // Removed await
                    if let preview = previewResult {
                        finalDisplayString = "AXElement: \(preview)"
                    } else {
                        finalDisplayString = "<AXUIElement: \(ref)>"
                    }
                    navElementRef = ref 
                } else { 
                    finalDisplayString = "<AXUIElement: Error getting ref>" 
                }

            case .arrayOfAXElements:
                var arrayRefCF: CFTypeRef?
                // Use tempElement (AXorcist.Element) to get the attribute
                if let nsArray = tempElement.attribute(Attribute<[AXUIElement]>(rawValue: attributeKey)) as? NSArray {                     let count = nsArray.count
                    finalDisplayString = "[AXUIElements: \(count)]"
                    if count > 0, CFGetTypeID(nsArray.object(at: 0)) == AXUIElementGetTypeID() {
                        let firstElementRef = nsArray.object(at: 0) as! AXUIElement
                        let previewResult = axorcist.getPreviewString(forElement: firstElementRef) // Removed await
                        if let preview = previewResult {
                            finalDisplayString += " (First: \(preview))"
                        } else {
                            finalDisplayString += " (First: <AXUIElement>)"
                        }
                    } else if count > 0 {
                        finalDisplayString += " (Elements not AXUIElement?)"
                    }
                    if let arr = arrayRefCF { CFRelease(arr) } // Release the copied array
                } else {
                    finalDisplayString = "<[AXUIElement]: Error getting array ref>"
                }
            default:
                // For other types, rawAttributeValue string is likely sufficient, or specific formatting can be added.
                // Check if actualValue is a number and format it if needed
                if let num = actualValue as? NSNumber {
                    finalDisplayString = num.stringValue
                } else if let str = actualValue as? String {
                    finalDisplayString = str // Already a string
                } else if actualValue == nil {
                     finalDisplayString = "<nil>"
                } // else, keep String(describing: ...)
        }

        let info = AttributeDisplayInfo(
            displayString: finalDisplayString, 
            valueType: valueType, 
            isSettable: isSettableStatus, 
            settableDisplayString: settableStr, 
            navigatableElementRef: navElementRef // Still nil for now
        )
        
        if node.id == cachedNodeIDForDisplayInfo { attributeDisplayInfoCache[attributeKey] = info }

        if Defaults[.verboseLogging] {
            let accumulatedLogs = await GlobalAXLogger.shared.getLogs()
            if !accumulatedLogs.isEmpty {
                 axDebugLog("-- AXUIDisplayInfo Logs ('\(attributeKey)') --")
                for logEntry in accumulatedLogs {
                    axDebugLog("\(GlobalAXLogger.formatEntriesAsText([logEntry], includeTimestamps: true, includeLevels: true, includeDetails: true).first ?? "")")
                }
            }
            await GlobalAXLogger.shared.clearLogs() // Clear after processing
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
        return info
    }

    // Method to be called by UI for navigation
    func navigateToElementInTree(axElementRef: AXUIElement, currentAppPID: pid_t) {
        logger.info("Attempting to navigate to element: \(axElementRef)")
        // First, ensure the main tree (accessibilityTree) is for the correct application.
        // If selectedApplicationPID is different from currentAppPID, this navigation might be cross-app or context is wrong.
        // This logic assumes we are navigating within the currently selected/focused app context.
        guard let appTreeRoot = accessibilityTree.first(where: { $0.pid == currentAppPID }) else {
            logger.warning("Cannot navigate: No tree loaded for PID \(currentAppPID).")
            // Optionally, inform the user or try to load the tree for currentAppPID if it differs from selectedApplicationPID.
            return
        }

        if let targetNode = findNodeByAXElement(axElementRef, in: [appTreeRoot]) {
            logger.info("Navigating to node: \(targetNode.displayName)")
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
            logger.warning("Element \(axElementRef) not found in current tree for PID \(currentAppPID).")
            // TODO: Consider targeted fetch for this element if not found, then select.
            // For now, just log. User might need to expand tree or refresh.
            self.actionStatusMessage = "Navigation target not found in current tree view."
            Task { try? await Task.sleep(for: .seconds(3)); self.actionStatusMessage = nil }
        }
        // CFRelease(axElementRef) // Caller (AttributeRowView) should not pass ownership if it obtained a copy for this call.
                                 // This method receives a ref, doesn't own it unless it copies it.
    }
} 