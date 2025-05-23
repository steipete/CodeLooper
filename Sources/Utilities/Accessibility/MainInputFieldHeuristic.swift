import AXorcistLib
import AppKit
import ApplicationServices
import Defaults
import Foundation

// MARK: - Main Input Field Heuristic

struct MainInputFieldHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .mainInputField

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        var tempLogs: [String] = []

        // Strategy 1: Look for text area with specific placeholder
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXTextArea", "placeholder": "Send a message"]
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy1,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse1.data != nil { return strategy1 }

        // Strategy 2: Look for text field with specific placeholder
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXTextField", "placeholder": "Send a message"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy2,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse2.data != nil { return strategy2 }

        // Strategy 3: Look for a generic enabled text area (fallback if ancestor_criteria is not supported)
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": "AXTextArea", "enabled": "true"]
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: strategy3,
            pathHint: nil, maxDepth: nil, requestedAttributes: nil, outputFormat: nil,
            isDebugLoggingEnabled: Defaults[.verboseLogging], currentDebugLogs: &tempLogs
        )
        if queryResponse3.data != nil { return strategy3 }

        return nil
    }
} 