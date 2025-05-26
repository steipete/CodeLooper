import SwiftUI
import AXorcist
import DesignSystem

@MainActor
public struct AXpectorView: View {
    @StateObject private var viewModel = AXpectorViewModel()
    @State private var selectedNodeID: AXPropertyNode.ID?

    public init() {}

    public var body: some View {
        // Check for Accessibility Permissions first
        if viewModel.isAccessibilityEnabled == nil {
            LoadingView(message: "Checking Accessibility Permissions...")
        } else if viewModel.isAccessibilityEnabled == false {
            PermissionRequiredView()
        } else {
            MainContentView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
        }
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

// MARK: - Permission Required View
private struct PermissionRequiredView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "lock.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(ColorPalette.error)
            
            Text("Accessibility Permissions Required")
                .font(Typography.title3(.semibold))
                .foregroundColor(ColorPalette.text)
            
            Text("AXpector needs Accessibility permissions to inspect other applications. Please enable it for CodeLooper in System Settings.")
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            DSButton("Open Privacy & Security Settings", style: .primary) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
                // Also request access to trigger the system prompt
                AXPermissions.requestAccess()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $viewModel.currentMode) {
                ForEach(AXpectorMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .top])
            .background(ColorPalette.background)

            switch viewModel.currentMode {
            case .inspector:
                NavigationView {
                    // Tree View
                    TreeSidebarView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
                        .frame(minWidth: 350)
                    
                    // Details View
                    if let selectedNode = viewModel.selectedNode, !viewModel.isHoverModeActive {
                        NodeDetailsView(viewModel: viewModel, node: selectedNode)
                            .frame(minWidth: 400, maxWidth: .infinity)
                    } else {
                        EmptyStateView(
                            isHoverMode: viewModel.isHoverModeActive,
                            hasSelectedApp: viewModel.selectedApplicationPID != nil
                        )
                    }
                }
            case .observer:
                ObserverView(viewModel: viewModel)
            }
        }
        .frame(minHeight: 600, idealHeight: 800)
        .background(ColorPalette.background)
    }
}

// Placeholder for ObserverView
private struct ObserverView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @State private var observerSelectedNodeID: AXPropertyNode.ID? 

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Header Controls for Observer Mode
                VStack(spacing: Spacing.medium) {
                    ApplicationPickerView(viewModel: viewModel)
                    
                    if viewModel.selectedApplicationPID != nil {
                        DSButton("Refresh Tree", style: .secondary, size: .small) {
                            viewModel.fetchAccessibilityTreeForSelectedApp() // Re-use existing fetch
                        }
                        .disabled(viewModel.isLoadingTree)
                        .frame(maxWidth: .infinity)
                    }
                    // Filter field for observer mode
                    DSTextField(
                        "Filter tree...",
                        text: $viewModel.filterText, // Re-use existing filterText
                        showClearButton: true
                    )
                }
                .padding(Spacing.medium)
                .background(ColorPalette.backgroundSecondary)
                
                DSDivider()
                
                // Tree Content for Observer Mode
                Group { // Group to handle conditional logic for tree display
                    if viewModel.isLoadingTree {
                        LoadingView(message: "Loading Accessibility Tree...")
                    } else if let error = viewModel.treeLoadingError {
                        ErrorView(message: "Failed to load tree: \(error)")
                    } else if viewModel.selectedApplicationPID == nil {
                        EmptyStateView(message: "Select an application to view its accessibility tree.")
                    } else if viewModel.filteredAccessibilityTree.isEmpty && !viewModel.filterText.isEmpty { // Use filteredAccessibilityTree
                         EmptyStateView(message: "No elements match your filter: \"\(viewModel.filterText)\"")
                    } else if viewModel.accessibilityTree.isEmpty { // Check original tree if no filter
                         EmptyStateView(message: "No accessibility elements found for the selected application, or the tree is empty.")
                    } else {
                        // Pass the observer-specific selectedNodeID binding
                        TreeContentView(viewModel: viewModel, selectedNodeID: $observerSelectedNodeID) 
                    }
                }
                .frame(minWidth: 300) // Ensure tree has some minimum width
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorPalette.background)

            // Observer Node Details View
            if let selectedID = observerSelectedNodeID,
               let node = viewModel.findNode(by: selectedID, in: viewModel.filteredAccessibilityTree.isEmpty && viewModel.filterText.isEmpty ? viewModel.accessibilityTree : viewModel.filteredAccessibilityTree) {
                ObserverNodeDetailsView(node: node)
                    .frame(minWidth: 300) // Ensure details view has some minimum width
            } else {
                EmptyStateView(message: "Select an element from the tree to see its details.")
                    .frame(minWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Removed redundant background from HSplitView children, HSplitView itself has no background property
    }
}

