import AppKit
import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Resume Connection Button Heuristic

struct ResumeConnectionButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .resumeConnectionButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Strategy 1: Look for button with exact title "Resume connection"
        let strategy1 = Locator(
            matchAll: false, 
            criteria: ["role": "AXButton", "title": "Resume connection"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return strategy1 }
        
        // Strategy 2: Look for button containing "Resume"
        let strategy2 = Locator(
            matchAll: false, 
            criteria: ["role": "AXButton", "title_contains": "Resume"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return strategy2 }

        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = Locator(
            matchAll: false,
            criteria: ["role": "AXLink", "title_contains": "Resume"]
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
