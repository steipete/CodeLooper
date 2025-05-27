import ApplicationServices
import AXorcist
import Defaults
import Foundation

// MARK: - Sidebar Activity Area Heuristic

struct SidebarActivityAreaHeuristic: AXElementHeuristic {
    let locatorType: LocatorType = .sidebarActivityArea


    @MainActor func discover(for pid: pid_t, axorcist: AXorcist) async -> Locator? {
        let locator1 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role_exact": AXRoleNames.kAXScrollAreaRole,
                "computedName_contains": "chat"
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

        let locator2 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role_exact": AXRoleNames.kAXScrollAreaRole,
                "identifier_exact": "sidebar"
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

        let locator3 = Locator(
            matchAll: false,
            criteria: Self.convertDictionaryToCriteriaArray([
                "role_exact": AXRoleNames.kAXGroupRole,
                "computedName_contains": "sidebar"
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