// Helper for Error View (can be made more generic later)
private struct ErrorView: View {
    let message: String
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.error)
            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

// Extended EmptyStateView for Observer Mode
private struct EmptyStateView: View {
    var message: String? = nil // Optional message for observer mode
    var isHoverMode: Bool = false
    var hasSelectedApp: Bool = false

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "sidebar.squares.left") // Generic icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(ColorPalette.textTertiary)

            if let message = message {
                Text(message)
                    .font(Typography.title3(.regular))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Original EmptyStateView logic
                if isHoverMode {
                    Text("Hover Inspecting Active")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Tree selection and details are disabled during hover inspect.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                } else if !hasSelectedApp {
                    Text("No Application Selected")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Select an application from the picker above to view its accessibility tree.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                } else {
                    Text("No Element Selected")
                        .font(Typography.title3(.regular))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("Select an element from the tree on the left to see its details.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(ColorPalette.background)
    }
}

// MARK: - Application Picker View
private struct ApplicationPickerView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    
    var body: some View {
        HStack {
            Text("Application")
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)
            
            Spacer()
            
            Menu {
                Button("Select Application") {
                    viewModel.selectedApplicationPID = nil
                }
                .disabled(viewModel.selectedApplicationPID == nil)
                
                Divider()
                
                ForEach(viewModel.runningApplications, id: \.processIdentifier) { app in
                    Button(action: {
                        viewModel.selectedApplicationPID = app.processIdentifier
                    }) {
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(app.localizedName ?? "Unknown App")
                            if app.processIdentifier == viewModel.selectedApplicationPID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xSmall) {
                    if let selectedApp = viewModel.runningApplications.first(where: { $0.processIdentifier == viewModel.selectedApplicationPID }),
                       let icon = selectedApp.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(selectedAppName)
                        .font(Typography.body())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xSmall)
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
    }
    
    private var selectedAppName: String {
        if let pid = viewModel.selectedApplicationPID,
           let app = viewModel.runningApplications.first(where: { $0.processIdentifier == pid }) {
            return app.localizedName ?? "Unknown App"
        }
        return "Select Application"
    }
}

// MARK: - Tree Sidebar View
private struct TreeSidebarView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            VStack(spacing: Spacing.medium) {
                // Application Picker
                ApplicationPickerView(viewModel: viewModel)
                
                // Refresh Button
                if viewModel.selectedApplicationPID != nil {
                    DSButton("Refresh Tree", style: .secondary, size: .small) {
                        viewModel.fetchAccessibilityTreeForSelectedApp()
                    }
                    .disabled(viewModel.isLoadingTree)
                    .frame(maxWidth: .infinity)
                }
                
                // Mode Controls
                ModeControlsView(viewModel: viewModel)
                
                // Search Field
                DSTextField(
                    "Filter tree (e.g., role:button title:Save)",
                    text: $viewModel.filterText,
                    showClearButton: true
                )
                
                // Filter Help
                DisclosureGroup("Filter Syntax Help") {
                    FilterHelpView()
                }
                .font(Typography.caption1())
                
                // Search Fields
                DisclosureGroup("Search Fields") {
                    SearchFieldsView(viewModel: viewModel)
                }
                .font(Typography.caption1())
            }
            .padding(Spacing.medium)
            .background(ColorPalette.backgroundSecondary)
            
            DSDivider()
            
            // Tree Content
            TreeContentView(viewModel: viewModel, selectedNodeID: $selectedNodeID)
        }
        .background(ColorPalette.background)
    }
}

