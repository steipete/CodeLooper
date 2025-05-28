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
            criteria: Self.convertDictionaryToCriteriaArray([
                "role": "AXWindow",
                "subrole_exact": "AXDialog",
                "description_contains_any": "error,failed,unable",
            ])
        )
        let queryCommand1 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator1,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse1 = axorcist.handleQuery(command: queryCommand1, maxDepth: nil)
        if queryResponse1.payload != nil { return locator1 }

        // Attempt 2: Look for static text that is likely an error message
        let locator2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role": "AXStaticText",
                "isLikelyErrorMessage_exact": "true",
            ])
        )
        let queryCommand2 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator2,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse2 = axorcist.handleQuery(command: queryCommand2, maxDepth: nil)
        if queryResponse2.payload != nil { return locator2 }

        // Attempt 3: Look for a more generic static text containing error keywords
        let locator3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role": "AXStaticText",
                "computed_name_contains_any": "error,failed,unable,warning,invalid",
            ])
        )
        let queryCommand3 = QueryCommand(
            appIdentifier: String(pid),
            locator: locator3,
            attributesToReturn: nil,
            maxDepthForSearch: 10
        )
        let queryResponse3 = axorcist.handleQuery(command: queryCommand3, maxDepth: nil)
        if queryResponse3.payload != nil { return locator3 }

        return nil
    }
}
