import AXorcistLib
import Foundation
import ApplicationServices
import Defaults

// MARK: - Force Stop Resume Link Heuristic

struct ForceStopResumeLinkHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .forceStopResumeLink

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []
        
        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXRoleNames.kAXLinkRole],
            computed_name_contains: "Resume Conversation"
        )
        
        let queryResponse1 = await axorcist.handleQuery(
            for: nil,
            locator: strategy1,
            pathHint: nil,
            maxDepth: 10,
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging],
            currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return strategy1 }
        
        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXRoleNames.kAXButtonRole],
            computed_name_contains: "Resume Conversation"
        )
        
        let queryResponse2 = await axorcist.handleQuery(
            for: nil,
            locator: strategy2,
            pathHint: nil,
            maxDepth: 10,
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging],
            currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return strategy2 }
        
        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXRoleNames.kAXLinkRole],
            computed_name_contains: "Resume"
        )
        
        let queryResponse3 = await axorcist.handleQuery(
            for: nil,
            locator: strategy3,
            pathHint: nil,
            maxDepth: 10,
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging],
            currentDebugLogs: &tempLogs
        )
        if queryResponse3.data != nil { return strategy3 }
        
        return nil
    }
} 