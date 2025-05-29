import AppKit
import AXorcist
import Combine
import Defaults
import SwiftUI

// Define the key locally if not accessible from main app target's DefaultsKeys
extension Defaults.Keys {
    static let verboseLogging_axpector = Key<Bool>("verboseLogging", default: false)
    static let selectTreeOnFocusChange = Key<Bool>("selectTreeOnFocusChange", default: true)
}

enum AXpectorMode: String, CaseIterable, Identifiable {
    case inspector
    case observer

    // MARK: Internal

    var id: String { self.rawValue }
}

@MainActor
class AXpectorViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Init / Deinit

    init() {
        setupFilterDebouncer()
        startMonitoringPermissions()
        setupApplicationMonitoring()
        // Fetch initial list of applications
        fetchRunningApplications()
    }

    deinit {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        permissionTask?.cancel()
        permissionTask = nil

        // Remove app observers
        if let observer = appLaunchObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = appTerminateObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        windowRefreshTimer?.invalidate()
        windowRefreshTimer = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopHoverMonitoring()
            self.stopFocusTrackingMonitoring()
        }
    }

    // MARK: Internal

    struct AttributeDisplayInfo {
        let displayString: String
        let isSettable: Bool
        let settableDisplayString: String
        let navigatableElementRef: AXUIElement?
    }

    enum AXpectorError: Error, LocalizedError {
        case general(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .general(message): message
            }
        }
    }

    static let defaultFetchAttributes: [String] = [
        AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXTitleAttribute, AXAttributeNames.kAXSubroleAttribute,
        AXAttributeNames.kAXIdentifierAttribute, AXAttributeNames.kAXDescriptionAttribute,
        AXAttributeNames.kAXValueAttribute,
        AXAttributeNames.kAXSelectedTextAttribute, AXAttributeNames.kAXEnabledAttribute,
        AXAttributeNames.kAXFocusedAttribute,
        AXAttributeNames.kAXChildrenAttribute, AXAttributeNames.kAXRoleDescriptionAttribute,
    ]

    let axorcist = AXorcist()

    // Application List and Selection
    @Published var runningApplications: [NSRunningApplication] = []
    // Tree State
    @Published var accessibilityTree: [AXPropertyNode] = []
    var originalAccessibilityTree: [AXPropertyNode] = []
    @Published var isLoadingTree: Bool = false
    @Published var treeLoadingError: String?
    @Published var scrollToSelectedNode: AXPropertyNode.ID?

    // Interaction States
    @Published var actionStatusMessage: String?
    @Published var editingAttributeKey: String?
    @Published var editingAttributeValueString: String = ""
    @Published var attributeUpdateStatusMessage: String?
    var attributeIsCurrentlySettable: Bool = false
    var attributeSettableStatusCache: [String: Bool] = [:]
    var cachedNodeIDForSettableStatus: AXPropertyNode.ID?

    var attributeDisplayInfoCache: [String: AttributeDisplayInfo] = [:]
    var cachedNodeIDForDisplayInfo: AXPropertyNode.ID?

    // UI Helpers
    lazy var highlightWindowController = HighlightWindowController()

    // Permissions
    @Published var isAccessibilityEnabled: Bool?
    var permissionTask: Task<Void, Never>?
    // Fetch Depths
    let initialFetchDepth = 3
    let subsequentFetchDepth = 2

    @Published var hoveredElementInfo: String = "Enable hover mode to inspect elements with mouse."
    @Published var temporarilySelectedNodeIDByHover: AXPropertyNode.ID?
    var globalEventMonitor: Any?
    var hoverUpdateTask: Task<Void, Never>?

    @Published var focusedElementInfo: String = "Enable focus tracking mode."
    @Published var temporarilySelectedNodeIDByFocus: AXPropertyNode.ID?
    @Published var focusedElementAttributesDescription: String?
    var focusObserver: AXObserver?
    var appActivationObserver: AnyObject?
    var observedPIDForFocus: pid_t = 0
    @Published var autoSelectFocusedApp: Bool = true
    @Published var focusedElementsLog: [AXPropertyNode] = []

    // Filter/Search
    @Published var filterText: String = ""
    @Published var filteredAccessibilityTree: [AXPropertyNode] = []
    // Application monitoring
    var appLaunchObserver: NSObjectProtocol?
    var appTerminateObserver: NSObjectProtocol?
    var windowRefreshTimer: Timer?

    @Published var currentMode: AXpectorMode = .inspector {
        didSet {
            if oldValue != currentMode {
                // If switching away from inspector, or to observer, disable active interaction modes
                if currentMode == .observer || oldValue == .inspector {
                    if isHoverModeActive {
                        // stopHoverMonitoring() // Already called by isHoverModeActive.didSet
                        isHoverModeActive = false
                    }
                    if isFocusTrackingModeActive {
                        // stopFocusTrackingMonitoring() // Already called by isFocusTrackingModeActive.didSet
                        isFocusTrackingModeActive = false
                    }
                }
                // Potentially clear tree or selection if switching modes makes current state irrelevant
                // For now, tree is re-used, selection is mode-specific via different @State vars in View
            }
        }
    }

    @Published var selectedApplicationPID: pid_t? {
        didSet {
            if oldValue != selectedApplicationPID {
                if isHoverModeActive {
                    self.stopHoverMonitoring()
                    isHoverModeActive = false
                }
                if isFocusTrackingModeActive {
                    self.stopFocusTrackingMonitoring()
                    self.startFocusTrackingMonitoring()
                }
                if selectedApplicationPID == nil {
                    highlightWindowController.hideHighlight()
                }
                attributeSettableStatusCache.removeAll()
                cachedNodeIDForSettableStatus = nil
                editingAttributeKey = nil
                attributeUpdateStatusMessage = nil
                Task { // Wrap async call in Task
                    await fetchAccessibilityTreeForSelectedApp()
                }
            }
        }
    }

    @Published var selectedNode: AXPropertyNode? {
        didSet {
            updateHighlightForNode(selectedNode, isHover: false, isFocusHighlight: false)
            if oldValue?.id != selectedNode?.id {
                attributeSettableStatusCache.removeAll()
                cachedNodeIDForSettableStatus = selectedNode?.id
                editingAttributeKey = nil
                attributeUpdateStatusMessage = nil
            }
        }
    }

    // Mode States
    @Published var isHoverModeActive: Bool = false {
        didSet {
            if isHoverModeActive {
                if isFocusTrackingModeActive {
                    self.stopFocusTrackingMonitoring()
                    focusedElementInfo = "Enable focus tracking mode."
                    temporarilySelectedNodeIDByFocus = nil
                    isFocusTrackingModeActive = false
                }
                self.startHoverMonitoring()
                hoveredElementInfo = "Hover over an element...\nTree selection disabled."
                temporarilySelectedNodeIDByHover = nil
            } else {
                self.stopHoverMonitoring()
                hoveredElementInfo = "Enable hover mode to inspect elements with mouse."
                temporarilySelectedNodeIDByHover = nil
                if !isFocusTrackingModeActive {
                    highlightWindowController.hideHighlight()
                }
            }
        }
    }

    @Published var isFocusTrackingModeActive: Bool = false {
        didSet {
            if isFocusTrackingModeActive {
                if isHoverModeActive {
                    isHoverModeActive = false // This will trigger its didSet to stop hover
                }
                self.startFocusTrackingMonitoring()
                focusedElementInfo = "Tracking focused element..."
                temporarilySelectedNodeIDByFocus = nil
            } else {
                self.stopFocusTrackingMonitoring()
                focusedElementInfo = "Enable focus tracking mode."
                temporarilySelectedNodeIDByFocus = nil
                if !isHoverModeActive {
                    highlightWindowController.hideHighlight()
                }
            }
        }
    }

    @Published var debouncedFilterText: String = "" { didSet { applyFilter() } }
    @Published var searchInDisplayName: Bool = true { didSet { applyFilter() } }
    @Published var searchInRole: Bool = true { didSet { applyFilter() } }
    @Published var searchInTitle: Bool = true { didSet { applyFilter() } }
    @Published var searchInValue: Bool = true { didSet { applyFilter() } }
    @Published var searchInDescription: Bool = true { didSet { applyFilter() } }
    @Published var searchInPath: Bool = true { didSet { applyFilter() } }

    // MARK: - Main Actions / Toggles

    func toggleHoverMode() {
        isHoverModeActive.toggle()
    }

    func toggleFocusTrackingMode() {
        isFocusTrackingModeActive.toggle()
    }

    // MARK: - Element Interaction

    func performAction(_ actionName: String, on node: AXPropertyNode?) {
        guard let targetNode = node else {
            axWarningLog("PerformAction: Nil node."); actionStatusMessage = "Error: No node selected."; return
        }
        axInfoLog("PerformAction: \\(actionName) on \\(targetNode.displayName)")
        actionStatusMessage = "Performing: \\(actionName)..."
        Task {
            let appIdentifier = targetNode.pid != 0 ? String(targetNode.pid) : nil
            var stringCriteria: [String: String] = [:] // Renamed for clarity
            if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = targetNode.attributes[AXAttributeNames.kAXTitleAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = targetNode.attributes[AXAttributeNames.kAXIdentifierAttribute]?
                .value as? String { stringCriteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if stringCriteria.isEmpty {
                if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String,
                   role == AXRoleNames.kAXStaticTextRole as String
                {
                    if let value = targetNode.attributes[AXAttributeNames.kAXValueAttribute]?.value as? String,
                       !value.isEmpty { stringCriteria[AXAttributeNames.kAXValueAttribute] = value }
                    else { stringCriteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
                } else { stringCriteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
            }

            let criteriaForLocator = axConvertStringCriteriaToCriterionArray(stringCriteria)
            let pathHintsForLocator = axConvertStringPathHintsToComponentArray(targetNode.fullPathArrayForLocator)
            let locator = Locator(criteria: criteriaForLocator, rootElementPathHint: pathHintsForLocator)

            axInfoLog(
                "Performing action: \(actionName) on \(targetNode.displayName)",
                details: ["commandID": AnyCodable("performAction_\(actionName)"), "appName": AnyCodable(appIdentifier)]
            )
            let performActionCommand = PerformActionCommand(
                appIdentifier: appIdentifier,
                locator: locator,
                action: actionName,
                value: nil,
                maxDepthForSearch: AXMiscConstants.defaultMaxDepthSearch
            )
            let response = axorcist.handlePerformAction(command: performActionCommand)
            if Defaults[.verboseLogging_axpector] {
                let collectedLogs = axGetLogEntries()
                for logEntry in collectedLogs {
                    axDebugLog(
                        "AXorcist (PerformAction) Log: \(logEntry.message) [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]",
                        details: logEntry.details
                    )
                }
                axClearLogs()
            }
            if response.error == nil, let responseData = response.payload?.value as? PerformResponse,
               responseData.success
            {
                self.actionStatusMessage = "Action \"\(actionName)\" successful."
                axInfoLog("Successfully performed action \"\(actionName)\" on node \(targetNode.displayName).")
            } else {
                let errorMessage = response.error?.message ?? "Failed to perform action \"\(actionName)\""
                self.actionStatusMessage = "Failed to perform action \"\(actionName)\": \(errorMessage)"
                axErrorLog(
                    "Failed to perform action \"\(actionName)\" on node \(targetNode.displayName). Error: \(errorMessage)"
                )
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if self.actionStatusMessage?.contains(actionName) == true { self.actionStatusMessage = nil }
            }
        }
    }

    // MARK: - Accessibility Tree Fetching

    func fetchAccessibilityTreeForSelectedApp() async {
        guard let pid = selectedApplicationPID else {
            self.accessibilityTree = []
            self.originalAccessibilityTree = []
            self.filteredAccessibilityTree = []
            self.selectedNode = nil
            self.treeLoadingError = "No application selected."
            return
        }
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            self.treeLoadingError = "Application with PID \(pid) not found."
            self.accessibilityTree = []
            self.originalAccessibilityTree = []
            self.filteredAccessibilityTree = []
            self.isLoadingTree = false
            return
        }
        let appName = app.localizedName ?? "Unknown App"
        axInfoLog("Fetching accessibility tree for: \(appName) (PID: \(pid)) with depth \(self.initialFetchDepth)")
        self.isLoadingTree = true; self.treeLoadingError = nil; self.accessibilityTree = []; self
            .originalAccessibilityTree = []; self.filteredAccessibilityTree = []
        let currentAppName = appName; let currentPid = pid
        let commandID =
            "fetchTree_\(currentAppName.filter { $0.isLetter || $0.isNumber })_\(UUID().uuidString.prefix(6))"
        Task.detached { [weak self, currentAppName, currentPid, commandID] in
            guard let strongSelf = self
            else { axWarningLog("AXpectorViewModel deallocated before fetch for \(currentAppName)."); return }
            await strongSelf.performTreeFetchAndProcess(appName: currentAppName, pid: currentPid, commandID: commandID)
        }
    }

    // MARK: - Hover Mode Implementation (MOVED FROM EXTENSION)

    func startHoverMonitoring() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.hoverUpdateTask?.cancel()
            self?.hoverUpdateTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                guard let self else { return }
                await self.updateHoveredElement(at: NSEvent.mouseLocation)
            }
        }
        if globalEventMonitor == nil { isHoverModeActive = false } // Ensure flag is correct if monitor fails
    }

    func stopHoverMonitoring() {
        hoverUpdateTask?.cancel()
        if let monitor = globalEventMonitor { NSEvent.removeMonitor(monitor); globalEventMonitor = nil }
    }

    func updateHoveredElement(at mouseLocation: NSPoint) async {
        guard isHoverModeActive, let pid = selectedApplicationPID else { return }
        axInfoLog(
            "Updating hovered element",
            details: ["commandID": AnyCodable("hover_\(pid)"), "appName": AnyCodable(String(pid))]
        )

        let getElementCommand = GetElementAtPointCommand(
            point: mouseLocation,
            pid: Int(pid),
            attributesToReturn: Self.defaultFetchAttributes
        )
        let getElementResult = axorcist.handleGetElementAtPoint(command: getElementCommand)

        var newHoverInfo = "Hover: No element."

        if let axElementData = getElementResult.payload?.value as? AXElementData {
            // Comment out lines that depend on axUiElement since AXElementData doesn't have underlyingElement
            // let axUiElement = axElementData.underlyingElement
            // let tempEl = Element(axUiElement)
            // let roleValue = tempEl.role() ?? "N/A"
            // let titleValue = tempEl.title() ?? ""

            // let titlePartFormatted = titleValue.isEmpty ? "" : " - \"\(titleValue.prefix(30))\""
            // newHoverInfo = "Hover: \(roleValue)\(titlePartFormatted)"
            newHoverInfo = "Hover: \(String(describing: axElementData.briefDescription))"

        } else if let errorMsg = getElementResult.error?.message {
            newHoverInfo = "Hover Error: \(errorMsg)"
        }

        await MainActor.run {
            self.hoveredElementInfo = newHoverInfo
            self.temporarilySelectedNodeIDByHover = nil
            self.highlightWindowController.hideHighlight()
        }
        axInfoLog("Finished updating hovered element")
    }

    // Synchronous helper (MOVED FROM EXTENSION)
    func getFrameForAXElement(_ axElement: AXUIElement?) -> NSRect? {
        guard let element = axElement else { return nil }
        var positionRef: CFTypeRef?; var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = positionRef, CFGetTypeID(posVal) == AXValueGetTypeID(),
              let sizeVal = sizeRef, CFGetTypeID(sizeVal) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero; var size = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        return NSRect(origin: position, size: size)
    }

    // updateHighlightForAXUIElement was also in an extension, moving it too for good measure
    // (MOVED FROM EXTENSION)
    func updateHighlightForAXUIElement(_ axElement: AXUIElement?, color: NSColor) {
        guard let element = axElement else {
            highlightWindowController.hideHighlight()
            return
        }
        if let frame = getFrameForAXElement(element) {
            highlightWindowController.showHighlight(at: frame, color: color, borderWidth: nil)
        } else {
            highlightWindowController.hideHighlight()
        }
    }

    // MARK: Private

    private var permissionCheckTimer: Timer?

    private func performTreeFetchAndProcess(appName: String, pid: Int32, commandID: String) async {
        axInfoLog(
            "Performing tree fetch: \(appName)",
            details: ["commandID": AnyCodable(commandID), "appName": AnyCodable(appName)]
        )

        let appElementAXUI = AXUIElementCreateApplication(pid)
        let rootElement = Element(appElementAXUI)

        let nodes = await recursivelyFetchChildren(
            forElement: rootElement,
            pid: pid,
            depthOfElementToFetchChildrenFor: 0,
            currentExpansionLevel: 0,
            maxExpansionLevels: initialFetchDepth,
            pathOfElementToFetchChildrenFor: ""
        )

        // Call the new MainActor UI update function
        await updateTreeUI(nodes: nodes, appName: appName, pid: pid, appElementAXUI: appElementAXUI)
    }

    @MainActor
    private func updateTreeUI(nodes: [AXPropertyNode], appName: String, pid: pid_t, appElementAXUI: AXUIElement) async {
        self.isLoadingTree = false
        self.treeLoadingError = nil

        if !nodes.isEmpty {
            let (attributes, _) = await getElementAttributes(
                element: Element(appElementAXUI),
                attributes: Self.defaultFetchAttributes,
                outputFormat: .jsonString
            )

            let appNode = AXPropertyNode(
                id: UUID(),
                axElementRef: appElementAXUI,
                pid: pid,
                role: attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "Application",
                title: appName,
                descriptionText: "",
                value: "",
                fullPath: appName,
                children: nodes,
                attributes: attributes,
                actions: Element(appElementAXUI).supportedActions() ?? [], // Get actions from Element
                hasChildrenAXProperty: !nodes.isEmpty,
                depth: 0
            )
            appNode.areChildrenFullyLoaded = true // Since initial fetch depth loads them

            self.accessibilityTree = [appNode]
            self.originalAccessibilityTree = [appNode]
        } else {
            self.accessibilityTree = []
            self.originalAccessibilityTree = []
        }

        self.applyFilter() // This should also be on MainActor if it modifies @Published properties
        axInfoLog("Finished tree UI update for: \(appName)")
    }

    // MARK: - Hover and Focus Helpers (Highlights)

    private func highlightElementAtPoint(_ point: NSPoint) async {
        guard let pid = selectedApplicationPID else { return }

        // axorcist.getElementAtPoint returns (element: AXElement?, error: String?)
        let getElementCommand = GetElementAtPointCommand(
            point: point,
            pid: Int(pid),
            attributesToReturn: Self.defaultFetchAttributes
        )
        let getElementResult = axorcist.handleGetElementAtPoint(command: getElementCommand)

        if let axElementData = getElementResult.payload?.value as? AXElementData {
            // Comment out lines that depend on axUiElement since AXElementData doesn't have underlyingElement
            // let axUiElement = axElementData.underlyingElement
            // let el = Element(axUiElement) // axUiElement is AXUIElement, wrap it
            let briefDesc = axElementData.briefDescription
            // Careful with multi-line string for hoveredElementInfo
            hoveredElementInfo = "Hovered: \(String(describing: briefDesc))"
            // Comment out lines that require the actual AXUIElement reference
            // if let appTree = self.accessibilityTree.first, appTree.pid == pid,
            //    let foundNode = findNodeByAXElement(axUiElement, in: [appTree]) { // Use axUiElement directly
            //     temporarilySelectedNodeIDByHover = foundNode.id
            //     updateHighlightForNode(foundNode, isHover: true, isFocusHighlight: false)
            // } else {
            //     temporarilySelectedNodeIDByHover = nil
            //     updateHighlightForAXUIElement(axUiElement, color: NSColor.systemYellow) // Use axUiElement
            // }
            temporarilySelectedNodeIDByHover = nil
        } else {
            hoveredElementInfo =
                "Hovered: Nothing found at point. Error: \(getElementResult.error?.message ?? "Unknown")"
            temporarilySelectedNodeIDByHover = nil
            highlightWindowController.hideHighlight()
        }
    }
}
