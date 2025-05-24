import SwiftUI
import AXorcist // For AXPropertyNode if it's moved or directly used

@MainActor
public struct AXpectorView: View {
    @StateObject private var viewModel = AXpectorViewModel()
    @State private var selectedNodeID: AXPropertyNode.ID?

    public init() {} // Add public initializer

    public var body: some View {
        // Check for Accessibility Permissions first
        if viewModel.isAccessibilityEnabled == false { // Explicitly check for false
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.red)
                Text("Accessibility Permissions Required")
                    .font(.title2)
                Text("AXpector needs Accessibility permissions to inspect other applications. Please enable it for CodeLooper (or your development app) in System Settings.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Open Privacy & Security Settings") {
                    // macOS 13 and later: x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
                    // Older macOS: com.apple.preference.security?Privacy_Accessibility
                    // A more generic approach for modern macOS:
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(.top)
                Button("Re-check Permissions") {
                    viewModel.checkAccessibilityPermissions(promptIfNeeded: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isAccessibilityEnabled == nil { // Still checking or unknown
            VStack {
                ProgressView("Checking Accessibility Permissions...")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                Task { // Wrap in Task
                    viewModel.checkAccessibilityPermissions() // Attempt to check again if view appears in this state
                }
            }
        } else { // Accessibility is enabled, show the main UI
            NavigationView {
                VStack(alignment: .leading, spacing: 0) { // Added spacing: 0 for tighter control
                    // Application Picker
                    Picker("Application:", selection: $viewModel.selectedApplicationPID) {
                        Text("Select Application").tag(nil as pid_t?)
                        ForEach(viewModel.runningApplications, id: \.processIdentifier) { app in
                            Text(app.localizedName ?? "Unknown App").tag(app.processIdentifier as pid_t?)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8) // Add some space below picker
                    .onChange(of: viewModel.selectedApplicationPID) {
                        selectedNodeID = nil 
                        viewModel.selectedNode = nil
                        // viewModel.temporarilySelectedNodeIDByHover is reset by the viewModel itself
                    }

                    // Refresh Button - Placed below the picker
                    if viewModel.selectedApplicationPID != nil {
                        Button(action: { viewModel.fetchAccessibilityTreeForSelectedApp() }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Tree")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .disabled(viewModel.isLoadingTree) // Disable if already loading
                    }

                    // Hover Mode Controls
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { viewModel.toggleHoverMode() }) {
                            Text(viewModel.isHoverModeActive ? "Stop Hover Inspect" : "Start Hover Inspect")
                                .frame(maxWidth: .infinity) // Make button wider
                                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)) // Add some padding inside
                                .background(viewModel.isHoverModeActive ? Color.accentColor : Color.clear)
                                .foregroundColor(viewModel.isHoverModeActive ? .white : .accentColor)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.accentColor, lineWidth: viewModel.isHoverModeActive ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain) // Use plain button style to allow custom background/overlay
                        .padding(.horizontal)
                        
                        Text(viewModel.hoveredElementInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(minHeight: 30, alignment: .topLeading) // Give it some space
                            .lineLimit(3) // Allow a few lines for info
                    }
                    .padding(.bottom, 8)
                    
                    // Focus Tracking Mode Controls
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { viewModel.toggleFocusTrackingMode() }) {
                            Text(viewModel.isFocusTrackingModeActive ? "Stop Focus Tracking" : "Start Focus Tracking")
                                .frame(maxWidth: .infinity)
                                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                                .background(viewModel.isFocusTrackingModeActive ? Color.blue : Color.clear) // Different color for active state
                                .foregroundColor(viewModel.isFocusTrackingModeActive ? .white : .blue)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.blue, lineWidth: viewModel.isFocusTrackingModeActive ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Toggle("Auto-select focused app", isOn: $viewModel.autoSelectFocusedApp)
                            .font(.caption)
                            .padding(.horizontal)
                            // Only show this toggle if focus tracking *could* be active (i.e., an app could be observed)
                            // Or always show it if the mode can be toggled regardless of current app selection.
                            // For simplicity, show if focus tracking mode itself could be toggled by the user.
                            // No, better to show it when focus tracking IS active, or when it *can* be active.
                            // Let's show it within the Focus Tracking VStack.

                        Text(viewModel.focusedElementInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(minHeight: 30, alignment: .topLeading)
                            .lineLimit(3)
                    }
                    .padding(.bottom, 8)
                    
                    // Search/Filter Field
                    HStack { // Use HStack for TextField and potential Clear button
                        TextField("Filter tree (e.g., role:button title:Save)", text: $viewModel.filterText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                        
                        if !viewModel.filterText.isEmpty {
                            Button(action: { viewModel.filterText = "" }) { // Action to clear text
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless) // Make it look like part of the text field
                            .padding(.trailing, 5) // Add some space for the clear button
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    DisclosureGroup("Filter Syntax Help") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Key-Value: key:value (e.g., role:button title:Open)").font(.caption)
                            Text("Supported Keys: role, title, value, desc, path, id").font(.caption)
                            Text("Negation: !key:value or -key:value (e.g., !role:window)").font(.caption)
                            Text("Regex: key:regex:pattern or regex:pattern for general terms").font(.caption)
                            Text("  (e.g., title:regex:^Save.* or regex:^Confirm)").font(.caption)
                            Text("General terms are space-separated words/phrases.").font(.caption)
                            Text("All criteria/terms are ANDed. Use Search Fields toggles for general terms.").font(.caption)
                        }
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes width
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    DisclosureGroup("Search Fields for General Terms") {
                        VStack(alignment: .leading) {
                            Toggle("Display Name", isOn: $viewModel.searchInDisplayName)
                            Toggle("Role", isOn: $viewModel.searchInRole)
                            Toggle("Title", isOn: $viewModel.searchInTitle)
                            Toggle("Value", isOn: $viewModel.searchInValue)
                            Toggle("Description", isOn: $viewModel.searchInDescription)
                            Toggle("Path", isOn: $viewModel.searchInPath)
                        }
                        .padding(.leading) // Indent toggles under disclosure group
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    Divider() // Separator before the tree

                    // Accessibility Tree
                    if viewModel.isLoadingTree {
                        ProgressView("Loading Accessibility Tree...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if let errorMessage = viewModel.treeLoadingError {
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.red)
                            Text("Error Loading Tree")
                                .font(.headline)
                            Text(errorMessage)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if viewModel.accessibilityTree.isEmpty && viewModel.selectedApplicationPID != nil && viewModel.filterText.isEmpty { // Added filterText check
                        // This case is kept for when loading is done, no error, but tree is genuinely empty and no filter applied.
                        Text("Accessibility tree is empty or not available.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if viewModel.filteredAccessibilityTree.isEmpty && !viewModel.filterText.isEmpty && viewModel.selectedApplicationPID != nil { // New case for empty filtered results
                        Text("No elements match your filter: \"\(viewModel.filterText)\"")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if viewModel.selectedApplicationPID == nil {
                         Text("Select an application to inspect.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else {
                        ScrollViewReader { scrollViewProxy in // Wrap List in ScrollViewReader
                            List(selection: $selectedNodeID) {
                                ForEach(viewModel.filteredAccessibilityTree) { rootNode in
                                    RecursiveNodeView(node: rootNode, selectedNodeID: $selectedNodeID, viewModel: viewModel)
                                }
                            }
                            .id("\(viewModel.selectedApplicationPID?.description ?? "nil")-\(viewModel.filterText)") // Change ID based on PID and filterText to help SwiftUI redraw/reset state
                            .listStyle(.sidebar) 
                            .onChange(of: selectedNodeID) { oldValue, newValue in
                                if !viewModel.isHoverModeActive {
                                    // When selecting from filtered tree, find node in original tree to keep selectedNode consistent
                                    if let newID = newValue { // Use newValue
                                        viewModel.selectedNode = viewModel.findNode(by: newID, in: viewModel.filteredAccessibilityTree) // Changed to filtered tree
                                    }
                                } else {
                                    // Deselect if in hover mode and user clicks, to avoid confusion
                                    // Or, allow selection but make hover highlight distinct
                                    // For now, click selection is disabled in hover mode by NodeLabel's onTapGesture
                                }
                            }
                            .onChange(of: viewModel.temporarilySelectedNodeIDByHover) { oldValue, newValue in
                                if let idToScrollTo = newValue { // Use newValue
                                    withAnimation(.easeInOut(duration: 0.3)) { // Optional animation
                                        scrollViewProxy.scrollTo(idToScrollTo, anchor: .center) // Scroll to the center
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 300) 

                // Details View
                if let selectedNode = viewModel.selectedNode, !viewModel.isHoverModeActive {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Details for: \(selectedNode.displayName)")
                                .font(.headline)
                                .padding(.bottom, 5)

                            Group {
                                Text("Role:").font(.caption).foregroundColor(.secondary)
                                Text(selectedNode.role)
                                Text("Title:").font(.caption).foregroundColor(.secondary)
                                Text(selectedNode.title.isEmpty ? "N/A" : selectedNode.title)
                                Text("Description:").font(.caption).foregroundColor(.secondary)
                                Text(selectedNode.descriptionText.isEmpty ? "N/A" : selectedNode.descriptionText)
                                Text("Value:").font(.caption).foregroundColor(.secondary)
                                Text(selectedNode.value.isEmpty ? "N/A" : selectedNode.value)
                                Text("Path:").font(.caption).foregroundColor(.secondary)
                                Text(selectedNode.fullPath)
                                Text("AXElementRef:").font(.caption).foregroundColor(.secondary)
                                Text("\(selectedNode.axElementRef)")
                                Text("PID:").font(.caption).foregroundColor(.secondary)
                                Text("\(selectedNode.pid)")
                            }
                            .padding(.leading)

                            Divider()

                            Text("Attributes (\(selectedNode.attributes.count))")
                                .font(.subheadline)
                            // Display attribute update status message
                            if let status = viewModel.attributeUpdateStatusMessage {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(status.starts(with: "Failed") || status.starts(with: "Error") ? .red : .green)
                                    .padding(.leading)
                                    .padding(.bottom, 2)
                            }

                            if selectedNode.attributes.isEmpty {
                                Text("No attributes available.").foregroundColor(.secondary).padding(.leading)
                            } else {
                                ForEach(selectedNode.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    AttributeRowView(viewModel: viewModel, node: selectedNode, attributeKey: key, attributeValue: value)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 350, maxWidth: .infinity) 
                } else {
                    // Show placeholder if no node is click-selected or if hover mode is ON
                    Text(viewModel.isHoverModeActive ? "Hover mode active. Hover over elements to see info above." : (viewModel.selectedApplicationPID == nil ? "Select an application to begin." : "Select an element to see details. Or enable Hover Inspect mode."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding() // Added padding for better spacing
                }
            }
            .frame(minHeight: 400, idealHeight: 600) 
        }
    }
}

// RecursiveNodeView has been moved to its own file: AXpector/Sources/AXpector/Views/RecursiveNodeView.swift

// NodeLabel has been moved to its own file: AXpector/Sources/AXpector/Views/NodeLabel.swift

// AttributeRowView has been moved to its own file: AXpector/Sources/AXpector/Views/AttributeRowView.swift

#if DEBUG
@MainActor
struct AXpectorView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = AXpectorViewModel()
        // Setup mockViewModel with some data for preview
        // Create a root node
        let rootNode = AXPropertyNode(
            id: UUID(), axElementRef: AXUIElementCreateApplication(0), pid: 0,
            role: "window", title: "Preview Window", descriptionText: "", value: "", fullPath: "App/Preview Window",
            children: [], attributes: [:], actions: [], hasChildrenAXProperty: true, depth: 0
        )
        // Create a child for the root, that itself can have children
        let childNode1 = AXPropertyNode(
            id: UUID(), axElementRef: AXUIElementCreateApplication(0), pid: 0,
            role: "group", title: "Child Group 1", descriptionText: "", value: "", fullPath: "App/Preview Window/Child Group 1",
            children: [], attributes: [:], actions: [], hasChildrenAXProperty: true, depth: 1
        )
        // Create a grandchild, this one has no further children reported by AX
        let grandChildNode1 = AXPropertyNode(
            id: UUID(), axElementRef: AXUIElementCreateApplication(0), pid: 0,
            role: "button", title: "Grandchild Button A", descriptionText: "", value: "", fullPath: "App/Preview Window/Child Group 1/Button A",
            children: [], attributes: [:], actions: ["Press"], hasChildrenAXProperty: false, depth: 2
        )
        childNode1.children = [grandChildNode1]
        childNode1.areChildrenFullyLoaded = true // Simulate they were loaded
        
        // Create another child for the root that is not yet expanded/loaded
        let childNode2 = AXPropertyNode(
            id: UUID(), axElementRef: AXUIElementCreateApplication(0), pid: 0,
            role: "table", title: "Child Table (Not Loaded)", descriptionText: "", value: "", fullPath: "App/Preview Window/Child Table",
            children: [], attributes: [:], actions: [], hasChildrenAXProperty: true, depth: 1
        )
        childNode2.areChildrenFullyLoaded = false // Simulate not loaded

        rootNode.children = [childNode1, childNode2]
        // For root, we assume its direct children (childNode1, childNode2) are loaded up to initialFetchDepth
        // If initialFetchDepth was, say, 1, then rootNode.areChildrenFullyLoaded would be true
        // but childNode1.areChildrenFullyLoaded could be false if its own children weren't fetched.
        rootNode.areChildrenFullyLoaded = true 
        rootNode.isExpanded = true // Start with root expanded in preview

        mockViewModel.accessibilityTree = [rootNode]
        mockViewModel.runningApplications = [NSRunningApplication.current]
        mockViewModel.selectedApplicationPID = NSRunningApplication.current.processIdentifier
        mockViewModel.selectedNode = childNode1 // Select a node for detail view
        mockViewModel.hoveredElementInfo = "Preview: Hover info here...\nRole: button\nTitle: OK" // Example hover info
        mockViewModel.isHoverModeActive = true // Example with hover mode active
        mockViewModel.temporarilySelectedNodeIDByHover = grandChildNode1.id // Example hover selection

        return AXpectorView().environmentObject(mockViewModel) // Inject if AXpectorView uses @EnvironmentObject
                                                            // If using @StateObject, this won't work directly.
                                                            // Preview needs to be adapted if viewModel is @StateObject.
                                                            // For this test, let's assume AXpectorView can take a VM.
    }
}
#endif 