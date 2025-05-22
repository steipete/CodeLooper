# Notification System

This document describes the notification naming convention and usage patterns in the CodeLooper macOS app.

## Notification Naming Convention

All notifications in the app follow a standardized naming convention to ensure uniqueness and clarity:

```
bundleIdentifier.notificationName
```

For example:

```swift
ai.amantusmachina.codelooper.userLoggedIn
```

### Benefits of this Convention

1. **Uniqueness**: Using the bundle identifier as a prefix prevents collisions with system or third-party notifications
2. **Clarity**: The notification name clearly describes the event that occurred
3. **Discoverability**: All notifications are defined in a single file with documentation
4. **Consistency**: All notifications follow the same pattern, making the codebase more maintainable

## Notification Organization

Notifications are organized in the `NotificationName.swift` file by functional area:

- User Preferences
- Authentication
- UI Actions
- Navigation
- Development & Debugging
- UI Appearance
- Application State
- Contact Management
- Upload Operations

Each notification has a documentation comment explaining when it is posted.

## Usage Examples

### Posting a Notification

```swift
// Post a notification without additional data
NotificationCenter.default.post(name: .userLoggedIn, object: nil)

// Post a notification with additional data in userInfo
NotificationCenter.default.post(
    name: .menuBarVisibilityChanged,
    object: nil,
    userInfo: ["isVisible": true]
)
```

### Observing a Notification

```swift
// Using the traditional selector approach
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleUserLogin),
    name: .userLoggedIn,
    object: nil
)

// Using a block-based observer
NotificationCenter.default.addObserver(
    forName: .menuBarVisibilityChanged,
    object: nil,
    queue: .main
) { notification in
    // Extract data from notification
    let isVisible = notification.userInfo?["isVisible"] as? Bool ?? true

    // Handle the notification
    updateUIForMenuBarVisibility(isVisible)
}
```

### Managing Multiple Observers

For classes that need to observe multiple notifications, set up observers in a dedicated method and store them to be removed when appropriate:

```swift
private var observers: [NSObjectProtocol] = []

private func setupNotificationObservers() {
    // Add observer for user login
    observers.append(
        NotificationCenter.default.addObserver(
            forName: .userLoggedIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserLogin()
        }
    )

    // Add observer for settings changes
    observers.append(
        NotificationCenter.default.addObserver(
            forName: .preferencesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePreferencesChanged()
        }
    )
}

deinit {
    // Remove all observers when this object is deallocated
    observers.forEach { NotificationCenter.default.removeObserver($0) }
}
```

## Cross-Lifecycle Communication

Notifications provide a key mechanism for communication between the SwiftUI and AppKit lifecycles:

1. **SwiftUI Component → AppKit Component**: SwiftUI components can post notifications that AppKit components observe to trigger actions
2. **AppKit Component → SwiftUI Component**: AppKit components can post notifications that SwiftUI components observe via the environment or view modifiers

## Best Practices

1. **Documentation**: Always document when and why a notification is posted
2. **Type Safety**: Use the strongly-typed notification names rather than string literals
3. **Memory Management**: Use `[weak self]` in block-based observers to prevent memory leaks
4. **Centralization**: Define all notifications in the `NotificationName.swift` file
5. **Consistency**: Follow the naming convention for all new notifications
6. **UserInfo**: When passing data in userInfo, use clear key names and document the expected types

## Adding New Notifications

To add a new notification:

1. Identify the functional area the notification belongs to
2. Add the notification constant to the appropriate section in `NotificationName.swift`
3. Follow the naming convention: `bundleIdentifier.notificationName`
4. Add documentation explaining when the notification is posted
5. If the notification includes userInfo data, document the expected keys and types

Example:

```swift
/// Posted when the user completes the onboarding process
public static let onboardingCompleted = Notification.Name("\(domain).onboardingCompleted")
```
