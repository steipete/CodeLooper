import AXorcist // For AXPropertyNode if it's moved or directly used
import SwiftUI

// AXorcist import already includes logging utilities

/// Row view for displaying an accessibility attribute name-value pair.
///
/// AttributeRowView provides formatted display of:
/// - Attribute names with consistent styling
/// - Type-aware value formatting and presentation
/// - Special handling for complex attribute types
/// - Copy-to-clipboard functionality for debugging
///
/// Used within the node details view to present all accessibility
/// attributes in a structured, readable format.
@MainActor
struct AttributeRowView: View {
    // MARK: Internal

    @ObservedObject var viewModel: AXpectorViewModel

    let node: AXPropertyNode // The node whose attribute this is
    let attributeKey: String
    let attributeValue: AnyCodable // Original value from node.attributes

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text("\(attributeKey):")
                    .fontWeight(.semibold)
                    .frame(width: 150, alignment: .leading)
                Text(settableDisplayString)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 30, alignment: .leading)

                if isEditingThisAttribute {
                    TextField("New value", text: $viewModel.editingAttributeValueString)
                        .textFieldStyle(.plain)
                        .border(Color.gray.opacity(0.5)) // Simple border for TextField
                } else {
                    Text(attributeUIDisplayString) // Use new state var for display
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer() // Push edit/set buttons to the right

                if isEditingThisAttribute {
                    HStack(spacing: 4) {
                        Button("Set") {
                            viewModel.commitAttributeEdit(node: node, originalAttributeKey: attributeKey)
                        }
                        Button("Cancel") {
                            viewModel.cancelAttributeEdit()
                        }
                    }
                } else if isSettable == true { // Only show Edit button if known to be settable
                    Button("Edit") {
                        viewModel.prepareAttributeForEditing(node: node, attributeKey: attributeKey)
                    }
                } else if isSettable == nil { // Still checking or haven't checked yet
                    ProgressView().controlSize(.small)
                }
                // If isSettable is false, no button is shown

                // Add Navigate button if applicable
                if attributeUIType == .axElement || attributeUIType == .arrayOfAXElements {
                    Button(attributeUIType == .arrayOfAXElements ? "Nav First" : "Navigate") {
                        Task {
                            var elementRefCF: CFTypeRef?
                            let axError = AXUIElementCopyAttributeValue(
                                node.axElementRef,
                                attributeKey as CFString,
                                &elementRefCF
                            )

                            if axError == .success, let valueRef = elementRefCF {
                                var refToNavigate: AXUIElement?
                                if attributeUIType == .axElement {
                                    if CFGetTypeID(valueRef) == AXUIElementGetTypeID() {
                                        refToNavigate = (valueRef as! AXUIElement)
                                    } else {
                                        axWarningLog(
                                            "Attribute \(attributeKey) expected AXUIElement but got other type."
                                        )
                                    }
                                } else if attributeUIType == .arrayOfAXElements {
                                    if CFGetTypeID(valueRef) == CFArrayGetTypeID() {
                                        let array = valueRef as! CFArray
                                        if CFArrayGetCount(array) > 0 {
                                            let firstElementRaw = CFArrayGetValueAtIndex(array, 0)
                                            // Ensure the first element is indeed an AXUIElement
                                            if let firstElementTyped = firstElementRaw as? AnyObject,
                                               CFGetTypeID(firstElementTyped) == AXUIElementGetTypeID()
                                            {
                                                // We need to retain this specific element if we're passing it out of
                                                // the array's scope
                                                // or ensure the ViewModel copies it. For now, we assume
                                                // navigateToElementInTree handles it.
                                                // AXUIElement is a CFType, so it should be CFRetained if kept beyond
                                                // immediate scope.
                                                // However, navigateToElementInTree is not designed to take ownership.
                                                // The simplest is to pass it directly. If AXUIElement is a struct
                                                // wrapper in AXorcistLib, it handles its own lifetime.
                                                // Given AXUIElement is a direct CFType, direct pass is fine if usage is
                                                // immediate.
                                                refToNavigate = (firstElementTyped as! AXUIElement)
                                                // No need to CFRetain refToNavigate here as it's from within a CFArray
                                                // whose lifetime is managed by valueRef.
                                            } else {
                                                axWarningLog(
                                                    "Attribute \(attributeKey) is arrayOfAXElements, but first element is not AXUIElement."
                                                )
                                            }
                                        } else {
                                            axInfoLog(
                                                "Attribute \(attributeKey) is an empty array of elements. Cannot navigate."
                                            )
                                        }
                                    } else {
                                        axWarningLog("Attribute \(attributeKey) expected CFArray but got other type.")
                                    }
                                } else {
                                    // Should not happen if type is .axElement
                                }

                                if let finalRefToNavigate = refToNavigate {
                                    viewModel.navigateToElementInTree(
                                        axElementRef: finalRefToNavigate,
                                        currentAppPID: node.pid
                                    )
                                    // If refToNavigate was for .axElement, it was the `valueRef` that was CFReleased by
                                    // its own defer or outer scope.
                                    // If it was from an array, its lifetime is tied to the array `valueRef` which is
                                    // released.
                                    // We should not release `finalRefToNavigate` here if it's just a pointer from the
                                    // array.
                                    // This area is tricky with CF memory management.
                                    // Let's assume navigateToElementInTree does not take ownership, and the ref from
                                    // array is valid for its call.
                                    // The original valueRef (single element or array) is released.
                                    if attributeUIType == .axElement,
                                       let singleElementValueRef = valueRef as! AXUIElement?,
                                       singleElementValueRef === finalRefToNavigate
                                    {
                                        // If it was a single element, it was already released by defer. This path is
                                        // tricky.
                                        // Let's simplify: if it was a single AXUIElement, it needs release if it was
                                        // the valueRef. If it was part of array, not here.
                                        // The defer { CFRelease(valueRef) } will handle the single element case
                                        // correctly if valueRef was the direct AXUIElement.
                                        // This `if` block for .axElement should correctly release valueRef if
                                        // refToNavigate was set from it.
                                    }
                                } else if attributeUIType == .axElement {
                                    // If refToNavigate is nil, and type was .axElement, valueRef should have been
                                    // released if it was non-nil by the outer defer.
                                    // This else branch is for cases where the cast/check failed inside .axElement case.
                                }
                            } else {
                                axWarningLog(
                                    "Could not get value for attribute \(attributeKey) for navigation. Error: \(axError.rawValue)"
                                )
                            }
                        }
                    }
                    // .disabled(attributeUIType == .arrayOfAXElements) // Enable for arrays now
                }
            }
            .padding(.leading)
            .task(id: node.id.uuidString + attributeKey) {
                let info = viewModel.fetchAttributeUIDisplayInfo(
                    for: node,
                    attributeKey: attributeKey,
                    attributeValue: attributeValue
                )
                if attributeKey == self.attributeKey, node.id == self.node.id {
                    self.attributeUIDisplayString = info.displayString
                    // self.attributeUIType = info.valueType // valueType was removed from AttributeDisplayInfo
                    // self.settableDisplayString = info.settableDisplayString // VM already provides this in info
                    // Let AttributeRowView decide the final display string for settable status based on Bool
                    if info.isSettable {
                        self.settableDisplayString = " (W)"
                    } else {
                        // Only show (R) if the status is definitively known and it's not settable
                        // If isSettable from info is nil (e.g. error in check), show nothing or loading
                        self.settableDisplayString = "" // CHANGED - was " (R)", empty string is better if not settable.
                    }
                    self.isSettable = info.isSettable
                    // self.navigatableElementRefForButton = info.navigatableElementRef // Not storing ref directly
                }
            }
        }
        // Display a small note if the attribute is known not to be settable, after checking
        // This is disabled for now to simplify. The absence of an Edit button after check implies not settable.
        /*
         if isSettable == false {
             Text("(Not settable)").font(.caption2).foregroundColor(.gray).padding(.leading, 155)
         }
         */
    }

    // MARK: Private

    @State private var isSettable: Bool? // Null until checked
    @State private var settableDisplayString: String = "" // For " (W)" indicator
    @State private var attributeUIDisplayString: String = "Loading..." // For actual value display
    @State private var attributeUIType: AXAttributeValueType?

    // @State private var navigatableElementRefForButton: AXUIElement? = nil // Not storing ref directly

    private var isEditingThisAttribute: Bool {
        viewModel.editingAttributeKey == attributeKey && viewModel.selectedNode?.id == node.id
    }
}
