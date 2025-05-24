import SwiftUI
import Combine
import AppKit // For NSRunningApplication, AXUIElement, AXObserver, pid_t. Some might be movable to extensions.
import AXorcist
// AXorcist import already includes logging utilities
import Defaults // ADD for Defaults[.verboseLogging]

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
                if _isHoverModeActive {
                    stopHoverMonitoring() 
                    _isHoverModeActive = false
                    isHoverModeActive = false 
                }
                
                if _isFocusTrackingModeActive {
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
            _isHoverModeActive = isHoverModeActive 
            if isHoverModeActive {
                if _isFocusTrackingModeActive { 
                    stopFocusTrackingMonitoring()
                    focusedElementInfo = "Enable focus tracking mode."
                    temporarilySelectedNodeIDByFocus = nil
                    _isFocusTrackingModeActive = false 
                    isFocusTrackingModeActive = false 
                }
                startHoverMonitoring()
                hoveredElementInfo = "Hover over an element...\nTree selection disabled."
                temporarilySelectedNodeIDByHover = nil 
            } else {
                stopHoverMonitoring()
                hoveredElementInfo = "Enable hover mode to inspect elements with mouse."
                temporarilySelectedNodeIDByHover = nil 
                if !_isFocusTrackingModeActive { 
                    highlightWindowController.hideHighlight() 
                }
            }
        }
    }
    @Published var hoveredElementInfo: String = "Enable hover mode to inspect elements with mouse."
    @Published var temporarilySelectedNodeIDByHover: AXPropertyNode.ID?
    internal var globalEventMonitor: Any? 
    internal var hoverUpdateTask: Task<Void, Never>? 
    private var _isHoverModeActive: Bool = false

    // Focus Tracking Mode
    @Published var isFocusTrackingModeActive: Bool = false {
        didSet {
            _isFocusTrackingModeActive = isFocusTrackingModeActive 
            if isFocusTrackingModeActive {
                if _isHoverModeActive { 
                    stopHoverMonitoring()
                    hoveredElementInfo = "Enable hover mode to inspect elements with mouse."
                    temporarilySelectedNodeIDByHover = nil
                    _isHoverModeActive = false 
                    isHoverModeActive = false 
                }
                startFocusTrackingMonitoring()
                focusedElementInfo = "Tracking focused element..."
                temporarilySelectedNodeIDByFocus = nil 
            } else {
                stopFocusTrackingMonitoring()
                focusedElementInfo = "Enable focus tracking mode."
                temporarilySelectedNodeIDByFocus = nil 
                if !_isHoverModeActive { 
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
    private var _isFocusTrackingModeActive: Bool = false
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
        checkAccessibilityPermissions() 
        fetchRunningApplications()
        setupFilterDebouncer() 
        // Subscribe to GlobalAXLogger if needed for real-time log display in UI
        // GlobalAXLogger.shared.addSubscriber(self) // Example if ViewModel conforms to AXLogSubscriber
    }

    deinit {
        stopHoverMonitoring() 
        stopFocusTrackingMonitoring() 
        // GlobalAXLogger.shared.removeSubscriber(self) // Example
    }

    // MARK: - Main Actions / Toggles
    func toggleHoverMode() {
        _isHoverModeActive.toggle()
        isHoverModeActive = _isHoverModeActive
    }

    func toggleFocusTrackingMode() {
        _isFocusTrackingModeActive.toggle()
        isFocusTrackingModeActive = _isFocusTrackingModeActive
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

            let locator = Locator(criteria: criteria, root_element_path_hint: targetNode.fullPathArrayForLocator) 

            await GlobalAXLogger.shared.updateOperationDetails(commandID: "performAction_\(actionName)", appName: appIdentifier)

            let response = await axorcist.handlePerformAction(
                for: appIdentifier, 
                locator: locator,
                actionName: actionName
            )

            if Defaults[.verboseLogging] {
                let collectedLogs = await GlobalAXLogger.shared.getLogs()
                let logMessages = GlobalAXLogger.formatEntriesAsText(collectedLogs, includeTimestamps: true, includeLevels: true, includeDetails: true)
                for logMessage in logMessages {
                    axDebugLog("AXorcist (PerformAction) Log: \(logMessage)")
                }
                await GlobalAXLogger.shared.clearLogs()
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
        guard let pid = selectedApplicationPID, 
              let app = runningApplications.first(where: { $0.processIdentifier == pid }) else {
            axInfoLog("No application selected or PID not found, clearing tree.")
            self.accessibilityTree = []
            self.selectedNode = nil
            self.isLoadingTree = false
            self.treeLoadingError = nil
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "App PID \(pid)"
        axInfoLog("Fetching accessibility tree for: \(appName) (PID: \(pid)) with depth \(initialFetchDepth)")
        self.isLoadingTree = true
        self.treeLoadingError = nil
        self.accessibilityTree = [] // Clear previous tree
        self.selectedNode = nil

        Task {
            let commandID = "fetchTree_\(appName.filter { $0.isLetterOrDigit })_\(UUID().uuidString.prefix(6))"
            await GlobalAXLogger.shared.updateOperationDetails(commandID: commandID, appName: appName)

            // Returns a JSON String of CollectAllOutput
            let jsonStringResponse = await axorcist.handleCollectAll(
                for: appName, // Or pid directly if AXorcist prefers
                locator: nil, // No specific locator for initial full tree
                pathHint: nil,
                maxDepth: initialFetchDepth,
                requestedAttributes: AXpectorViewModel.defaultFetchAttributes,
                outputFormat: .json, // Explicitly request JSON to match CollectAllOutput
                commandId: commandID
            )
            
            var fetchedNodes: [AXPropertyNode] = []
            var operationError: String? = nil

            do {
                if let jsonData = jsonStringResponse.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let collectAllOutput = try decoder.decode(CollectAllOutput.self, from: jsonData)
                    
                    if collectAllOutput.success {
                        if let elements = collectAllOutput.collected_elements { // These are AXorcistLib.AXElement
                            // mapAXElementToNode is in AXpectorViewModel+NodeOperations.swift
                            // It expects AXorcistLib.AXElement, pid, currentDepth, parentPath
                            fetchedNodes = elements.map { mapAXElementToNode($0, pid: pid, currentDepth: 0, parentPath: "") }
                            axInfoLog("Successfully fetched and mapped \(fetchedNodes.count) root elements for \(appName).")
                        } else {
                            axWarningLog("CollectAll reported success but no elements found for \(appName).")
                            fetchedNodes = []
                        }
                        self.treeLoadingError = nil
                    } else {
                        let errorDetail = collectAllOutput.error_message ?? "Unknown error from AXorcist.handleCollectAll."
                        operationError = "Failed to fetch tree for \(appName): \(errorDetail)"
                        axErrorLog(operationError!)
                    }
                } else {
                    operationError = "Failed to convert JSON string response to Data for \(appName)."
                    axErrorLog(operationError!)
                }
            } catch {
                operationError = "Failed to decode CollectAllOutput JSON for \(appName): \(error.localizedDescription). JSON: \(jsonStringResponse)"
                axErrorLog(operationError!)
            }

            if Defaults[.verboseLogging] {
                let collectedLogs = await GlobalAXLogger.shared.getLogs()
                let logMessages = GlobalAXLogger.formatEntriesAsText(collectedLogs, includeTimestamps: true, includeLevels: true, includeDetails: true)
                if !logMessages.isEmpty { axDebugLog("--- AXorcist (FetchTree \(appName)) Logs ---") }
                for logMessage in logMessages {
                    axDebugLog(logMessage)
                }
                await GlobalAXLogger.shared.clearLogs()
            }
            
            self.accessibilityTree = fetchedNodes
            self.isLoadingTree = false
            self.treeLoadingError = operationError
            
            // Update filter after new tree is loaded
            applyFilter() 
            
            await GlobalAXLogger.shared.updateOperationDetails(commandID: nil, appName: nil)
        }
    }
}

// Extensions for different logical units are now in separate files in ViewModelExtensions/
// The AXPropertyNode class is now in Models/AXPropertyNode.swift

// Represents a node in the visual accessibility tree
@MainActor // Ensure UI-related properties are accessed on the main actor
class AXPropertyNode: ObservableObject, Identifiable, Hashable {
    let id: UUID
    let axElementRef: AXUIElement 
    let pid: pid_t
    
    // Properties that might change and should update the UI
    @Published var role: String
    @Published var title: String
    @Published var descriptionText: String
    @Published var value: String
    @Published var fullPath: String
    @Published var children: [AXPropertyNode]
    @Published var isExpanded: Bool = false
    @Published var isLoadingChildren: Bool = false
    
    // Properties that are generally static after creation for this instance
    let attributes: [String: AnyCodable]
    let actions: [String]
    let hasChildrenAXProperty: Bool // Renamed to be clear it's from AX, not derived from children.count
    let depth: Int
    var areChildrenFullyLoaded: Bool = false // Can be updated after a dynamic load

    init(id: UUID, axElementRef: AXUIElement, pid: pid_t, 
         role: String, title: String, descriptionText: String, value: String, fullPath: String, 
         children: [AXPropertyNode], attributes: [String: AnyCodable], actions: [String], 
         hasChildrenAXProperty: Bool, depth: Int) {
        self.id = id
        self.axElementRef = axElementRef
        self.pid = pid
        self.role = role
        self.title = title
        self.descriptionText = descriptionText
        self.value = value
        self.fullPath = fullPath
        self.children = children
        self.attributes = attributes
        self.actions = actions
        self.hasChildrenAXProperty = hasChildrenAXProperty
        self.depth = depth
    }

    var displayName: String {
        let t = title.isEmpty ? "" : "\"\(title.prefix(30))\""
        let r = role.isEmpty ? "Element" : role
        return "\(r) \(t)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Equatable based on ID
    static func == (lhs: AXPropertyNode, rhs: AXPropertyNode) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable based on ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Initializer with more detailed properties
    init(id: UUID, axElementRef: AXUIElement, pid: pid_t, 
         role: String, title: String, descriptionText: String, value: String,
         fullPath: String, children: [AXPropertyNode], 
         attributes: [String: AnyCodable], actions: [String],
         hasChildrenAXProperty: Bool, depth: Int) {
        self.id = id
        self.axElementRef = axElementRef
        self.pid = pid
        self.role = role
        self.title = title
        self.descriptionText = descriptionText
        self.value = value
        self.fullPath = fullPath
        self.children = children
        self.attributes = attributes
        self.actions = actions
        self.hasChildrenAXProperty = hasChildrenAXProperty
        self.depth = depth
        
        // Attempt to get appName more reliably here if possible
        if let app = NSRunningApplication(processIdentifier: pid) {
            self.appName = app.localizedName ?? app.bundleIdentifier ?? "App PID \(pid)"
        }
    }
    
    // Simplified static func to create a node from an AXUIElement for previews etc.
    // This is used when a full AXorcistLib.AXElement isn't available or needed.
    static func lightNode(from axElementRef: AXUIElement, pid: pid_t) -> AXPropertyNode {
        let axLibElement = AXorcist.Element(axElementRef) // Use AXorcist.Element or AXorcistLib.Element
        //var tempDebugLogs: [String] = [] // Removed

        let role = axLibElement.role() // No logging params
        let title = axLibElement.title() // No logging params
        let value = axLibElement.value() as? String // No logging params
        let help = axLibElement.help() // No logging params
        let desc = axLibElement.descriptionText() // No logging params (method name changed from .description)
        let identifier = axLibElement.identifier() // No logging params
        
        // Path generation requires the application element, which might not be easily available here.
        // For a light node, we might skip the full path or use a simplified one.
        // let appElementRef = AXUIElementCreateApplication(pid)
        // let appElementForPath = AXorcist.Element(appElementRef)
        // let pathArray = axLibElement.generatePathArray(upTo: appElementForPath) // No logging params
        // let pathString = pathArray.map { $0.identifier }.joined(separator: "/")
        let pathString = "Calculating..."

        return AXPropertyNode(
            id: UUID(), axElementRef: axElementRef, pid: pid,
            role: role ?? "N/A", title: title ?? "", descriptionText: desc ?? "", value: value ?? "",
            fullPath: pathString, children: [], attributes: [:], actions: [], 
            hasChildrenAXProperty: axLibElement.attribute(.children) != nil, // Basic check
            depth: 0
        )
    }
}

// Extension to make AXElement usable in the view model directly if needed,
// or ensure it's Sendable if passed across actor boundaries.
// AXorcist.AXElement should already be equatable and hashable if it has an ID.
// For now, AXPropertyNode wraps it. 

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
            _isHoverModeActive = false 
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
        guard _isHoverModeActive else { return }
        guard let pid = selectedApplicationPID else {
            hoveredElementInfo = "No application selected for hover."
            return
        }

        // AXorcist's getElementAtPoint now returns a HandlerResponse
        // and uses GlobalAXLogger internally.
        let response = axorcist.getElementAtPoint(
            pid: pid,
            point: mouseLocation,
            isScreenCoordinatesTopLeft: false // AXpector uses AppKit coordinates
        )

        if let error = response.error {
            hoveredElementInfo = "Error: \(error)"
            temporarilySelectedNodeIDByHover = nil
            highlightWindowController.hideHighlight()
            return
        }

        guard let axElementData = response.data?.value as? AXElement else {
            hoveredElementInfo = "No element at cursor (or unexpected data type)."
            temporarilySelectedNodeIDByHover = nil
            highlightWindowController.hideHighlight()
            return
        }
        
        // We need the actual AXUIElement ref from the AXElement data if possible,
        // or a way to find our AXPropertyNode based on the AXElement data (e.g., path or attributes).
        // For now, let's assume AXElement contains enough info to describe, or we need to adjust.
        // The AXElement ref from AXorcist is transient. We need to map it to our tree.

        // To map to our tree, we'd need to search based on path or unique attributes.
        // This is a simplified placeholder. Ideally, we'd search our `accessibilityTree`.
        // For now, just display info from the direct hit. This won't select in the tree.
        let role = axElementData.attributes?[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "Unknown"
        let title = axElementData.attributes?[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? ""
        hoveredElementInfo = "Hover: \(role) - \(title)\nPath: \(axElementData.path?.joined(separator: "/") ?? "N/A")"
        
        // To actually select in the tree and highlight based on the *found tree node*:
        // 1. Get the AXUIElement from the hit test (AXorcist returns AXElement which has the underlying ref).
        // 2. Search `accessibilityTree` for an AXPropertyNode whose `axElementRef` matches.
        //    This requires AXElement from AXorcist to expose its underlyingElement.
        //    Let's assume AXElement.underlyingElement is available for this conceptual step.

        // --- Conceptual search for the node in our tree ---
        // if let hitAXUIElement = axElementData.underlyingElement { // Assuming this exists
        //     if let nodeInTree = findNodeByAXElement(hitAXUIElement, in: accessibilityTree) {
        //         temporarilySelectedNodeIDByHover = nodeInTree.id
        //         updateHighlightForNode(nodeInTree, isHover: true, isFocusHighlight: false)
        //         return // Found and highlighted
        //     }
        // }
        // --- End conceptual search ---

        // If not found in tree (or above conceptual search is not implemented),
        // try to highlight based on raw AXUIElement (less accurate if tree is out of sync)
        // For this, we need the actual AXUIElement. The current `AXElement` model doesn't seem to hold it directly.
        // The original `getElementAtPoint` in AXorcist *did* return an AXUIElement.
        // The new `getElementAtPoint` in `AXorcist+UtilityHandlers` returns a `HandlerResponse` with `AXElement` data.
        // `AXElement` struct in `CommandModels.swift` has `underlyingElement: AXUIElement`.

        if let underlyingElementFromResponse = axElementData.underlyingElement { // This is the key!
             highlightWindowController.highlightElement(underlyingElementFromResponse)
        } else {
            hoveredElementInfo = "Hover: Element found but could not get its reference for highlight."
            temporarilySelectedNodeIDByHover = nil
            highlightWindowController.hideHighlight()
        }
    }
} 