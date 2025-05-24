import SwiftUI
import AXorcist // For AXUIElement, AnyCodable
import AppKit      // For pid_t (though Foundation might be enough depending on exact definition)

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
    @Published var attributes: [String: AnyCodable]
    @Published var actions: [String]
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
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !t.isEmpty && t != "Untitled" { return t }
        if !d.isEmpty { return d }
        if !v.isEmpty { 
            let maxLength = 50
            return v.count > maxLength ? String(v.prefix(maxLength)) + "..." : v
        }
        if !role.isEmpty && role != "N/A" { return role }
        return "Element (ID: \(id.uuidString.prefix(8)))"
    }

    // Equatable based on ID
    static nonisolated func == (lhs: AXPropertyNode, rhs: AXPropertyNode) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable based on ID
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Computed property to get fullPath as an array of strings for Locator
    var fullPathArrayForLocator: [String]? {
        let components = fullPath.split(separator: "/").map(String.init)
        // Return nil if the path is empty or just a single slash (or invalid), 
        // as a path hint should ideally have more substance.
        // AXorcist's path hint logic might also be fine with single-element arrays.
        // For now, return nil for empty to signify no meaningful hint.
        return components.isEmpty ? nil : components
    }
} 