import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Stop Generating Button Heuristic

struct StopGeneratingButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .stopGeneratingButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Strategy 1: Look for button with exact title "Stop generating"
        let strategy1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role_exact": "AXButton",
                "title_exact": "Stop generating",
            ])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return strategy1 }

        // Strategy 2: Look for button with title containing "Stop"
        let strategy2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXButton", "title_contains": "Stop"])
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return strategy2 }

        // Strategy 3: Look for any link containing "Stop"
        let strategy3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXLink", "title_contains": "Stop"])
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
