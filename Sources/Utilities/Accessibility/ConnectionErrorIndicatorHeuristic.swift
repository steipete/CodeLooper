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
            criteria: ["role": "AXStaticText", "title": "Connection error"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return strategy1 }
        
        // Strategy 2: Look for static text containing "Connection error"
        let strategy2 = Locator(
            matchAll: false,
            criteria: ["role": "AXStaticText", "title_contains_any": "Connection error,Unable to connect,Network error"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return strategy2 }

        // Strategy 3: Look for a generic error message pattern if more specific ones fail.
        let strategy3 = Locator(
            matchAll: false,
            criteria: ["role": "AXStaticText", "value_contains_any": "error,failed"]
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy3,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse3.data != nil { return strategy3 }
        
        return nil
    }
} 
