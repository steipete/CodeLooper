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
            criteria: ["role": AXRoleNames.kAXScrollAreaRole],
            computedNameContains: "chat"
        )
        let queryResponse1 = await axorcist.handleQuery(
            for: nil,
            locator: locator1,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse1.data != nil { return locator1 }

        let locator2 = Locator(
            matchAll: false,
            criteria: ["role": AXRoleNames.kAXScrollAreaRole, "identifier": "sidebar"]
        )
        let queryResponse2 = await axorcist.handleQuery(
            for: nil,
            locator: locator2,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse2.data != nil { return locator2 }

        let locator3 = Locator(
            matchAll: false,
            criteria: ["role": AXRoleNames.kAXGroupRole],
            computedNameContains: "sidebar"
        )
        let queryResponse3 = await axorcist.handleQuery(
            for: nil,
            locator: locator3,
            maxDepth: nil, requestedAttributes: nil, outputFormat: nil
        )
        if queryResponse3.data != nil { return locator3 }

        return nil
    }
} 