// MARK: - Mode Controls View
private struct ModeControlsView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    
    var body: some View {
        VStack(spacing: Spacing.small) {
            // Hover Mode
            DSButton(
                viewModel.isHoverModeActive ? "Stop Hover Inspect" : "Start Hover Inspect",
                style: viewModel.isHoverModeActive ? .primary : .secondary,
                size: .small
            ) {
                viewModel.toggleHoverMode()
            }
            .frame(maxWidth: .infinity)
            
            if !viewModel.hoveredElementInfo.isEmpty {
                Text(viewModel.hoveredElementInfo)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            
            // Focus Tracking
            DSButton(
                viewModel.isFocusTrackingModeActive ? "Stop Focus Tracking" : "Start Focus Tracking",
                style: viewModel.isFocusTrackingModeActive ? .primary : .secondary,
                size: .small
            ) {
                viewModel.toggleFocusTrackingMode()
            }
            .frame(maxWidth: .infinity)
            
            DSToggle(
                "Auto-select focused app",
                isOn: $viewModel.autoSelectFocusedApp
            )
            
            if !viewModel.focusedElementInfo.isEmpty {
                Text(viewModel.focusedElementInfo)
                    .font(Typography.caption2())
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            
            // Display detailed focused element attributes
            if viewModel.isFocusTrackingModeActive, let attributesDesc = viewModel.focusedElementAttributesDescription {
                ScrollView {
                    Text(attributesDesc)
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.text)
                        .padding(Spacing.xSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorPalette.backgroundSecondary.opacity(0.5))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 150) // Limit height to prevent oversized view
                .padding(.top, Spacing.xSmall)
            }
        }
    }
}

// MARK: - Filter Help View
private struct FilterHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("• Key-Value: key:value (e.g., role:button)")
                .font(Typography.caption2())
            Text("• Keys: role, title, value, desc, path, id")
                .font(Typography.caption2())
            Text("• Negation: !key:value or -key:value")
                .font(Typography.caption2())
            Text("• Regex: key:regex:pattern")
                .font(Typography.caption2())
            Text("• All criteria are ANDed")
                .font(Typography.caption2())
        }
        .foregroundColor(ColorPalette.textSecondary)
        .padding(.leading, Spacing.small)
    }
}

// MARK: - Search Fields View
private struct SearchFieldsView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            DSToggle("Display Name", isOn: $viewModel.searchInDisplayName)
            DSToggle("Role", isOn: $viewModel.searchInRole)
            DSToggle("Title", isOn: $viewModel.searchInTitle)
            DSToggle("Value", isOn: $viewModel.searchInValue)
            DSToggle("Description", isOn: $viewModel.searchInDescription)
            DSToggle("Path", isOn: $viewModel.searchInPath)
        }
        .padding(.leading, Spacing.small)
    }
}

