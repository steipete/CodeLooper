import AppKit
import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Error Message Popup Heuristic

struct ErrorMessagePopupHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .errorMessagePopup


    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        // tempLogs removed

        // Attempt 1: Look for a pop-up dialog with an error message
        let locator1 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXWindow", "subrole_exact": "AXDialog", "description_contains_any": "error,failed,unable"])
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator1,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return locator1 }
        
        // Attempt 2: Look for static text that is likely an error message
        let locator2 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXStaticText", "isLikelyErrorMessage_exact": "true"])
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator2,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return locator2 }

        // Attempt 3: Look for a more generic static text containing error keywords
        let locator3 = Locator(
            matchAll: false,
            criteria: AXElementHeuristic.convertDictionaryToCriteriaArray(["role": "AXStaticText", "computed_name_contains_any": "error,failed,unable,warning,invalid"])
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: String(pid),
            locator: locator3,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse3.data != nil { return locator3 }

        return nil
    }
} 
