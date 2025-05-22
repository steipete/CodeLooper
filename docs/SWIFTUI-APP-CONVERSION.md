# SwiftUI App Conversion Guide

This document describes the approach used to modernize the FriendshipAI macOS app by adopting the SwiftUI App lifecycle while maintaining compatibility with the existing AppKit-based code.

## Overview

We've implemented a hybrid architecture that allows the app to run with either:

1. **Traditional AppKit Lifecycle** (`NSApplicationDelegate`-based)
2. **Modern SwiftUI App Lifecycle** (SwiftUI `App` protocol-based)

This approach provides a smooth migration path while allowing incremental conversion of the app to SwiftUI.

## Architecture

The architecture uses an adapter pattern to bridge between the two lifecycles:

```
┌───────────────────┐     ┌────────────────────┐     ┌──────────────────┐
│ SwiftUI App       │     │ AppDelegate        │     │ AppKit Components│
│ (@main AppMain)   │────►│ (via adaptor)      │────►│ (existing code)  │
└───────────────────┘     └────────────────────┘     └──────────────────┘
         │                        │                          │
         ▼                        ▼                          ▼
┌───────────────────┐     ┌────────────────────┐     ┌──────────────────┐
│ SwiftUI Components│     │ Coordinator Layer  │     │ NSHostingView    │
│ (new components)  │◄────│ (bridging classes) │◄────│ (SwiftUI adapters│
└───────────────────┘     └────────────────────┘     └──────────────────┘
```

### Key Components

1. **AppMain.swift**

   - SwiftUI entry point (marked with `@main`)
   - Uses `@NSApplicationDelegateAdaptor` to maintain the existing `AppDelegate`
   - Defines SwiftUI scenes for various windows
   - Handles single instance checking

2. **SwiftUIEnvironment.swift**

   - Provides app-wide state through the `AppEnvironment` class
   - Implements reactive state updates using Combine
   - Syncs with UserDefaults for persistence
   - Implements theme management

3. **WelcomeWindowCoordinator.swift**

   - Coordinates welcome window display between AppKit and SwiftUI
   - Detects which lifecycle is active and adapts accordingly
   - Uses notification-based communication

4. **Component Adapters**
   - `SettingsView.swift` - Adapts the existing settings view for SwiftUI
   - `WelcomeWindowView.swift` - Adapts the welcome window for SwiftUI
   - `MacSettingsScene.swift` - Custom implementation for settings window management

## Implementation Details

### Lifecycle Detection

The code detects which lifecycle is active using class inspection:

```swift
var isSwiftUILifecycle: Bool {
    return NSApplication.shared.delegate is AppDelegate &&
           NSClassFromString("_TtC16FriendshipAI7AppMain") != nil
}
```

### Window Management

Windows are managed differently depending on the lifecycle:

1. **SwiftUI Lifecycle**

   - Windows are defined as SwiftUI scenes in `AppMain`
   - Window visibility is controlled through state variables
   - Windows use SwiftUI's `.windowStyle()` and `.commands()` modifiers

2. **AppKit Lifecycle**
   - Traditional `NSWindowController` are used
   - The app manually creates windows from SwiftUI content using `NSHostingController`
   - Window visibility is managed through manual `showWindow` and `close` calls

### Environment and State Management

The app uses a comprehensive environment model:

```swift
@MainActor
class AppEnvironment: ObservableObject {
    // Authentication state
    @Published var isAuthenticated: Bool = false

    // Window state
    @Published var showWelcomeScreen: Bool = false

    // User information
    @Published var userName: String? = nil
    @Published var userEmail: String? = nil
    @Published var userAvatarURL: URL? = nil

    // App state
    @Published var isUploading: Bool = false
    @Published var isSetupComplete: Bool = false

    // Initialization sets up bindings to UserDefaults & notification observers
    init() { ... }
}
```

### Communication Between Lifecycles

Both lifecycles communicate through:

1. **Shared Coordinator Objects**

   - `WelcomeWindowCoordinator` maintains singleton instance accessible by both

2. **Notification Center**

   - Notifications allow cross-lifecycle communication
   - Custom notification names defined for key events
   - Both lifecycles observe relevant notifications

3. **UserDefaults**
   - Persistent settings are shared via UserDefaults
   - Both systems react to changes using Combine publishers or notification observers

### Thread Safety and Concurrency

The implementation follows modern Swift concurrency patterns:

1. **MainActor Isolation**

   - UI components are explicitly marked with `@MainActor`
   - Asynchronous operations use `Task` and `await`

2. **Sendable Conformance**
   - Types that cross actor boundaries are marked `Sendable`
   - `@unchecked Sendable` is used for types that require manual verification

## Benefits of the New Architecture

1. **Modern SwiftUI Features**

   - Access to modern SwiftUI lifecycle and features
   - Better state management with environment objects
   - Declarative window management with scenes

2. **Gradual Migration Path**

   - No need to rewrite all UI components at once
   - Existing AppKit components continue to work
   - SwiftUI components can be added incrementally

3. **Better State Management**

   - Reactive state updates through Combine and SwiftUI
   - Cleaner data flow with environment objects
   - Better separation of concerns with dedicated managers

4. **Improved Concurrency Handling**
   - Support for Swift Concurrency (`async`/`await`)
   - Better MainActor isolation for UI components
   - More explicit thread safety with Sendable conformance

## Migration Path

The migration follows a phased approach:

1. **Initial Setup**

   - Create AppMain.swift with `@main` attribute
   - Maintain existing AppDelegate with `@NSApplicationDelegateAdaptor`
   - Implement single instance logic in SwiftUI lifecycle

2. **Environment Creation**

   - Define app-wide environment with SwiftUI's environment system
   - Create bidirectional bindings between environment and UserDefaults
   - Setup notification observers for cross-component communication

3. **Window Adapters**

   - Create SwiftUI adapters for existing AppKit windows
   - Implement scenes in the App's body for each window type
   - Create coordinators to bridge between AppKit and SwiftUI windows

4. **Theme Integration**

   - Implement consistent theme management across both lifecycles using AppEnvironment
   - Create bidirectional sync between AppKit appearance and SwiftUI themes via environment properties
   - Use environment for theme distribution to all components

5. **Incremental Component Migration**
   - Gradually convert AppKit components to SwiftUI
   - Start with simple, standalone components
   - Leave complex integrated components for later phases

## Future Improvements

1. **Complete Component Migration**

   - Continue converting AppKit components to SwiftUI
   - Replace NSHostingView bridges with native SwiftUI views
   - Simplify coordinators once migration is complete

2. **SwiftUI Scene Enhancements**

   - Add more scene customization for different windows
   - Implement better cross-scene communication
   - Leverage more SwiftUI lifecycle hooks

3. **Environment Enhancement**
   - Expand environment with more app-wide state
   - Add more services to the environment
   - Improve dependency injection through the environment

## References

- [Apple: Adopting SwiftUI in an AppKit Application](https://developer.apple.com/documentation/swiftui/adopting-swiftui-in-an-appkit-application)
- [Apple: NSApplicationDelegateAdaptor](https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor)
- [Apple: App Protocol](https://developer.apple.com/documentation/swiftui/app)
- [Apple: Scene Protocol](https://developer.apple.com/documentation/swiftui/scene)
- [Apple: StateObject Property Wrapper](https://developer.apple.com/documentation/swiftui/stateobject)
- [Vlad Smolyanoy: SwiftUI App Structure for Menu Bar Apps](https://twitter.com/vlad_sm/status/1578343970791911424)
