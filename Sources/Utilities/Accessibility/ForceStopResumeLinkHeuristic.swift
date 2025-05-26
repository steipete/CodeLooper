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
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXLink", "title_exact": "Force Stop and Resume"])
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator1,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return locator1 }
        
        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXLink", "title_contains": "Resume Conversation"])
        )
        
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse2.data != nil { return strategy1 }
        
        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXButton", "title_contains": "Resume Conversation"])
        )
        
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse3.data != nil { return strategy2 }
        
        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXLink", "title_contains": "Resume"])
        )
        
        let queryResponse4 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy3,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil
        )
        if queryResponse4.data != nil { return strategy3 }
        
        return nil
    }
} 
