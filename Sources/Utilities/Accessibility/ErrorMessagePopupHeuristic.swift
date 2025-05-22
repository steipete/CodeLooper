import AXorcistLib
import Foundation

// MARK: - Error Message Popup Heuristic

struct ErrorMessagePopupHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .errorMessagePopup

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for static text containing "error" (case insensitive)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "error"
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
        
        // Strategy 2: Look for dialog boxes
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXDialog"], // Using string literal as kAXDialogRole might not always be available directly
            root_element_path_hint: nil,
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
        
        // Strategy 3: Look for text containing "failed"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "failed"
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