import AXorcistLib
import Foundation

// MARK: - Sidebar Activity Area Heuristic

struct SidebarActivityAreaHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .sidebarActivityArea

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for a scroll area in the main window (typical sidebar)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXScrollAreaRole],
            root_element_path_hint: ["AXApplication", "AXWindow"],
            requireAction: nil,
            computed_name_contains: nil
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
        
        // Strategy 2: Look for a splitter group's scroll area (often the sidebar)
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXScrollAreaRole],
            root_element_path_hint: ["AXApplication", "AXWindow", "AXSplitter"],
            requireAction: nil,
            computed_name_contains: nil
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
        
        // Strategy 3: Look for any group that might represent a sidebar
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXGroupRole],
            root_element_path_hint: ["AXApplication", "AXWindow"],
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