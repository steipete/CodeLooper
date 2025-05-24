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
            criteria: ["role": AXRoleNames.kAXStaticTextRole],
            computedNameContains: "Generating"
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: nil,
            locator: locator1,
            pathHint: nil,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse1.data != nil { return locator1 }

        // Attempt 2: Broader role with general keywords
        let locator2 = Locator(
            matchAll: false,
            criteria: ["role": AXRoleNames.kAXStaticTextRole],
            computedNameContains: "loading"
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: nil,
            locator: locator2,
            pathHint: nil,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Progress indicator role
        let locator3 = Locator(
            matchAll: false,
            criteria: ["role": AXRoleNames.kAXProgressIndicatorRole]
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: nil,
            locator: locator3,
            pathHint: nil,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse3.data != nil {
            return locator3
        }
        
        return nil
    }
} 
