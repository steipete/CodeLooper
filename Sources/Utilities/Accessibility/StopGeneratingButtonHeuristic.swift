import AXorcistLib
import Foundation
import ApplicationServices
import Defaults

// MARK: - Stop Generating Button Heuristic

struct StopGeneratingButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .stopGeneratingButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []

        let locator1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole, "title": "Stop Generating"],
            requireAction: kAXPressAction
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: nil,
            locator: locator1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return locator1 }

        let locator2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            requireAction: kAXPressAction,
            computed_name_contains: "Stop"
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: nil,
            locator: locator2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return locator2 }

        let locator3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole, "AXRoleDescription": "stop button"],
            requireAction: kAXPressAction
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: nil,
            locator: locator3,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse3.data != nil { return locator3 }

        return nil
    }
} 