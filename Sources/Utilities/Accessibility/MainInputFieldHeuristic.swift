import AppKit
import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Main Input Field Heuristic

struct MainInputFieldHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .mainInputField


    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Strategy 1: Look for a text area that is enabled
        let strategy1 = Locator(
            matchAll: true,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role_exact": "AXTextArea", "enabled_exact": "true"])
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return strategy1 }
        
        // Strategy 2: Look for a text field that is enabled
        let strategy2 = Locator(
            matchAll: true,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role_exact": "AXTextField", "enabled_exact": "true"])
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return strategy2 }

        // Strategy 3: Fallback - any element that looks like a text input area based on common AX attributes
        let strategy3 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray([
                "role_exact": "AXTextArea",
                "AXRoleDescription_exact": "text area", // AXRoleDescription is an attribute name
                "AXIdentifier_exact": "main_chat_input", // AXIdentifier is an attribute name
                "AXPlaceholderValue_contains": "message" // AXPlaceholderValue is an attribute name
            ])
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy3,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse3.data != nil { return strategy3 }
        
        return nil
    }
} 
