import SwiftUI
import Combine
import AppKit
import AXorcist
import Defaults

// Define the key locally if not accessible from main app target's DefaultsKeys
extension Defaults.Keys {
    static let verboseLogging_axpector = Key<Bool>("verboseLogging", default: false)
}

enum AXpectorMode: String, CaseIterable, Identifiable {
    case inspector
    case observer

    var id: String { self.rawValue }
}

@MainActor
class AXpectorViewModel: ObservableObject {
    // MARK: - Properties
    internal let axorcist = AXorcist()

    @Published var currentMode: AXpectorMode = .inspector {
        didSet {
            if oldValue != currentMode {
                // If switching away from inspector, or to observer, disable active interaction modes
                if currentMode == .observer || oldValue == .inspector {
                    if isHoverModeActive {
                        //stopHoverMonitoring() // Already called by isHoverModeActive.didSet
                        isHoverModeActive = false
                    }
                    if isFocusTrackingModeActive {
                        //stopFocusTrackingMonitoring() // Already called by isFocusTrackingModeActive.didSet
                        isFocusTrackingModeActive = false
                    }
                }
                // Potentially clear tree or selection if switching modes makes current state irrelevant
                // For now, tree is re-used, selection is mode-specific via different @State vars in View
            }
        }
    }

    // Application List and Selection
    @Published var runningApplications: [NSRunningApplication] = []
    @Published var selectedApplicationPID: pid_t? {
        didSet {
            if oldValue != selectedApplicationPID {
                if isHoverModeActive {
                    stopHoverMonitoring() // This will be in an extension
                    isHoverModeActive = false
                }
                if isFocusTrackingModeActive {
                    stopFocusTrackingMonitoring() // Assume this exists or will be added
                    startFocusTrackingMonitoring() // Assume this exists or will be added
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

    // Tree State
    @Published var accessibilityTree: [AXPropertyNode] = []
    internal var originalAccessibilityTree: [AXPropertyNode] = []
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
    @Published var isLoadingTree: Bool = false
    @Published var treeLoadingError: String? = nil

    // Interaction States
    @Published var actionStatusMessage: String? = nil
    @Published var editingAttributeKey: String? = nil
    @Published var editingAttributeValueString: String = ""
    @Published var attributeUpdateStatusMessage: String? = nil
    internal var attributeIsCurrentlySettable: Bool = false
    internal var attributeSettableStatusCache: [String: Bool] = [:]
    internal var cachedNodeIDForSettableStatus: AXPropertyNode.ID? = nil
    
    internal struct AttributeDisplayInfo {
        let displayString: String
        let valueType: AXAttributeValueType
        let isSettable: Bool
        let settableDisplayString: String
        let navigatableElementRef: AXUIElement?
    }
    internal var attributeDisplayInfoCache: [String: AttributeDisplayInfo] = [:]
    internal var cachedNodeIDForDisplayInfo: AXPropertyNode.ID? = nil

    // UI Helpers
    internal lazy var highlightWindowController = HighlightWindowController()

    // Permissions
    @Published var isAccessibilityEnabled: Bool? = nil
    private var permissionCheckTimer: Timer?
    internal var permissionTask: Task<Void, Never>?

    // Fetch Depths
    internal let initialFetchDepth = 3
    internal let subsequentFetchDepth = 2

    // Mode States
    @Published var isHoverModeActive: Bool = false {
        didSet {
            if isHoverModeActive {
                if isFocusTrackingModeActive {
                    stopFocusTrackingMonitoring() // Assumed to exist
                    focusedElementInfo = "Enable focus tracking mode."
                    temporarilySelectedNodeIDByFocus = nil
                    isFocusTrackingModeActive = false
                }
                startHoverMonitoring() // This will be in an extension
                hoveredElementInfo = "Hover over an element...\nTree selection disabled."
                temporarilySelectedNodeIDByHover = nil
            } else {
                stopHoverMonitoring() // This will be in an extension
                hoveredElementInfo = "Enable hover mode to inspect elements with mouse."
                temporarilySelectedNodeIDByHover = nil
                if !isFocusTrackingModeActive {
                    highlightWindowController.hideHighlight()
                }
            }
        }
    }
    @Published var hoveredElementInfo: String = "Enable hover mode to inspect elements with mouse."
    @Published var temporarilySelectedNodeIDByHover: AXPropertyNode.ID?
    internal var globalEventMonitor: Any?
    internal var hoverUpdateTask: Task<Void, Never>?

    @Published var isFocusTrackingModeActive: Bool = false {
        didSet {
            if isFocusTrackingModeActive {
                if isHoverModeActive {
                    isHoverModeActive = false // This will trigger its didSet to stop hover
                }
                startFocusTrackingMonitoring() // Assumed to exist
                focusedElementInfo = "Tracking focused element..."
                temporarilySelectedNodeIDByFocus = nil
            } else {
                stopFocusTrackingMonitoring() // Assumed to exist
                focusedElementInfo = "Enable focus tracking mode."
                temporarilySelectedNodeIDByFocus = nil
                if !isHoverModeActive {
                    highlightWindowController.hideHighlight()
                }
            }
        }
    }
    @Published var focusedElementInfo: String = "Enable focus tracking mode."
    @Published var temporarilySelectedNodeIDByFocus: AXPropertyNode.ID?
    @Published var focusedElementAttributesDescription: String? = nil
    internal var focusObserver: AXObserver?
    internal var appActivationObserver: AnyObject?
    internal var observedPIDForFocus: pid_t = 0
    @Published var autoSelectFocusedApp: Bool = true
    @Published var focusedElementsLog: [AXPropertyNode] = []

    // Filter/Search
    @Published var filterText: String = ""
    @Published var debouncedFilterText: String = "" { didSet { applyFilter() } }
    @Published var filteredAccessibilityTree: [AXPropertyNode] = []
    @Published var searchInDisplayName: Bool = true { didSet { applyFilter() } }
    @Published var searchInRole: Bool = true { didSet { applyFilter() } }
    @Published var searchInTitle: Bool = true { didSet { applyFilter() } }
    @Published var searchInValue: Bool = true { didSet { applyFilter() } }
    @Published var searchInDescription: Bool = true { didSet { applyFilter() } }
    @Published var searchInPath: Bool = true { didSet { applyFilter() } }

    // Application monitoring
    internal var appLaunchObserver: NSObjectProtocol?
    internal var appTerminateObserver: NSObjectProtocol?
    internal var windowRefreshTimer: Timer?
    
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
            guard let self = self else { return }
            self.stopHoverMonitoring() // This will be in an extension
            self.stopFocusTrackingMonitoring() // Assumed to exist
        }
    }

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
            if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String { stringCriteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = targetNode.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String { stringCriteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = targetNode.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String { stringCriteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if stringCriteria.isEmpty {
                if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String, role == AXRoleNames.kAXStaticTextRole as String {
                     if let value = targetNode.attributes[AXAttributeNames.kAXValueAttribute]?.value as? String, !value.isEmpty { stringCriteria[AXAttributeNames.kAXValueAttribute] = value }
                     else { stringCriteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
                } else { stringCriteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
            }
            
            let criteriaForLocator = axConvertStringCriteriaToCriterionArray(stringCriteria)
            let pathHintsForLocator = axConvertStringPathHintsToComponentArray(targetNode.fullPathArrayForLocator)
            let locator = Locator(criteria: criteriaForLocator, rootElementPathHint: pathHintsForLocator)
            
            await GlobalAXLogger.shared.updateOperationDetails(commandID: "performAction_\\(actionName)", appName: appIdentifier)
            let response = await axorcist.handlePerformAction(for: appIdentifier, locator: locator, actionName: actionName)
            if Defaults[.verboseLogging_axpector] {
                let collectedLogs = await axGetLogEntries()
                for logEntry in collectedLogs { 
                    axDebugLog("AXorcist (PerformAction) Log: \\(logEntry.message) [L:\\(logEntry.level.rawValue) T:\\(logEntry.timestamp)]", details: logEntry.details)
                }
                await axClearLogs()
            }
            if response.error == nil, let responseData = response.data?.value as? PerformResponse, responseData.success {
                self.actionStatusMessage = "Action \\\"\\(actionName)\\\" successful."
                axInfoLog("Successfully performed action \"\(actionName)\" on node \(targetNode.displayName).")
            } else {
                let errorMessage = response.error ?? "Failed to perform action \"\(actionName)\""
                self.actionStatusMessage = "Failed to perform action \"\(actionName)\": \(errorMessage)"
                axErrorLog("Failed to perform action \"\(actionName)\" on node \(targetNode.displayName). Error: \(errorMessage)")
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if self.actionStatusMessage?.contains(actionName) == true { self.actionStatusMessage = nil }
            }
        }
    }

    static let defaultFetchAttributes: [String] = [
        AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXTitleAttribute, AXAttributeNames.kAXSubroleAttribute,
        AXAttributeNames.kAXIdentifierAttribute, AXAttributeNames.kAXDescriptionAttribute, AXAttributeNames.kAXValueAttribute,
        AXAttributeNames.kAXSelectedTextAttribute, AXAttributeNames.kAXEnabledAttribute, AXAttributeNames.kAXFocusedAttribute,
        AXAttributeNames.kAXChildrenAttribute, AXAttributeNames.kAXRoleDescriptionAttribute
    ]

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
        self.isLoadingTree = true; self.treeLoadingError = nil; self.accessibilityTree = []; self.originalAccessibilityTree = []; self.filteredAccessibilityTree = []
        let currentAppName = appName; let currentPid = pid
        let commandID = "fetchTree_\(currentAppName.filter { $0.isLetter || $0.isNumber })_\(UUID().uuidString.prefix(6))"
        Task.detached { [weak self, currentAppName, currentPid, commandID] in
            guard let strongSelf = self else { axWarningLog("AXpectorViewModel deallocated before fetch for \(currentAppName)."); return }
            await strongSelf.performTreeFetchAndProcess(appName: currentAppName, pid: currentPid, commandID: commandID)
        }
    }

    private func performTreeFetchAndProcess(appName: String, pid: Int32, commandID: String) async {
        await GlobalAXLogger.shared.updateOperationDetails(commandID: commandID, appName: appName)
        
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
            let (attributes, _) = await getElementAttributes(element: Element(appElementAXUI), attributes: Self.defaultFetchAttributes, outputFormat: .jsonString)
            
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
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil) // Log ending on main actor too
    }

    enum AXpectorError: Error, LocalizedError {
        case general(String)
        var errorDescription: String? {
            switch self {
            case .general(let message): return message
            }
        }
    }

    // MARK: - Hover and Focus Helpers (Highlights)
    private func highlightElementAtPoint(_ point: NSPoint) async {
        guard let pid = selectedApplicationPID else { return }
        
        // axorcist.getElementAtPoint returns (element: AXElement?, error: String?)
        let getElementResult = await axorcist.getElementAtPoint(pid: pid, point: point, requestedAttributes: Self.defaultFetchAttributes)

        if let axUiElement = getElementResult.element { // Use .element from the tuple
            let el = Element(axUiElement) // axUiElement is AXUIElement, wrap it
            let role = el.role()
            let title = el.title()
            let briefDesc = el.briefDescription(includeRole: true, includeTitle: true, includeValue: false, includeDescription: false)
            // Careful with multi-line string for hoveredElementInfo
            hoveredElementInfo = "Hovered: \(briefDesc)\nRole: \(role ?? "N/A")\nTitle: \(title ?? "N/A")"
            if let appTree = self.accessibilityTree.first, appTree.pid == pid, 
               let foundNode = findNodeByAXElement(axUiElement, in: [appTree]) { // Use axUiElement directly
                temporarilySelectedNodeIDByHover = foundNode.id
                updateHighlightForNode(foundNode, isHover: true, isFocusHighlight: false)
            } else {
                temporarilySelectedNodeIDByHover = nil
                updateHighlightForAXUIElement(axUiElement, color: NSColor.systemYellow) // Use axUiElement
            }
        } else {
            hoveredElementInfo = "Hovered: Nothing found at point. Error: \(getElementResult.error ?? "Unknown")"
            temporarilySelectedNodeIDByHover = nil
            highlightWindowController.hideHighlight()
        }
    }
}

// MARK: - Hover Mode Implementation
extension AXpectorViewModel {
    internal func startHoverMonitoring() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.hoverUpdateTask?.cancel()
            self?.hoverUpdateTask = Task {
                try? await Task.sleep(for: .milliseconds(100)) 
                if Task.isCancelled { return }
                guard let self = self else { return }
                await self.updateHoveredElement(at: NSEvent.mouseLocation) 
            }
        }
        if globalEventMonitor == nil { isHoverModeActive = false }
    }

    internal func stopHoverMonitoring() {
        hoverUpdateTask?.cancel()
        if let monitor = globalEventMonitor { NSEvent.removeMonitor(monitor); globalEventMonitor = nil }
    }

    internal func updateHoveredElement(at mouseLocation: NSPoint) async { 
        guard isHoverModeActive, let pid = selectedApplicationPID else { return }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: "hover_\(pid)", appName: String(pid))
        
        // axorcist.getElementAtPoint returns (element: AXElement?, error: String?)
        let getElementResult = await axorcist.getElementAtPoint(pid: pid, point: mouseLocation, requestedAttributes: Self.defaultFetchAttributes)
        
        var newHoverInfo: String = "Hover: No element."

        // getElementResult.element is AXUIElement directly
        if let axUiElement = getElementResult.element {
            // To get attributes like role and title, we need to wrap axUiElement in an Element
            // or use the attributes already fetched if getElementAtPoint is modified to return them.
            // For now, let's assume getElementAtPoint returns requestedAttributes in its AXElement wrapper if it changes.
            // Based on current axorcist.getElementAtPoint, it returns AXUIElement, not AXElement struct with attributes.
            // This part needs to be re-evaluated based on what getElementAtPoint actually returns or if we need another fetch.
            // For simplicity, if getElementResult.element is AXUIElement, let's just make a brief description from it.
            let tempEl = Element(axUiElement)
            let roleValue = tempEl.role() ?? "N/A"
            let titleValue = tempEl.title() ?? ""
            
            let titlePart = titleValue.isEmpty ? "" : " - \\\"\\(titleValue.prefix(30))\\\""
            newHoverInfo = "Hover: \\(roleValue)\\(titlePart)"
 
        } else if let errorMsg = getElementResult.error {
            newHoverInfo = "Hover Error: \\(errorMsg)"
        }
        
        await MainActor.run {
            self.hoveredElementInfo = newHoverInfo
            self.temporarilySelectedNodeIDByHover = nil
            self.highlightWindowController.hideHighlight()
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
    }

    // Synchronous helper
    internal func getFrameForAXElement(_ axElement: AXUIElement?) -> NSRect? {
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
}

// Add the missing helper function
extension AXpectorViewModel {
    internal func updateHighlightForAXUIElement(_ axElement: AXUIElement?, color: NSColor) {
        guard let element = axElement else {
            highlightWindowController.hideHighlight()
            return
        }
        if let frame = getFrameForAXElement(element) {
            highlightWindowController.highlight(rect: frame, color: color)
        } else {
            highlightWindowController.hideHighlight()
        }
    }
}

