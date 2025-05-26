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
            criteria: ["role": "AXButton", "title": "Stop generating"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return strategy1 }

        // Strategy 2: Look for button with title containing "Stop"
        let strategy2 = Locator(
            matchAll: false,
            criteria: ["role": "AXButton", "title_contains": "Stop"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return strategy2 }

        // Strategy 3: Look for any link containing "Stop"
        let strategy3 = Locator(
            matchAll: false,
            criteria: ["role": "AXLink", "title_contains": "Stop"]
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
