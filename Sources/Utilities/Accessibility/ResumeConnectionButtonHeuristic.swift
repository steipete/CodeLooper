import AXorcistLib
import AppKit
import ApplicationServices
import Defaults
import Foundation

// MARK: - Resume Connection Button Heuristic

struct ResumeConnectionButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .resumeConnectionButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []

        // Attempt 1: Look for a button with title "Resume Connection"
        let locator1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXButton", "title": "Resume Connection"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return locator1 }

        // Attempt 2: Look for a button with title containing "Resume"
        let locator2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXButton", "title_contains": "Resume"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Look for a generic button that might be a resume button (e.g., if localization changes title)
        // This is a broader search, could be refined if specific patterns emerge
        let locator3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXButton", "enabled": "true"]
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