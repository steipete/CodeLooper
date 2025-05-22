import AXorcistLib
import Foundation

// Define LocatorType based on the string keys used in LocatorManager
// This makes it more type-safe when mapping heuristics.
public enum LocatorType: String, CaseIterable {
    case generatingIndicatorText
    case sidebarActivityArea
    case errorMessagePopup
    case stopGeneratingButton
    case connectionErrorIndicator
    case resumeConnectionButton
    case forceStopResumeLink
    case mainInputField
    // Add other locator types as they are defined and used
}


/// Protocol for a dynamic discovery heuristic for a specific type of UI element.
protocol AXElementHeuristic {
    /// The type of locator this heuristic tries to discover.
    var locatorType: LocatorType { get }

    /// Attempts to discover the element and return a working Locator for it.
    /// - Parameters:
    ///   - pid: The process identifier of the target application.
    ///   - axorcist: An instance of AXorcist to perform queries.
    /// - Returns: An `AXorcistLib.Locator` if the element is successfully found and a locator can be constructed, otherwise `nil`.
    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator?
}

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
            criteria: ["role": "AXDialog"],
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

// MARK: - Stop Generating Button Heuristic

struct StopGeneratingButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .stopGeneratingButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for button containing "Stop"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Stop"
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
        
        // Strategy 2: Look for button containing "Cancel"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Cancel"
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
        
        // Strategy 3: Look for any enabled button
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: [
                "role": kAXButtonRole,
                "enabled": "true"
            ],
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

// MARK: - Connection Error Indicator Heuristic

struct ConnectionErrorIndicatorHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .connectionErrorIndicator

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for text containing "offline"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "offline"
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
        
        // Strategy 2: Look for text containing "connection"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "connection"
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
        
        // Strategy 3: Look for text containing "network"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "network"
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

// MARK: - Resume Connection Button Heuristic

struct ResumeConnectionButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .resumeConnectionButton

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for button containing "Resume"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume"
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
        
        // Strategy 2: Look for button containing "Reconnect"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Reconnect"
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
        
        // Strategy 3: Look for button containing "Retry"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Retry"
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

// MARK: - Force Stop Resume Link Heuristic

struct ForceStopResumeLinkHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .forceStopResumeLink

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
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
        
        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
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
        
        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume"
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

// MARK: - Main Input Field Heuristic (Enhanced)

struct MainInputFieldHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .mainInputField

    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for focused text area in main window
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: [
                "role": kAXTextAreaRole,
                "focused": "true"
            ],
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
        
        // Strategy 2: Look for text area containing "Chat with Cursor"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXTextAreaRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Chat with Cursor"
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
        
        // Strategy 3: Look for any focusable text area in main window
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": kAXTextAreaRole],
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