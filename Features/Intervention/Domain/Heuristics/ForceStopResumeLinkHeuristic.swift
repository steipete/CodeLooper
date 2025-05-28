import AppKit
import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Force Stop and Resume Link Heuristic

struct ForceStopResumeLinkHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .forceStopResumeLink

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Attempt 1: Look for a link with text "Force Stop and Resume"
        let locator1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role": "AXLink", "title_exact": "Force Stop and Resume"])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return locator1 }

        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role": "AXLink", "title_contains": "Resume Conversation"])
        )

        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return strategy1 }

        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role": "AXButton",
                "title_contains": "Resume Conversation",
            ])
        )

        let queryCommand3 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse3 = axorcist.handleQuery(command: queryCommand3, maxDepth: nil)
        if queryResponse3.payload != nil { return strategy2 }

        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role": "AXLink", "title_contains": "Resume"])
        )

        let queryCommand4 = QueryCommand(
            appIdentifier: String(pid),
            locator: strategy3,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse4 = axorcist.handleQuery(command: queryCommand4, maxDepth: nil)
        if queryResponse4.payload != nil { return strategy3 }

        return nil
    }
}
