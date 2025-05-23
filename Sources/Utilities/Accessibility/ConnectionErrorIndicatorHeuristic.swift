import AXorcistLib
import AppKit
import ApplicationServices
import Defaults
import Foundation

// MARK: - Connection Error Indicator Heuristic

struct ConnectionErrorIndicatorHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .connectionErrorIndicator

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []

        // Attempt 1: Look for "offline"
        let locator1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXStaticText", "computed_name_contains": "offline"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return locator1 }

        // Attempt 2: Look for "network error"
        let locator2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXStaticText", "computed_name_contains": "network error"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Look for a generic error image - simplified from description_contains_any
        let locator3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXImage", "description": "error"]
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