// MARK: - Tree Content View
private struct TreeContentView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    @Binding var selectedNodeID: AXPropertyNode.ID?
    
    var body: some View {
        Group {
            if viewModel.isLoadingTree {
                LoadingView(message: "Loading Accessibility Tree...")
            } else if let errorMessage = viewModel.treeLoadingError {
                ErrorStateView(message: errorMessage)
            } else if viewModel.filteredAccessibilityTree.isEmpty {
                EmptyTreeView(
                    hasFilter: !viewModel.filterText.isEmpty,
                    filterText: viewModel.filterText,
                    hasSelectedApp: viewModel.selectedApplicationPID != nil
                )
            } else {
                ScrollViewReader { scrollViewProxy in
                    List(selection: $selectedNodeID) {
                        ForEach(viewModel.filteredAccessibilityTree) { rootNode in
                            RecursiveNodeView(
                                node: rootNode,
                                selectedNodeID: $selectedNodeID,
                                viewModel: viewModel
                            )
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: selectedNodeID) { oldValue, newValue in
                        if viewModel.currentMode == .inspector, !viewModel.isHoverModeActive, let newID = newValue {
                            viewModel.selectedNode = viewModel.findNode(by: newID, in: viewModel.filteredAccessibilityTree)
                        }
                    }
                    .onChange(of: viewModel.temporarilySelectedNodeIDByHover) { oldValue, newValue in
                        if let idToScrollTo = newValue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollViewProxy.scrollTo(idToScrollTo, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View
private struct ErrorStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.error)
            
            Text("Error Loading Tree")
                .font(Typography.headline())
                .foregroundColor(ColorPalette.text)
            
            Text(message)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Empty Tree View
private struct EmptyTreeView: View {
    let hasFilter: Bool
    let filterText: String
    let hasSelectedApp: Bool
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: hasFilter ? "magnifyingglass" : "tree")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(ColorPalette.textTertiary)
            
            Text(emptyMessage)
                .font(Typography.body())
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyMessage: String {
        if hasFilter {
            return "No elements match your filter: \"\(filterText)\""
        } else if !hasSelectedApp {
            return "Select an application to inspect"
        } else {
            return "Accessibility tree is empty or not available"
        }
    }
}

// MARK: - Node Details View
private struct NodeDetailsView: View {
    @ObservedObject var viewModel: AXpectorViewModel
    let node: AXPropertyNode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Details")
                        .font(Typography.title3(.semibold))
                        .foregroundColor(ColorPalette.text)
                    
                    Text(node.displayName)
                        .font(Typography.headline())
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                DSDivider()
                
                // Properties
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    PropertyRow(label: "Role", value: node.role)
                    PropertyRow(label: "Title", value: node.title.isEmpty ? "N/A" : node.title)
                    PropertyRow(label: "Description", value: node.descriptionText.isEmpty ? "N/A" : node.descriptionText)
                    PropertyRow(label: "Value", value: node.value.isEmpty ? "N/A" : node.value)
                    PropertyRow(label: "Path", value: node.fullPath)
                    PropertyRow(label: "AXElementRef", value: "\(node.axElementRef)")
                    PropertyRow(label: "PID", value: "\(node.pid)")
                }
                
                DSDivider()
                
                // Attributes
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("Attributes")
                            .font(Typography.headline())
                            .foregroundColor(ColorPalette.text)
                        
                        Text("(\(node.attributes.count))")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    if let status = viewModel.attributeUpdateStatusMessage {
                        DSBadge(
                            text: status,
                            style: status.contains("Failed") || status.contains("Error") ? .error : .success
                        )
                    }
                    
                    if node.attributes.isEmpty {
                        Text("No attributes available.")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            ForEach(node.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                AttributeRowView(
                                    viewModel: viewModel,
                                    node: node,
                                    attributeKey: key,
                                    attributeValue: value
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.large)
        }
        .background(ColorPalette.background)
    }
}

// MARK: - Property Row
private struct PropertyRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
            Text(label)
                .font(Typography.caption1(.medium))
                .foregroundColor(ColorPalette.textSecondary)
            
            Text(value)
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Observer Node Details View (Read-Only)
private struct ObserverNodeDetailsView: View {
    let node: AXPropertyNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text("Selected Element (Observer)")
                    .font(Typography.headline())
                    .foregroundColor(ColorPalette.text)
                
                PropertyRow(label: "Display Name", value: node.displayName)
                PropertyRow(label: "Role", value: node.role)
                PropertyRow(label: "Title", value: node.title.isEmpty ? "N/A" : node.title)
                PropertyRow(label: "Value", value: node.value.isEmpty ? "N/A" : node.value)
                PropertyRow(label: "Description", value: node.descriptionText.isEmpty ? "N/A" : node.descriptionText)
                PropertyRow(label: "Path", value: node.fullPath)
                
                if !node.attributes.isEmpty {
                    DSDivider()
                    Text("All Attributes (\(node.attributes.count)")
                        .font(Typography.subheadline(.semibold))
                        .foregroundColor(ColorPalette.text)
                        .padding(.top, Spacing.small)
                    
                    ForEach(node.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, attrInfo in
                        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                            Text(key)
                                .font(Typography.caption1(.semibold))
                                .foregroundColor(ColorPalette.textSecondary)
                            Text(String(describing: attrInfo.value))
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.text)
                                .textSelection(.enabled)
                        }
                        .padding(.bottom, Spacing.xxSmall)
                    }
                }
            }
            .padding(Spacing.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.backgroundSecondary) // Differentiate from main tree background
        .border(ColorPalette.border, width: 1)
    }
}

// MARK: - Preview
#if DEBUG
struct AXpectorView_Previews: PreviewProvider {
    static var previews: some View {
        AXpectorView()
            .frame(width: 900, height: 700)
            .withDesignSystem()
    }
}
#endif