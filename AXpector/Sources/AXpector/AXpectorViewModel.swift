import SwiftUI
import Combine
import AppKit
import AXorcist
import Defaults

// Define the key locally if not accessible from main app target's DefaultsKeys
extension Defaults.Keys {
    static let verboseLogging_axpector = Key<Bool>("verboseLogging", default: false)
}

@MainActor
class AXpectorViewModel: ObservableObject {
    // MARK: - Properties
    internal let axorcist = AXorcist()

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
                fetchAccessibilityTreeForSelectedApp()
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
    internal var focusObserver: AXObserver?
    internal var appActivationObserver: AnyObject?
    internal var observedPIDForFocus: pid_t = 0
    @Published var autoSelectFocusedApp: Bool = true

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

    // MARK: - Init / Deinit
    init() {
        setupFilterDebouncer()
    }

    deinit {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
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
            var criteria: [String: String] = [:]
            if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String { criteria[AXAttributeNames.kAXRoleAttribute] = role }
            if let title = targetNode.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String { criteria[AXAttributeNames.kAXTitleAttribute] = title }
            if let identifier = targetNode.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String { criteria[AXAttributeNames.kAXIdentifierAttribute] = identifier }
            if criteria.isEmpty {
                if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String, role == AXRoleNames.kAXStaticTextRole as String {
                     if let value = targetNode.attributes[AXAttributeNames.kAXValueAttribute]?.value as? String, !value.isEmpty { criteria[AXAttributeNames.kAXValueAttribute] = value }
                     else { criteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
                } else { criteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName }
            }
            let locator = Locator(criteria: criteria, rootElementPathHint: targetNode.fullPathArrayForLocator)
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

    // MARK: - Accessibility Tree Loading
    internal func fetchAccessibilityTreeForSelectedApp(forceReload: Bool = false) {
        guard let pid = selectedApplicationPID else {
            axWarningLog("Attempted to fetch tree with no application selected.")
            self.accessibilityTree = []; self.originalAccessibilityTree = []; self.filteredAccessibilityTree = []; self.selectedNode = nil
            self.treeLoadingError = "No application selected."
            return
        }
        guard let app = runningApplications.first(where: { $0.processIdentifier == pid }) else {
            axWarningLog("Application with PID \(pid) not found.")
            self.treeLoadingError = "Application with PID \(pid) not found."; self.accessibilityTree = []; self.originalAccessibilityTree = []; self.filteredAccessibilityTree = []
            self.isLoadingTree = false
            return
        }
        let appName = app.localizedName ?? app.bundleIdentifier ?? "App PID \(pid)"
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
        func processResponse(json: String) -> (nodes: [AXPropertyNode]?, error: String?) {
            guard let jsonData = json.data(using: .utf8) else { return (nil, "JSON to Data conversion failed.") }
            do {
                let output = try JSONDecoder().decode(CollectAllOutput.self, from: jsonData)
                if output.success { return (output.collectedElements.map { self.mapJsonAXElementToNode($0, pid: pid, currentDepth: 0, parentPath: "") }, nil) } 
                else { return (nil, output.errorMessage ?? "Unknown AXorcist error.") }
            } catch { return (nil, "JSON Decode error: \\(error.localizedDescription).") }
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: commandID, appName: appName)
        let jsonResponse = axorcist.handleCollectAll(for: appName, locator: nil, pathHint: nil, maxDepth: initialFetchDepth, requestedAttributes: Self.defaultFetchAttributes, outputFormat: .jsonString, commandId: commandID)
        let result = processResponse(json: jsonResponse)
        await MainActor.run {
            self.isLoadingTree = false; self.treeLoadingError = result.error
            if let nodes = result.nodes { self.accessibilityTree = nodes; self.originalAccessibilityTree = nodes } 
            else { self.accessibilityTree = []; self.originalAccessibilityTree = [] }
            self.applyFilter() 
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
    }

    enum AXpectorError: Error, LocalizedError {
        case general(String)
        var errorDescription: String? {
            switch self {
            case .general(let message): return message
            }
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
        let response = axorcist.getElementAtPoint(pid: pid, point: mouseLocation, requestedAttributes: Self.defaultFetchAttributes)
        
        var newHoverInfo: String = "Hover: No element."

        if let codableElement = response.data?.value as? AXElement { 
            let roleValue = codableElement.attributes?[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "N/A"
            let titleValue = codableElement.attributes?[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? ""
            
            let titlePart = titleValue.isEmpty ? "" : " - \\\"\\(titleValue.prefix(30))\\\""
            newHoverInfo = "Hover: \(roleValue)\(titlePart)"
 
        } else if let errorMsg = response.error {
            newHoverInfo = "Hover Error: \(errorMsg)"
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

