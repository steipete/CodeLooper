# macOS Menu Implementation Best Practices

This document outlines best practices for implementing menus in macOS applications, with specific focus on the CodeLooper macOS app.

## Target-Action Implementation for NSMenuItem

### Best Practices:

1. **Explicitly Set Target for Menu Items:**

   - Always set the target property to ensure proper action routing
   - Example:

   ```swift
   let menuItem = NSMenuItem(title: "Some Action", action: #selector(someAction), keyEquivalent: "")
   menuItem.target = self  // This is crucial!
   ```

2. **Use nil Target Only When Appropriate:**

   - Only use nil targets for items that should use responder chain
   - Section headers, status indicators, and submenu parents often use nil actions
   - For items with actions, always set a target

3. **Define Selector References Using #selector:**

   - Always use `#selector` syntax to ensure compile-time checking of selector names
   - Example:

   ```swift
   action: #selector(MenuManager.toggleDebugMenuAction)
   ```

4. **Forward Actions to Delegate:**
   - In action methods, delegate the actual implementation to a proper delegate
   - This maintains separation of concerns
   - Example:
   ```swift
   @objc
   func showSettingsAction() {
       delegate?.showSettings()
   }
   ```

## Responder Chain vs. Explicit Targets

### When to Use Responder Chain (nil Target):

1. **Standard Application Commands:**

   - Standard editing commands (cut, copy, paste)
   - Document operations (save, print)
   - Application-wide functionality

2. **Benefits:**
   - Simplifies menu implementation
   - Allows different responders to handle the same action based on context
   - Follows Apple's recommended pattern for standard commands

### When to Set Explicit Targets:

1. **Menu-Specific Actions:**

   - Actions that are specifically tied to the menu controller
   - Custom functionality not in standard responder chain
   - **This is the case for most of our menu items in CodeLooper**

2. **Benefits:**
   - Direct routing of actions to specific handlers
   - Clear ownership of functionality
   - Easier to debug action routing issues
   - Better performance (no responder chain traversal)

## Common Pitfalls in Menu Implementation

1. **Missing Targets:**

   - **Pitfall:** Creating menu items with actions but not setting targets
   - **Solution:** Always explicitly set the target property for menu items with actions:

   ```swift
   menuItem.target = self
   ```

2. **Threading Issues:**

   - **Pitfall:** Manipulating menu UI from background threads
   - **Solution:** Use `@MainActor` for menu-related code

3. **Memory Management Issues:**

   - **Pitfall:** Retaining cycle with delegates
   - **Solution:** Use `weak var delegate: MenuManagerDelegate?`

4. **Validation Handling:**

   - **Pitfall:** Missing menu validation, causing inappropriate menu item enablement
   - **Solution:** Implement `validateMenuItem:` or `validateUserInterfaceItem:` in the target

5. **Key Equivalent Conflicts:**
   - **Pitfall:** Duplicate key equivalents causing unexpected behavior
   - **Solution:** Carefully assign unique key equivalents for each action context

## Apple's Recommendations for Menu Design

### Menu Organization:

1. **Logical Grouping:**

   - Group related items together
   - Use separator items between groups

2. **Menu Section Headers:**
   - Use descriptive headers for sections with visual distinction
   - Example:
   ```swift
   let actionsHeader = NSMenuItem(title: "Actions", action: nil, keyEquivalent: "")
   actionsHeader.isEnabled = false
   actionsHeader.attributedTitle = NSAttributedString(
       string: "ACTIONS",
       attributes: [
           .font: NSFont.systemFont(ofSize: 11, weight: .medium),
           .foregroundColor: NSColor.secondaryLabelColor
       ]
   )
   ```

### Visual Design:

1. **Use System Icons:**

   - Prefer SF Symbols for menu icons
   - Maintain consistent size and style

2. **Accessibility Support:**
   - Always set accessibilityDescription for images:
   ```swift
   image.accessibilityDescription = "Description of what this does"
   ```

### Menu Validation and State:

1. **Dynamic Menu Updates:**
   - Update menu items state and title as needed:
   ```swift
   startAtLoginItem.state = Defaults[.startAtLogin] ? .on : .off
   ```

## Implementation in CodeLooper

To ensure all menu items in the CodeLooper macOS app have proper targets:

1. **Modify Menu Creation:**

   - In `MenuManagerExtension.swift` and `MenuBuilder.swift`, update all menu item creation to include `target = self`:

   ```swift
   let menuItem = NSMenuItem(title: "Action", action: #selector(MenuManager.action), keyEquivalent: "")
   menuItem.target = self  // Add this line for all action menu items
   ```

2. **Skip Setting Target For:**
   - Section headers (with nil action)
   - Status indicators (with nil action)
   - Separator items
   - Items with submenu

## References

- [Apple Human Interface Guidelines - Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
- [Apple Developer Documentation - NSMenuItem](https://developer.apple.com/documentation/appkit/nsmenuitem)
- [NSResponder and the Responder Chain](https://developer.apple.com/documentation/appkit/nsresponder)
