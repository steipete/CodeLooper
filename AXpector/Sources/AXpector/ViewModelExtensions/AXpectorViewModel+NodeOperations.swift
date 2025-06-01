import AppKit // For AXUIElement
import AXorcist // For Element, AXAttributeNames
import SwiftUI // For AXPropertyNode which is ObservableObject, @MainActor, etc.

// AXorcist import already includes logging utilities
import Defaults // ADD for Defaults

// MARK: - Node Operations (Finding, Expanding, Mapping)

/// Extension providing node operations and tree manipulation functionality.
///
/// This extension handles:
/// - Node discovery and lookup operations within accessibility trees
/// - Tree expansion and collapse state management
/// - Node property mapping and conversion from AXorcist elements
/// - Child node relationship management
/// - Tree traversal and navigation utilities
extension AXpectorViewModel {
    // Function to find a node by ID in the tree structure
    func findNode(by id: AXPropertyNode.ID?, in tree: [AXPropertyNode]) -> AXPropertyNode? {
        guard let targetID = id else { return nil }
        for node in tree {
            if node.id == targetID { return node }
            if let foundInChild = findNode(by: targetID, in: node.children) {
                return foundInChild
            }
        }
        return nil
    }

    // Path calculation is now done during mapping. This can be kept for ad-hoc recalculation if needed.
    func calculateFullPath(
        for nodeID: AXPropertyNode.ID?,
        in tree: [AXPropertyNode],
        currentPathParts: [String] = []
    ) -> String {
        guard let targetID = nodeID else { return "Error: No ID" }

        for node in tree {
            var pathPartsForCurrentNode = currentPathParts
            let nodeName = node.displayName.isEmpty ? "Unnamed" : node.displayName
                .replacingOccurrences(of: "/", with: ":")
            pathPartsForCurrentNode.append(nodeName)

            if node.id == targetID {
                return pathPartsForCurrentNode.joined(separator: "/")
            }

            if !node.children.isEmpty {
                let pathInChild = calculateFullPath(
                    for: targetID,
                    in: node.children,
                    currentPathParts: pathPartsForCurrentNode
                )
                if !pathInChild.hasPrefix("Error:") {
                    return pathInChild
                }
            }
        }
        return currentPathParts.isEmpty ? "Error: Node not found in tree" : "Error: Path segment not found"
    }

    // Function to dynamically load children for a node
    // swiftlint:disable:next function_body_length
    func expandNodeAndLoadChildren(_ node: AXPropertyNode) {
        if !node.hasChildrenAXProperty {
            axInfoLog(
                "Node \(node.displayName) has no children to load according to AX property. Ensuring it is collapsed."
            )
            node.isExpanded = false
            return
        }

        if node.areChildrenFullyLoaded || node.isLoadingChildren {
            if node.areChildrenFullyLoaded {
                axInfoLog("Node \(node.displayName) children are already fully loaded.")
            } else {
                axInfoLog("Node \(node.displayName) children are already loading.")
            }
            node.isExpanded = true
            return
        }

        let (currentCriteria, currentGeneralTerms) = parseFilterText(self.debouncedFilterText.lowercased())
        axInfoLog(
            "Expanding node and loading children for: \(node.displayName) (Path: \(node.fullPath)) with depth \(self.subsequentFetchDepth)"
        )
        node.isLoadingChildren = true

        Task {
            axInfoLog(
                "Expanding node: \(node.displayName)",
                details: [
                    "commandID": AnyCodable("expandNode_\(node.id.uuidString.prefix(8))"),
                    "appName": AnyCodable(String(node.pid)),
                ]
            )

            let rootAXElementForExpansion = Element(node.axElementRef)
            let fetchedPropertyNodeChildren = await self.recursivelyFetchChildren(
                forElement: rootAXElementForExpansion,
                pid: node.pid,
                depthOfElementToFetchChildrenFor: node.depth, // Depth of the node we are expanding
                currentExpansionLevel: 0,
                maxExpansionLevels: self.subsequentFetchDepth,
                pathOfElementToFetchChildrenFor: node.fullPath
            )

            if Defaults[.verboseLoggingAxpector] {
                let collectedLogs = axGetLogEntries()
                for logEntry in collectedLogs { // Iterate and log
                    axDebugLog(
                        """
                        AXorcist (ExpandNode) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \
                        \(logEntry.message) Details: \(logEntry.details ?? [:])
                        """
                    )
                }
                axClearLogs()
            }

            let childrenToAssign: [AXPropertyNode]
            if !self.debouncedFilterText.isEmpty {
                axInfoLog(
                    """
                    Re-filtering \(fetchedPropertyNodeChildren.count) newly loaded children for node \(node
                        .displayName) \
                    against filter: \(self.debouncedFilterText)
                    """
                )
                childrenToAssign = filterNodes(
                    fetchedPropertyNodeChildren,
                    criteria: currentCriteria,
                    generalTerms: currentGeneralTerms
                )
            } else {
                childrenToAssign = fetchedPropertyNodeChildren
            }

            node.children = childrenToAssign
            node.areChildrenFullyLoaded = true
            axInfoLog(
                "Successfully assigned \(childrenToAssign.count) children (after potential filtering) for node \(node.displayName)."
            )

            node.isLoadingChildren = false
            if !node.isExpanded { node.isExpanded = true }

            axInfoLog("Finished expanding node: \(node.displayName)")
        }
    }

