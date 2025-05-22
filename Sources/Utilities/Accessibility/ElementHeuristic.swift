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
    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator?
}

// MARK: - Generating Indicator Text Heuristic

struct GeneratingIndicatorTextHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .generatingIndicatorText

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for static text containing "generating" (case insensitive)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "generating"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for text containing "Generating response" or similar patterns
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Generating"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for progress indicators or activity indicators
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXProgressIndicatorRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Sidebar Activity Area Heuristic

struct SidebarActivityAreaHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .sidebarActivityArea

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for a scroll area in the main window (typical sidebar)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXScrollAreaRole],
            root_element_path_hint: ["AXApplication", "AXWindow"],
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for a splitter group's scroll area (often the sidebar)
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXScrollAreaRole],
            root_element_path_hint: ["AXApplication", "AXWindow", "AXSplitter"],
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for any group that might represent a sidebar
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXGroupRole],
            root_element_path_hint: ["AXApplication", "AXWindow"],
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Error Message Popup Heuristic

struct ErrorMessagePopupHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .errorMessagePopup

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for static text containing "error" (case insensitive)
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "error"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for dialog boxes
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXDialogRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for text containing "failed"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "failed"
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Stop Generating Button Heuristic

struct StopGeneratingButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .stopGeneratingButton

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for button containing "Stop"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Stop"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for button containing "Cancel"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Cancel"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for any enabled button
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: [
                "role": AXorcistLib.AccessibilityConstants.kAXButtonRole,
                "enabled": "true"
            ],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Connection Error Indicator Heuristic

struct ConnectionErrorIndicatorHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .connectionErrorIndicator

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for text containing "offline"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "offline"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for text containing "connection"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "connection"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for text containing "network"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXStaticTextRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "network"
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Resume Connection Button Heuristic

struct ResumeConnectionButtonHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .resumeConnectionButton

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for button containing "Resume"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for button containing "Reconnect"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Reconnect"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for button containing "Retry"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Retry"
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Force Stop Resume Link Heuristic

struct ForceStopResumeLinkHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .forceStopResumeLink

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for link containing "Resume Conversation"
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for button containing "Resume Conversation"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXButtonRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume Conversation"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for any link containing "Resume"
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXLinkRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Resume"
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}

// MARK: - Main Input Field Heuristic (Enhanced)

struct MainInputFieldHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .mainInputField

    func discover(for pid: pid_t, axorcist: AXorcist) async -> AXorcistLib.Locator? {
        // Strategy 1: Look for focused text area in main window
        let strategy1 = AXorcistLib.Locator(
            match_all: false,
            criteria: [
                "role": AXorcistLib.AccessibilityConstants.kAXTextAreaRole,
                "focused": "true"
            ],
            root_element_path_hint: ["AXApplication", "AXWindow"],
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse1 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy1,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse1.success, !queryResponse1.elements.isEmpty {
                return strategy1
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 2: Look for text area containing "Chat with Cursor"
        let strategy2 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXTextAreaRole],
            root_element_path_hint: nil,
            requireAction: nil,
            computed_name_contains: "Chat with Cursor"
        )
        
        do {
            let queryResponse2 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy2,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse2.success, !queryResponse2.elements.isEmpty {
                return strategy2
            }
        } catch {
            // Continue to next strategy
        }
        
        // Strategy 3: Look for any focusable text area in main window
        let strategy3 = AXorcistLib.Locator(
            match_all: false,
            criteria: ["role": AXorcistLib.AccessibilityConstants.kAXTextAreaRole],
            root_element_path_hint: ["AXApplication", "AXWindow"],
            requireAction: nil,
            computed_name_contains: nil
        )
        
        do {
            let queryResponse3 = try await axorcist.query(
                pid: Int(pid),
                locator: strategy3,
                isDebugLoggingEnabled: false,
                currentDebugLogs: []
            )
            if queryResponse3.success, !queryResponse3.elements.isEmpty {
                return strategy3
            }
        } catch {
            // Continue to next strategy
        }
        
        return nil
    }
}