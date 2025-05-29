import AppKit // For pid_t (though Foundation might be enough depending on exact definition)
import AXorcist // For AXUIElement, AnyCodable
import SwiftUI

/// Represents a node in the accessibility tree with properties and child relationships.
///
/// AXPropertyNode encapsulates:
/// - Core accessibility element reference and metadata
/// - Hierarchical relationships (parent/children)
/// - Element properties (role, title, value, attributes)
/// - Available actions and capabilities
/// - UI state for tree visualization and selection
///
/// This class serves as the data model for the accessibility tree view,
/// enabling inspection, editing, and navigation of accessibility hierarchies.
@MainActor // Ensure UI-related properties are accessed on the main actor
class AXPropertyNode: ObservableObject, Identifiable, Hashable {
    // MARK: Lifecycle

    init(
        id: UUID,
        axElementRef: AXUIElement,
        pid: pid_t,
        role: String,
        title: String,
        descriptionText: String,
        value: String,
        fullPath: String,
        children: [AXPropertyNode],
        attributes: [String: AnyCodable],
        actions: [String],
        hasChildrenAXProperty: Bool,
        depth: Int
    ) {
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

    // MARK: Internal

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

    var displayName: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedTitle.isEmpty, trimmedTitle != "Untitled" { return trimmedTitle }
        if !trimmedDescription.isEmpty { return trimmedDescription }
        if !trimmedValue.isEmpty {
            let maxLength = 50
            return trimmedValue.count > maxLength ? String(trimmedValue.prefix(maxLength)) + "..." : trimmedValue
        }
        if !role.isEmpty, role != "N/A" { return role }
        return "Element (ID: \(id.uuidString.prefix(8)))"
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

    // Equatable based on ID
    nonisolated static func == (lhs: AXPropertyNode, rhs: AXPropertyNode) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable based on ID
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Struct to hold display-specific information for an attribute
public struct AttributeDisplayInfo {
    // MARK: Lifecycle

    public init(
        displayString: String,
        // valueType: AXValueType? = nil, // REMOVED
        isSettable: Bool,
        settableDisplayString: String,
        navigatableElementRef: AXUIElement? = nil
    ) {
        self.displayString = displayString
        // self.valueType = valueType // REMOVED
        self.isSettable = isSettable
        self.settableDisplayString = settableDisplayString
        self.navigatableElementRef = navigatableElementRef
    }

    // MARK: Public

    public let displayString: String
    // public let valueType: AXValueType? // REMOVED as getValueType was removed
    public let isSettable: Bool
    public let settableDisplayString: String
    public let navigatableElementRef: AXUIElement? // If this attribute represents a navigable element
}
