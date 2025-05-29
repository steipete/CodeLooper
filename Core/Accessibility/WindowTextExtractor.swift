import AppKit
import ApplicationServices

/// Extracts all visible text from a window using accessibility APIs
public enum WindowTextExtractor {
    // MARK: Public

    /// Errors that can occur during text extraction
    public enum ExtractionError: Error, LocalizedError {
        case noFrontmostApp
        case noFrontWindow
        case accessibilityError(String)

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .noFrontmostApp:
                "No frontmost application found"
            case .noFrontWindow:
                "No front window found"
            case let .accessibilityError(message):
                "Accessibility error: \(message)"
            }
        }
    }

    /// Extracts all text from the frontmost window
    /// - Returns: Combined text from all text elements in the window
    /// - Throws: ExtractionError if text cannot be extracted
    public static func extractTextFromFrontWindow() throws -> String {
        // Get frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw ExtractionError.noFrontmostApp
        }

        // Create AXUIElement for the application
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Get focused window
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success,
              let window = focusedWindow
        else {
            throw ExtractionError.noFrontWindow
        }

        // Extract text from window  
        let windowElement = window as! AXUIElement
        return extractTextFromElement(windowElement)
    }

    /// Extracts text from a specific application by name
    /// - Parameter appName: Name of the application
    /// - Returns: Combined text from all text elements in the app's focused window
    /// - Throws: ExtractionError if text cannot be extracted
    public static func extractTextFromApp(named appName: String) throws -> String {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName == appName || $0.bundleIdentifier?.contains(appName) == true
        }

        guard let app = apps.first else {
            throw ExtractionError.noFrontmostApp
        }

        // Create AXUIElement for the application
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get focused window
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success,
              let window = focusedWindow
        else {
            throw ExtractionError.noFrontWindow
        }

        // Extract text from window  
        let windowElement = window as! AXUIElement
        return extractTextFromElement(windowElement)
    }

    // MARK: Private

    /// Recursively extracts text from an accessibility element and its children
    private static func extractTextFromElement(_ element: AXUIElement) -> String {
        var collectedText = [String]()

        // Get element role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String

        // Check if this element contains text we're interested in
        let textRoles = [
            kAXStaticTextRole as String,
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXButtonRole as String,
            kAXMenuItemRole as String,
            kAXMenuButtonRole as String,
            kAXPopUpButtonRole as String,
            kAXComboBoxRole as String,
        ]

        if let role, textRoles.contains(role) {
            // Try to get value
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
               let value = valueRef as? String,
               !value.isEmpty
            {
                collectedText.append(value)
            }

            // Try to get title (for buttons, menu items, etc.)
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String,
               !title.isEmpty
            {
                collectedText.append(title)
            }

            // Try to get description
            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               !desc.isEmpty
            {
                collectedText.append(desc)
            }
        }

        // Recursively process children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement]
        {
            for child in children {
                let childText = extractTextFromElement(child)
                if !childText.isEmpty {
                    collectedText.append(childText)
                }
            }
        }

        return collectedText.joined(separator: "\n")
    }
}
