import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Generating Indicator Text Heuristic

struct GeneratingIndicatorTextHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .generatingIndicatorText


    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // Attempt 1: Specific text and role
        let locator1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": AXRoleNames.kAXStaticTextRole as String, "computedName_contains": "Generating"])
            // computedNameContains: "Generating" // This is now part of criteria
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return locator1 }

        // Attempt 2: Broader role with general keywords
        let locator2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": AXRoleNames.kAXStaticTextRole as String, "computedName_contains": "loading"])
            // computedNameContains: "loading" // This is now part of criteria
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return locator2 }

        // Attempt 3: Progress indicator role
        let locator3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray(["role_exact": AXRoleNames.kAXProgressIndicatorRole as String])
        )
        let queryCommand3 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator3,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse3 = axorcist.handleQuery(command: queryCommand3, maxDepth: nil)
        if queryResponse3.payload != nil {
            return locator3
        }
        
        return nil
    }
} 
