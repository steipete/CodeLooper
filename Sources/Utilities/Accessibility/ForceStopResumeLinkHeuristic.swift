import AXorcistLib
import Foundation

// MARK: - Force Stop Resume Link Heuristic

struct ForceStopResumeLinkHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .forceStopResumeLink

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
        )
        
        var tempLogs: [String] = []
        let queryResponse1 = axorcist.handleQuery(
            for: nil,
            locator: strategy1,
            maxDepth: 10,
            isDebugLoggingEnabled: true,
            currentDebugLogs: &tempLogs
        )
        if queryResponse1.error == nil, let _ = queryResponse1.data {
            return strategy1
        }
        
        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
        )
        
        var tempLogs2: [String] = []
        let queryResponse2 = axorcist.handleQuery(
            for: nil,
            locator: strategy2,
            maxDepth: 10,
            isDebugLoggingEnabled: true,
            currentDebugLogs: &tempLogs2
        )
        if queryResponse2.error == nil, let _ = queryResponse2.data {
            return strategy2
        }
        
        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume"
        )
        
        var tempLogs3: [String] = []
        let queryResponse3 = axorcist.handleQuery(
            for: nil,
            locator: strategy3,
            maxDepth: 10,
            isDebugLoggingEnabled: true,
            currentDebugLogs: &tempLogs3
        )
        if queryResponse3.error == nil, let _ = queryResponse3.data {
            return strategy3
        }
        
        return nil
    }
} 