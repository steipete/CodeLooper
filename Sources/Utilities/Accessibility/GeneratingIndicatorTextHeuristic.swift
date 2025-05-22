import AXorcistLib
import Foundation

// MARK: - Generating Indicator Text Heuristic

struct GeneratingIndicatorTextHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .generatingIndicatorText

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for static text containing "generating" (case insensitive)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "generating"
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
        
        // Strategy 2: Look for text containing "Generating response" or similar patterns
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Generating"
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
        
        // Strategy 3: Look for progress indicators or activity indicators
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXProgressIndicatorRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: nil
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