    func recursivelyFetchChildren(
        forElement elementToFetchChildrenFor: Element,
        pid: pid_t,
        depthOfElementToFetchChildrenFor: Int,
        // This is the depth in the overall tree of the element whose children we are fetching
        currentExpansionLevel: Int, // How many levels deep are we in *this specific* expansion operation
        maxExpansionLevels: Int, // Max levels for *this specific* expansion operation
        pathOfElementToFetchChildrenFor: String
    ) async -> [AXPropertyNode] {
        guard currentExpansionLevel < maxExpansionLevels else {
            return []
        }

        guard let directChildrenAX = elementToFetchChildrenFor.children() else {
            return []
        }

        var propertyNodes: [AXPropertyNode] = []
        for childAX in directChildrenAX {
            let (childAttributes, _) = await getElementAttributes(
                element: childAX,
                attributes: AXpectorViewModel.defaultFetchAttributes,
                outputFormat: .jsonString
            )

            let childRole = childAttributes[AXAttributeNames.kAXRoleAttribute]?.value as? String
            let childTitle = childAttributes[AXAttributeNames.kAXTitleAttribute]?.value as? String
            var childPathComponent = childRole ?? "UnknownRole"
            if let title = childTitle,
               !title.isEmpty
            {
                childPathComponent += "[\"\(title.prefix(20))\"]"
            } else {
                childPathComponent += "[EL:\(String(describing: childAX.underlyingElement).suffix(8))]"
            }
            let childFullPath = pathOfElementToFetchChildrenFor
                .isEmpty ? childPathComponent : "\(pathOfElementToFetchChildrenFor)/\(childPathComponent)"

            let grandChildrenPropertyNodes = await recursivelyFetchChildren(
                forElement: childAX,
                pid: pid,
                depthOfElementToFetchChildrenFor: depthOfElementToFetchChildrenFor + 1,
                // Grandchildren's parent is one level deeper
                currentExpansionLevel: currentExpansionLevel + 1,
                maxExpansionLevels: maxExpansionLevels,
                pathOfElementToFetchChildrenFor: childFullPath
            )

            let propertyNode = AXPropertyNode(
                id: UUID(),
                axElementRef: childAX.underlyingElement,
                pid: pid,
                role: childAttributes[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "N/A",
                title: childAttributes[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? "",
                descriptionText: childAttributes[AXAttributeNames.kAXDescriptionAttribute]?.value as? String ?? "",
                value: childAttributes[AXAttributeNames.kAXValueAttribute]?.value as? String ?? "",
                fullPath: childFullPath,
                children: grandChildrenPropertyNodes,
                attributes: childAttributes,
                actions: childAX.supportedActions() ?? [],
                // Use childAX.children() to check if it *can* have children from AX perspective
                hasChildrenAXProperty: (childAX.children() != nil && !(childAX.children()?.isEmpty ?? true)) ||
                    (childAttributes[AXAttributeNames.kAXChildrenAttribute] != nil),
                depth: depthOfElementToFetchChildrenFor + 1 // Depth of this new child node in the tree
            )
            propertyNode.areChildrenFullyLoaded = !grandChildrenPropertyNodes
                .isEmpty || (currentExpansionLevel + 1 >= maxExpansionLevels)
            propertyNodes.append(propertyNode)
        }
        return propertyNodes
    }

    // Recursive helper to find a node by AXUIElement reference
    func findNodeByAXElement(_ elementRef: AXUIElement, in nodes: [AXPropertyNode]) -> AXPropertyNode? {
        for node in nodes {
            if CFEqual(node.axElementRef, elementRef) { return node }
            if let foundInChildren = findNodeByAXElement(elementRef, in: node.children) {
                return foundInChildren
            }
        }
        return nil
    }

    // Ensure parents of a given node are expanded and their children loaded if necessary
    func expandParents(for nodeID: AXPropertyNode.ID, in tree: [AXPropertyNode]) -> Bool {
        for nodeInTree in tree {
            if nodeInTree.id == nodeID {
                return true
            }
            if findNode(by: nodeID, in: [nodeInTree]) != nil {
                if nodeInTree.hasChildrenAXProperty {
                    nodeInTree.isExpanded = true
                    expandNodeAndLoadChildren(nodeInTree)
                }
                if expandParents(for: nodeID, in: nodeInTree.children) {
                    return true
                }
            }
        }
        return false
    }

    // Pass parentPath for efficient path construction during mapping
    // This function is now largely replaced by the logic inside recursivelyFetchChildren
    // but might be kept if it's used for an initial full tree fetch.
    // For expanding nodes, recursivelyFetchChildren is more direct.
    @MainActor
    func mapJsonAXElementToNode(
        _ jsonElement: AXElement,
        pid: pid_t,
        currentDepth: Int,
        parentPath: String
    ) -> AXPropertyNode {
        let role = jsonElement.attributes?[AXAttributeNames.kAXRoleAttribute]?.value as? String
        let title = jsonElement.attributes?[AXAttributeNames.kAXTitleAttribute]?.value as? String
        let descriptionText = jsonElement.attributes?[AXAttributeNames.kAXDescriptionAttribute]?.value as? String
        let valueText = jsonElement.attributes?[AXAttributeNames.kAXValueAttribute]?.value as? String

        var currentPathComponent = role ?? "UnknownRole"
        if let titleText = title, !titleText.isEmpty { currentPathComponent += "[\"\(titleText.prefix(20))\"]" }
        // Path construction from jsonElement.path might be better if available and reliable
        let newPath = parentPath.isEmpty ? currentPathComponent : "\(parentPath)/\(currentPathComponent)"

        // Children are not directly available in AXElement struct from CollectAllOutput in a nested way for this map.
        // The CollectAllOutput.collectedElements is a flat list of all elements found.
        // So, children for this node would need to be reconstructed based on paths, or this mapping is only for
        // top-level elements.
        // For now, assume children will be empty and loaded later.

        // TEMPORARY: Use a placeholder for axElementRef. This will break interactions.
        let placeholderRef = AXUIElementCreateApplication(pid) // This is NOT correct but makes it compile.

        // Determine hasChildrenAXProperty based on the kAXChildrenAttribute in the JSON data
        var hasChildren = false
        if let childrenAttr = jsonElement.attributes?[AXAttributeNames.kAXChildrenAttribute]?.value {
            if let childrenArray = childrenAttr as? [Any] {
                hasChildren = !childrenArray.isEmpty
            } else if let childrenNSArray = childrenAttr as? NSArray {
                // swiftlint gets confused and tries to convert this to .isEmpty which doesn't exist on NSArray.
                // swiftlint:disable:next empty_count
                hasChildren = childrenNSArray.count > 0
            }
            // Add more checks if children can be other types that indicate presence
        }

        let node = AXPropertyNode(
            id: UUID(),
            axElementRef: placeholderRef, // Placeholder!
            pid: pid,
            role: role ?? "N/A",
            title: title ?? "",
            descriptionText: descriptionText ?? "",
            value: valueText ?? "",
            fullPath: jsonElement.path?.joined(separator: "/") ?? newPath,
            // Prefer actual path from AXElement if present
            children: [], // Children need to be populated by a separate step that reconstructs hierarchy from flat list
            attributes: jsonElement.attributes ?? [:],
            actions: [], // Actions are not in AXElement struct
            hasChildrenAXProperty: hasChildren, // Updated based on kAXChildrenAttribute
            depth: currentDepth
        )
        node.areChildrenFullyLoaded = true // Since we are not populating children here from this map
        return node
    }

    @MainActor
    func mapAXElementToNode(
        _ axElementFromCollectAll: Element,
        pid: pid_t,
        currentDepth: Int,
        parentPath: String
    ) -> AXPropertyNode {
        // This mapping is for when Element comes from a broader collectAll operation,
        // which already has its children populated up to a certain depth.

        let roleDesc = axElementFromCollectAll.attributes?[AXAttributeNames.kAXRoleDescriptionAttribute]?
            .value as? String
        let role = axElementFromCollectAll.attributes?[AXAttributeNames.kAXRoleAttribute]?.value as? String
        let title = axElementFromCollectAll.attributes?[AXAttributeNames.kAXTitleAttribute]?.value as? String

        var currentPathComponent = roleDesc ?? role ?? "UnknownRole"
        // Using underlyingElement string for path component if title is empty can be very verbose and less stable.
        // Consider a more stable placeholder or relying on role if title is missing.
        if let titleText = title, !titleText.isEmpty { currentPathComponent += "[\"\(titleText.prefix(20))\"]" } else {
            currentPathComponent += "[EL:\(String(describing: axElementFromCollectAll.underlyingElement).suffix(8))]"
        } // Short unique-ish ID

        let newPath = parentPath.isEmpty ? currentPathComponent : "\(parentPath)/\(currentPathComponent)"

        // Children from Element are already Element type
        let mappedChildren: [AXPropertyNode] = axElementFromCollectAll.children()?.map {
            mapAXElementToNode($0, pid: pid, currentDepth: currentDepth + 1, parentPath: newPath)
        } ?? []

        let node = AXPropertyNode(
            id: UUID(),
            axElementRef: axElementFromCollectAll.underlyingElement,
            pid: pid,
            role: role ?? "N/A",
            title: title ?? "",
            descriptionText: axElementFromCollectAll.attributes?[AXAttributeNames.kAXDescriptionAttribute]?
                .value as? String ?? "",
            value: axElementFromCollectAll.attributes?[AXAttributeNames.kAXValueAttribute]?.value as? String ?? "",
            fullPath: newPath,
            children: mappedChildren,
            attributes: axElementFromCollectAll.attributes ?? [:],
            actions: axElementFromCollectAll.actions ?? [],
            // hasChildrenAXProperty should be determined by querying the actual AXUIElement if not provided by
            // axElementFromCollectAll
            // For now, inferring from mappedChildren.count, but AXorcist.Element().children() would be more accurate
            // for the actual AX property.
            hasChildrenAXProperty: !mappedChildren.isEmpty || (axElementFromCollectAll.children()?.isEmpty == false),
            depth: currentDepth
        )
        // If axElementFromCollectAll.children is non-nil, it means they were part of the fetch.
        node.areChildrenFullyLoaded = axElementFromCollectAll.children() != nil
        return node
    }
}
