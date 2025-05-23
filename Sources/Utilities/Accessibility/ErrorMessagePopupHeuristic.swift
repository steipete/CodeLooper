import AXorcistLib
import AppKit
import ApplicationServices
import Defaults
import Foundation

// MARK: - Error Message Popup Heuristic

struct ErrorMessagePopupHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .errorMessagePopup

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []

        // Attempt 1: Look for a pop-up dialog with an error message
        let locator1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXWindow", "subrole": "AXDialog", "description_contains_any": "error,failed,unable"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return locator1 }
        
        // Attempt 2: Look for static text that is likely an error message
        let locator2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXStaticText", "isLikelyErrorMessage": "true"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Look for a more generic static text containing error keywords
        let locator3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXStaticText", "computed_name_contains_any": "error,failed,unable,warning,invalid"]
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator3,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse3.data != nil { return locator3 }

        return nil
    }
} 