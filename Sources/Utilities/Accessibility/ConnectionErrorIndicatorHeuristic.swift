import AppKit
import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Connection Error Indicator Heuristic

struct ConnectionErrorIndicatorHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .connectionErrorIndicator


    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Strategy 1: Look for a static text element with title "Connection error"
        let strategy1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXStaticText", "title_exact": "Connection error"])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return strategy1 }
        
        // Strategy 2: Look for static text containing "Connection error"
        let strategy2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXStaticText", "title_contains_any": "Connection error,Unable to connect,Network error"])
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return strategy2 }

        // Strategy 3: Look for a generic error message pattern if more specific ones fail.
        let strategy3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXStaticText", "value_contains_any": "error,failed"])
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
