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
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXButton", "title_exact": "Resume connection"])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return strategy1 }
        
        // Strategy 2: Look for button containing "Resume"
        let strategy2 = Locator(
            matchAll: false, 
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXButton", "title_contains": "Resume"])
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return strategy2 }

        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": "AXLink", "title_contains": "Resume"])
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
