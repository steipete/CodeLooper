import SwiftUI
import Combine
import AppKit // For NSRunningApplication, AXUIElement, AXObserver, pid_t. Some might be movable to extensions.
import AXorcist
// AXorcist import already includes logging utilities
import Defaults // ADD for Defaults[.verboseLogging]

// Define the key locally if not accessible from main app target's DefaultsKeys
extension Defaults.Keys {
    static let verboseLogging_axpector = Key<Bool>("verboseLogging", default: false)
}

@MainActor
class AXpectorViewModel: ObservableObject {
    // MARK: - Properties
    
    // Central Services/Helpers
    // internal let logger = Logger(subsystem: "com.CodeLooper.AXpector", category: "ViewModel") // REMOVE OSLog based logger
    internal let axorcist = AXorcist()

    // Application List and Selection
    @Published var runningApplications: [NSRunningApplication] = []
    @Published var selectedApplicationPID: pid_t? {
        didSet {
            if oldValue != selectedApplicationPID {
                if isHoverModeActive {
                    stopHoverMonitoring()
                    isHoverModeActive = false
                }
                
                if isFocusTrackingModeActive {
                    stopFocusTrackingMonitoring()
                    startFocusTrackingMonitoring()
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

    // Interaction States (Action, Attribute Editing)
    @Published var actionStatusMessage: String? = nil
    @Published var editingAttributeKey: String? = nil
    @Published var editingAttributeValueString: String = ""
    @Published var attributeUpdateStatusMessage: String? = nil
    internal var attributeIsCurrentlySettable: Bool = false 
    internal var attributeSettableStatusCache: [String: Bool] = [:]
    internal var cachedNodeIDForSettableStatus: AXPropertyNode.ID? = nil

    // Moved from AXpectorViewModel+AttributeEditing.swift
    internal struct AttributeDisplayInfo { // Make internal if only used by ViewModel and its extensions
        let displayString: String
        let valueType: AXAttributeValueType
        let isSettable: Bool
        let settableDisplayString: String // e.g., " (W)" or ""
        let navigatableElementRef: AXUIElement? // Only non-nil if valueType is .axElement
        // For .arrayOfAXElements, we might need a different structure or handle navigation separately
    }
    
    internal var attributeDisplayInfoCache: [String: AttributeDisplayInfo] = [:] // Keyed by attributeName
    internal var cachedNodeIDForDisplayInfo: AXPropertyNode.ID? = nil

    // Highlight Window
    internal lazy var highlightWindowController = HighlightWindowController()

    // Permissions
    @Published var isAccessibilityEnabled: Bool? = nil

    // Fetch Depths
    internal let initialFetchDepth = 3 
    internal let subsequentFetchDepth = 2 

    // Hover Mode
    @Published var isHoverModeActive: Bool = false {
        didSet {
            if isHoverModeActive {
                if isFocusTrackingModeActive {
                    stopFocusTrackingMonitoring()
                    focusedElementInfo = "Enable focus tracking mode."
                    temporarilySelectedNodeIDByFocus = nil
                    isFocusTrackingModeActive = false 
                }
                startHoverMonitoring()
                hoveredElementInfo = "Hover over an element...\nTree selection disabled."
                temporarilySelectedNodeIDByHover = nil 
            } else {
                stopHoverMonitoring()
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

    // Focus Tracking Mode
    @Published var isFocusTrackingModeActive: Bool = false {
        didSet {
            if isFocusTrackingModeActive {
                if isHoverModeActive {
                    isHoverModeActive = false 
                }
                startFocusTrackingMonitoring()
                focusedElementInfo = "Tracking focused element..."
                temporarilySelectedNodeIDByFocus = nil 
            } else {
                stopFocusTrackingMonitoring()
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
    @Published var filterText: String = "" {
        didSet {
            // Debouncer handles calling applyFilter via debouncedFilterText
        }
    }
    @Published var debouncedFilterText: String = "" {
        didSet {
            applyFilter()
        }
    }
    @Published var filteredAccessibilityTree: [AXPropertyNode] = []
    @Published var searchInDisplayName: Bool = true { didSet { applyFilter() } }
    @Published var searchInRole: Bool = true { didSet { applyFilter() } }
    @Published var searchInTitle: Bool = true { didSet { applyFilter() } }
    @Published var searchInValue: Bool = true { didSet { applyFilter() } }
    @Published var searchInDescription: Bool = true { didSet { applyFilter() } }
    @Published var searchInPath: Bool = true { didSet { applyFilter() } }
    
    // Note: AXIdentifier is handled by key:id, not a general text search field toggle here.

    // MARK: - Attribute Editing State
    // Internal struct definitions for filtering are now in AXpectorViewModel+Filtering.swift

    // MARK: - Init / Deinit
    init() {
        checkAccessibilityPermissions(initialCheck: true, promptIfNeeded: false) 
        fetchRunningApplications()
        setupFilterDebouncer() 
        // Subscribe to GlobalAXLogger if needed for real-time log display in UI
        // GlobalAXLogger.shared.addSubscriber(self) // Example if ViewModel conforms to AXLogSubscriber
    }

    deinit {
        Task { @MainActor [weak self] in // Ensure cleanup happens on main actor, capture self weakly
            guard let self = self else { return }
            self.stopHoverMonitoring()
            self.stopFocusTrackingMonitoring()
        }
        // GlobalAXLogger.shared.removeSubscriber(self) // Example
    }

    // MARK: - Main Actions / Toggles
    func toggleHoverMode() {
        isHoverModeActive.toggle()
    }

    func toggleFocusTrackingMode() {
        isFocusTrackingModeActive.toggle()
    }

    func performAction(_ actionName: String, on node: AXPropertyNode?) {
        guard let targetNode = node else {
            axWarningLog("Attempted to perform action \"\(actionName)\" on a nil node.")
            actionStatusMessage = "Error: No node selected to perform action on."
            return
        }

        axInfoLog("Attempting to perform action \"\(actionName)\" on node: \(targetNode.displayName) (Path: \(targetNode.fullPath))")
        actionStatusMessage = "Performing action: \(actionName)..."

        Task {
            let appIdentifier = targetNode.pid != 0 ? String(targetNode.pid) : nil
            
            var criteria: [String: String] = [:]
            if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String {
                criteria[AXAttributeNames.kAXRoleAttribute] = role
            }
            if let title = targetNode.attributes[AXAttributeNames.kAXTitleAttribute]?.value as? String {
                criteria[AXAttributeNames.kAXTitleAttribute] = title
            }
            if let identifier = targetNode.attributes[AXAttributeNames.kAXIdentifierAttribute]?.value as? String {
                 criteria[AXAttributeNames.kAXIdentifierAttribute] = identifier
            }
            if criteria.isEmpty {
                if let role = targetNode.attributes[AXAttributeNames.kAXRoleAttribute]?.value as? String, role == AXRoleNames.kAXStaticTextRole as String {
                     if let value = targetNode.attributes[AXAttributeNames.kAXValueAttribute]?.value as? String, !value.isEmpty {
                        criteria[AXAttributeNames.kAXValueAttribute] = value
                     } else {
                        criteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName
                     }
                } else {
                    criteria[AXAttributeNames.kAXTitleAttribute] = targetNode.displayName
                }
            }

            let locator = Locator(criteria: criteria, rootElementPathHint: targetNode.fullPathArrayForLocator)

            await GlobalAXLogger.shared.updateOperationDetails(commandID: "performAction_\(actionName)", appName: appIdentifier)

            let response = await axorcist.handlePerformAction(
                for: appIdentifier, 
                locator: locator,
                actionName: actionName
            )

            if Defaults[.verboseLogging_axpector] { 
                let collectedLogs = await axGetLogEntries() 
                for logEntry in collectedLogs { // Iterate and log
                    axDebugLog("AXorcist (PerformAction) Log [L:\(logEntry.level.rawValue) T:\(logEntry.timestamp)]: \(logEntry.message) Details: \(logEntry.details ?? [:])")
                }
                await axClearLogs() 
            }

            if response.error == nil, let responseData = response.data?.value as? PerformResponse, responseData.success {
                self.actionStatusMessage = "Action \"\(actionName)\" performed successfully."
                axInfoLog("Successfully performed action \"\(actionName)\" on node \(targetNode.displayName).")
            } else {
                let errorMessage = response.error ?? "Failed to perform action \"\(actionName)\""
                self.actionStatusMessage = "Failed to perform action \"\(actionName)\": \(errorMessage)"
                axErrorLog("Failed to perform action \"\(actionName)\" on node \(targetNode.displayName). Error: \(errorMessage)")
            }
            
            Task {
                try? await Task.sleep(for: .seconds(3))
                if self.actionStatusMessage?.contains(actionName) == true { 
                    self.actionStatusMessage = nil
                }
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
    internal func fetchAccessibilityTreeForSelectedApp() {
        guard let pid = selectedApplicationPID else {
            axWarningLog("Attempted to fetch tree with no application selected.")
            self.accessibilityTree = []
            self.originalAccessibilityTree = []
            self.filteredAccessibilityTree = []
            self.selectedNode = nil
            self.treeLoadingError = "No application selected."
            return
        }

        guard let app = runningApplications.first(where: { $0.processIdentifier == pid }) else {
            axWarningLog("Application with PID \(pid) not found in observed applications.")
            self.treeLoadingError = "Application with PID \(pid) not found."
            self.accessibilityTree = []
            self.originalAccessibilityTree = []
            self.filteredAccessibilityTree = []
            self.isLoadingTree = false
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "App PID \(pid)"
        axInfoLog("Fetching accessibility tree for: \(appName) (PID: \(pid)) with depth \(self.initialFetchDepth)")
        self.isLoadingTree = true
        self.treeLoadingError = nil
        self.accessibilityTree = [] 
        self.originalAccessibilityTree = []
        self.filteredAccessibilityTree = []

        // Capture appName and pid into local constants
        let currentAppName = appName
        let currentPid = pid
        let commandID = "fetchTree_\(currentAppName.filter { $0.isLetter || $0.isNumber })_\(UUID().uuidString.prefix(6))"

        Task.detached { [weak self, currentAppName, currentPid, commandID] () async -> Void in
            guard let strongSelf = self else {
                axWarningLog("AXpectorViewModel was deallocated before performTreeFetchAndProcess could be run for app: \(currentAppName)")
                return
            }
            await strongSelf.performTreeFetchAndProcess(appName: currentAppName, pid: currentPid, commandID: commandID)
        }
    }
    
    private func performTreeFetchAndProcess(appName: String, pid: Int32, commandID: String) async {
        // Define a nested private function to process the response
        func processResponse(json: String, currentApp: String, currentPid: Int32) -> (nodes: [AXpector.AXPropertyNode]?, error: String?) {
            var localFetchedNodes: [AXpector.AXPropertyNode] = []
            var localOperationError: String? = nil
            let jsonDataUTF8: Data? = json.data(using: .utf8)

            do {
                if let jsonData = jsonDataUTF8 {
                    let localJsonData: Data = jsonData
                    let decoder = JSONDecoder()
                    let collectAllOutput = try decoder.decode(CollectAllOutput.self, from: localJsonData)
                    
                    if collectAllOutput.success {
                        localFetchedNodes = collectAllOutput.collectedElements.map { 
                            self.mapJsonAXElementToNode($0, pid: currentPid, currentDepth: 0, parentPath: "")
                        }
                    } else {
                        let errorDetail = collectAllOutput.errorMessage ?? "Unknown error from AXorcist.handleCollectAll."
                        localOperationError = "Failed to fetch tree for \(currentApp): \(errorDetail)"
                    }
                } else {
                    localOperationError = "Failed to convert JSON string response to Data for \(currentApp). JSON String was nil after UTF-8 conversion."
                }
            } catch {
                localOperationError = "Failed to decode AXorcist.CollectAllOutput JSON for \(currentApp): \(error.localizedDescription). JSON: \(json)"
            }

            return (localFetchedNodes.isEmpty && localOperationError == nil ? [] : localFetchedNodes, localOperationError)
        }

        await GlobalAXLogger.shared.updateOperationDetails(commandID: commandID, appName: appName)

        let jsonStringResponse: String = await MainActor.run {
            self.axorcist.handleCollectAll(
                for: appName, 
                locator: nil, 
                pathHint: nil,
                maxDepth: self.initialFetchDepth, 
                requestedAttributes: AXpectorViewModel.defaultFetchAttributes,
                outputFormat: .jsonString, 
                commandId: commandID
            )
        }
        
        // Call the new local function
        let result = processResponse(json: jsonStringResponse, currentApp: appName, currentPid: pid)
        
        // Update self's properties based on the result
        await MainActor.run {
            self.treeLoadingError = result.error
            if let nodes = result.nodes {
                self.accessibilityTree = nodes
                self.originalAccessibilityTree = nodes
            } else {
                self.accessibilityTree = []
                self.originalAccessibilityTree = []
            }
            self.isLoadingTree = false
            self.applyFilter()
            if let error = result.error {
                axErrorLog("AXpector: Error processing tree for \(appName): \(error)")
            } else {
                axInfoLog("AXpector: Successfully processed tree for \(appName). Nodes: \(result.nodes?.count ?? 0)")
            }
        }
        await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
    }
}

// MARK: - Focus Tracking Implementation -> MOVED TO SEPARATE FILE

// MARK: - Hover Mode Implementation
extension AXpectorViewModel {
    internal func startHoverMonitoring() {
        guard globalEventMonitor == nil else { 
            axInfoLog("Hover monitoring already active.")
            return
        }
        axInfoLog("Starting hover monitoring.")
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.hoverUpdateTask?.cancel()
            self?.hoverUpdateTask = Task {
                // Debounce: Wait for a short period after mouse movement stops
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                self?.updateHoveredElement(at: NSEvent.mouseLocation)
            }
        }
        if globalEventMonitor == nil {
            axErrorLog("Failed to start hover monitoring. Global event monitor is nil.")
            isHoverModeActive = false
        }
    }

    internal func stopHoverMonitoring() {
        hoverUpdateTask?.cancel()
        if let monitor = globalEventMonitor {
            axInfoLog("Stopping hover monitoring.")
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        } else {
            axInfoLog("Hover monitoring was not active.")
        }
    }

    private func updateHoveredElement(at mouseLocation: NSPoint) {
        guard isHoverModeActive else { return }
        guard let pid = selectedApplicationPID else {
            hoveredElementInfo = "No application selected for hover."
            return
        }

        // The hoverUpdateTask is managed by start/stopHoverMonitoring.
        // This function is called by that task after debouncing.
        // Do not cancel or reassign self.hoverUpdateTask here.

        Task { // Create a new Task for the async work within updateHoveredElement
            let commandID = "hover_\(pid)_\(Int(mouseLocation.x))_\(Int(mouseLocation.y))_\(UUID().uuidString.prefix(4))"
            await GlobalAXLogger.shared.updateOperationDetails(commandID: commandID, appName: String(pid)) // Use pid for appName

            // getElementAtPoint returns HandlerResponse, not throwing
            let response = axorcist.getElementAtPoint(
                pid: pid, 
                point: mouseLocation, 
                requestedAttributes: AXpectorViewModel.defaultFetchAttributes // Fetch attributes for display
            )

            if Task.isCancelled { return }

            if let axElement = response.data?.value as? Element { // Use Element
                let underlyingElement = axElement.underlyingElement
                // Get frame and show highlight
                let frame = await self.getFrameForAXElement(underlyingElement)
                if let nsRectFrame = frame {
                    self.highlightWindowController.showHighlight(at: nsRectFrame, color: NSColor.orange.withAlphaComponent(0.4)) // Example color
                } else {
                    self.highlightWindowController.hideHighlight()
                }

                let role = axElement.attributes?[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "N/A"
                let title = axElement.attributes?[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? ""
                let shortTitle = title.isEmpty ? "" : " - \"\(title.prefix(30))\""
                hoveredElementInfo = "Hover: \(role)\(shortTitle)"
                
                // Find the corresponding node in the tree to select it temporarily
                if let nodeInTree = findNodeByAXElement(underlyingElement, in: self.accessibilityTree) {
                    self.temporarilySelectedNodeIDByHover = nodeInTree.id
                } else {
                    self.temporarilySelectedNodeIDByHover = nil // Element not in current tree
                }
            } else if let errorMsg = response.error {
                hoveredElementInfo = "Hover Error: \(errorMsg)"
                highlightWindowController.hideHighlight()
                self.temporarilySelectedNodeIDByHover = nil
            } else {
                hoveredElementInfo = "Hover: No element at point."
                highlightWindowController.hideHighlight()
                self.temporarilySelectedNodeIDByHover = nil
            }
            await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil) // Clear operation details
        }
    }
} 

enum AXpectorError: Error, LocalizedError {
    // ... existing code ...
} 
