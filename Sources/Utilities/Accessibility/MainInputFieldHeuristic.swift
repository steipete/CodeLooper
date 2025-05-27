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
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXTextArea", "enabled_exact": "true"])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return strategy1 }

        // Strategy 2: Look for a text field that is enabled
        let strategy2 = Locator(
            matchAll: true,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXTextField", "enabled_exact": "true"])
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return strategy2 }

        // Strategy 3: Fallback - any element that looks like a text input area based on common AX attributes
        let strategy3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role_exact": "AXTextArea",
                "AXRoleDescription_exact": "text area", // AXRoleDescription is an attribute name
                "AXIdentifier_exact": "main_chat_input", // AXIdentifier is an attribute name
                "AXPlaceholderValue_contains": "message", // AXPlaceholderValue is an attribute name
            ])
        )
        let queryCommand3 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy3,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse3 = axorcist.handleQuery(command: queryCommand3, maxDepth: nil)
        if queryResponse3.payload != nil { return strategy3 }

        return nil
    }
}
