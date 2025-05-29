import Combine // For $filterText, .debounce, .assign
import SwiftUI // For @Published properties if any were moved (not in this extension directly)

// import OSLog // For Logger // REMOVE OSLog
import AXorcist // For GlobalAXLogger and ax...Log helpers
import Foundation // For NSRegularExpression

// MARK: - Filter Criteria Structures (used by Filtering Logic)

// Note: These are defined here to be accessible by the AXpectorViewModel extension below.
// Alternatively, they could be nested inside the extension if preferred and Swift syntax allows for private/fileprivate
// struct access from extension methods.
// Making them internal here if they are used across the module, or fileprivate if only in this file + its extensions.

struct FilterCriterion { // Keep internal if AXpectorViewModel methods in other files might need it, or make fileprivate
    let key: String
    let value: String
    let isNegated: Bool
    let isRegex: Bool
}

struct GeneralTermCriterion { // Keep internal or make fileprivate
    let term: String
    let isNegated: Bool
    let isRegex: Bool
}

// MARK: - Filtering Logic

/// Extension providing advanced filtering capabilities for accessibility tree nodes.
///
/// This extension handles:
/// - Text-based filtering with pattern matching and regex support
/// - Multi-criteria filtering (role, title, value, attributes)
/// - Debounced filter input processing for performance
/// - Filter state management and persistence
/// - Tree node visibility calculations based on filter results
extension AXpectorViewModel {
    func applyFilter() {
        if filterText.isEmpty {
            filteredAccessibilityTree = accessibilityTree
            axInfoLog("Filter cleared. Displaying full tree.")
            return
        }

        axInfoLog("Applying filter: \(self.debouncedFilterText)")
        let (criteria, generalTerms) = parseFilterText(debouncedFilterText.lowercased())

        if !criteria
            .isEmpty
        {
            axDebugLog(
                "Parsed criteria: \(criteria.map { 
                    "(\($0.isNegated ? "NOT " : "")\($0.key): \($0.isRegex ? "regex: " : "")\($0.value)"
                })"
            )
        }
        if !generalTerms
            .isEmpty
        {
            axDebugLog(
                "Parsed general terms: \(generalTerms.map { "(\($0.isNegated ? "NOT " : "")\($0.isRegex ? "regex:" : "")\($0.term))" })"
            )
        }

        filteredAccessibilityTree = filterNodes(accessibilityTree, criteria: criteria, generalTerms: generalTerms)
        expandAllParentsInFilteredTree(nodes: filteredAccessibilityTree)
    }

    func parseFilterText(_ text: String) -> (criteria: [FilterCriterion], generalTerms: [GeneralTermCriterion]) {
        var criteria: [FilterCriterion] = []
        var generalTerms: [GeneralTermCriterion] = []
        let components = text.split(separator: " ").map { String($0) }

        let validKeys = ["role", "title", "value", "desc", "description", "path", "id"]

        for component in components {
            var keyToTest = component
            var isNegated = false
            var isRegex = false

            if component.starts(with: "!") || component.starts(with: "-") {
                isNegated = true
                keyToTest = String(keyToTest.dropFirst())
            }

            // Check for regex: prefix AFTER potential negation, but BEFORE splitting for key:value
            if keyToTest.starts(with: "regex:") {
                isRegex = true
                keyToTest = String(keyToTest.dropFirst("regex:".count))
            }

            let parts = keyToTest.split(separator: ":", maxSplits: 1).map { String($0) }
            if parts.count == 2, validKeys.contains(parts[0]) {
                let key = parts[0] == "description" ? "desc" : parts[0]
                let value = parts[1]
                // isRegex here correctly refers to whether the original component (after negation) started with regex:
                // before the key.
                // e.g., "regex:title:foo" or "!regex:role:bar"
                criteria.append(FilterCriterion(key: key, value: value, isNegated: isNegated, isRegex: isRegex))
            } else {
                // If it wasn't a key:value, keyToTest is the term (with regex: already stripped if it was global for
                // the term)
                // isRegex is already correctly set for a global regex term.
                generalTerms.append(GeneralTermCriterion(term: keyToTest, isNegated: isNegated, isRegex: isRegex))
            }
        }
        return (criteria, generalTerms)
    }

    // swiftlint:disable:next function_body_length
    func filterNodes(
        _ nodes: [AXPropertyNode],
        criteria: [FilterCriterion],
        generalTerms: [GeneralTermCriterion]
    ) -> [AXPropertyNode] {
        var matchedNodes: [AXPropertyNode] = []
        for node in nodes {
            var matchesAllCriteria = true
            for criterion in criteria {
                var specificFieldMatches = false
                let targetValue = criterion.value
                switch criterion.key {
                case "role": specificFieldMatches = match(
                    text: node.role.lowercased(),
                    pattern: targetValue,
                    isRegex: criterion.isRegex
                )
                case "title": specificFieldMatches = match(
                    text: node.title.lowercased(),
                    pattern: targetValue,
                    isRegex: criterion.isRegex
                )
                case "value": specificFieldMatches = match(
                    text: node.value.lowercased(),
                    pattern: targetValue,
                    isRegex: criterion.isRegex
                )
                case "desc": specificFieldMatches = match(
                    text: node.descriptionText.lowercased(),
                    pattern: targetValue,
                    isRegex: criterion.isRegex
                )
                case "path": specificFieldMatches = match(
                    text: node.fullPath.lowercased(),
                    pattern: targetValue,
                    isRegex: criterion.isRegex
                )
                case "id":
                    if let axIdentifier = node.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String {
                        specificFieldMatches = match(
                            text: axIdentifier.lowercased(),
                            pattern: targetValue,
                            isRegex: criterion.isRegex
                        )
                    } else { specificFieldMatches = false }
                default: break
                }
                if criterion.isNegated { specificFieldMatches.toggle() }
                if !specificFieldMatches { matchesAllCriteria = false; break }
            }
            if !matchesAllCriteria { continue }

            var matchesAllPositiveGeneralTerms = true
            var matchesAnyNegatedGeneralTerm = false

            let positiveGeneralTerms = generalTerms.filter { !$0.isNegated }
            let negatedGeneralTerms = generalTerms.filter(\.isNegated)

            if !positiveGeneralTerms.isEmpty {
                for termCrit in positiveGeneralTerms {
                    var termMatchedInAtLeastOneField = false
                    let termPattern = termCrit.term
                    if searchInDisplayName, match(
                        text: node.displayName.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField, searchInRole, match(
                        text: node.role.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField, searchInTitle, match(
                        text: node.title.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField, searchInValue, match(
                        text: node.value.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField, searchInDescription, match(
                        text: node.descriptionText.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField, searchInPath, match(
                        text: node.fullPath.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { termMatchedInAtLeastOneField = true }
                    if !termMatchedInAtLeastOneField { matchesAllPositiveGeneralTerms = false; break }
                }
            }

            if !negatedGeneralTerms.isEmpty {
                for termCrit in negatedGeneralTerms {
                    let termPattern = termCrit.term
                    if searchInDisplayName, match(
                        text: node.displayName.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                    if searchInRole, match(
                        text: node.role.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                    if searchInTitle, match(
                        text: node.title.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                    if searchInValue, match(
                        text: node.value.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                    if searchInDescription, match(
                        text: node.descriptionText.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                    if searchInPath, match(
                        text: node.fullPath.lowercased(),
                        pattern: termPattern,
                        isRegex: termCrit.isRegex
                    ) { matchesAnyNegatedGeneralTerm = true; break }
                }
            }

            let overallGeneralTermsMatch = matchesAllPositiveGeneralTerms && !matchesAnyNegatedGeneralTerm
            let filteredChildren = filterNodes(node.children, criteria: criteria, generalTerms: generalTerms)

            if (matchesAllCriteria && overallGeneralTermsMatch) || !filteredChildren.isEmpty {
                let newNode = AXPropertyNode(
                    id: node.id,
                    axElementRef: node.axElementRef,
                    pid: node.pid,
                    role: node.role,
                    title: node.title,
                    descriptionText: node.descriptionText,
                    value: node.value,
                    fullPath: node.fullPath,
                    children: filteredChildren,
                    attributes: node.attributes,
                    actions: node.actions,
                    hasChildrenAXProperty: node.hasChildrenAXProperty,
                    depth: node.depth
                )
                newNode.isExpanded = (matchesAllCriteria && overallGeneralTermsMatch) || !filteredChildren.isEmpty
                newNode.areChildrenFullyLoaded = node.areChildrenFullyLoaded
                matchedNodes.append(newNode)
            }
        }
        return matchedNodes
    }

    private func expandAllParentsInFilteredTree(nodes: [AXPropertyNode]) {
        for node in nodes where !node.children.isEmpty {
            node.isExpanded = true
            expandAllParentsInFilteredTree(nodes: node.children)
        }
    }

    func setupFilterDebouncer() {
        $filterText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .assign(to: &$debouncedFilterText)
    }

    private func match(text: String, pattern: String, isRegex: Bool) -> Bool {
        if isRegex {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                return regex
                    .firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil
            } catch {
                axWarningLog(
                    "Invalid regex pattern '\(pattern)': \(error.localizedDescription). Treating as literal string contains search."
                )
                return text.contains(pattern)
            }
        } else {
            return text.contains(pattern)
        }
    }
}
