import AXorcistLib
import Foundation
import ApplicationServices
import Defaults

// MARK: - Main Input Field Heuristic (Enhanced)

struct MainInputFieldHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .mainInputField

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []
        // axorcist instance is passed in

        // Attempt 1: Common role and placeholder/value - simplified
        let locator1 = AXorcistLib.Locator(
            match_all: false,
            criteria: [
                "role": kAXTextAreaRole,
                "placeholder_value": "message" // Simplified from placeholder_value_contains_any
            ]
        )
        let queryResponse1 = await axorcist.handleQuery( // Added await
            for: nil,
            locator: locator1,
            pathHint: nil,
            maxDepth: nil, 
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], // Corrected Defaults usage
            currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return locator1 }

        // Attempt 2: Specific accessibility labels or titles - simplified
        let locator2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXTextAreaRole],
            computed_name_contains: "Chat Input" // Simplified from computed_name_equals_any
        )
        let queryResponse2 = await axorcist.handleQuery( // Added await
            for: nil,
            locator: locator2,
            pathHint: nil,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], // Corrected Defaults usage
            currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Generic enabled text area (fallback)
        let locator3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXTextAreaRole, "enabled": "true"]
        )
        let queryResponse3 = await axorcist.handleQuery( // Added await
            for: nil,
            locator: locator3,
            pathHint: nil,
            maxDepth: nil,
            requestedAttributes: nil,
            outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], // Corrected Defaults usage
            currentDebugLogs: &tempLogs
        )
        if queryResponse3.data != nil { return locator3 }

        return nil
    }
} 