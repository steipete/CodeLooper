# FriendshipAI macOS App Architecture

This document outlines the architecture and organization of the FriendshipAI macOS application codebase.

## Core Architecture

The FriendshipAI macOS app follows a modular architecture organized around features and clear separation of concerns. The app is transitioning from a traditional AppKit architecture to a more modern SwiftUI approach, making use of Swift's latest concurrency features.

### Key Architectural Patterns

- **Feature-based modules**: Code is organized by feature/domain rather than by technical type
- **MVVM pattern**: ViewModels mediate between Model and View for SwiftUI components
- **Dependency injection**: Services are passed where needed rather than accessed globally
- **Actor isolation**: Thread safety is ensured with `@MainActor` and Swift concurrency
- **Environment objects**: For sharing state across the SwiftUI component tree
- **Combine**: For reactive data flow with publishers and subscribers

## Directory Structure

The codebase is organized into the following high-level directories:

```
/Sources
├── App/              # Application lifecycle and environment
├── Features/         # Feature modules by domain
├── Core/             # Core services and utilities
├── UI/               # User interface components
└── Shared/           # Shared utilities and extensions
```

### App

The `App` directory contains the core application structure and lifecycle components:

- `AppMain.swift`: SwiftUI App entry point with scene definitions
- `AppDelegate.swift`: Legacy AppKit delegate for system integration
- `Environment/`: App-wide state management and environment objects

### Features

Feature modules encapsulate specific domain functionality and are organized by business domain:

- **Authentication**: User login, token management, and OAuth flows
- **Contacts**: Contact export, upload, and statistics
- **Settings**: User preferences and configuration

Each feature module follows a similar internal structure:

- `Services/`: Business logic and domain services
- `Models/`: Domain-specific data models
- `UI/`: Feature-specific UI components

### Core

Core services provide fundamental infrastructure used across the application:

- **Permissions**: System permission handling
- **Logging**: Structured logging system
- **Storage**: Data persistence (Keychain, UserDefaults, File System)
- **Networking**: API client and network operations

### UI

UI components are organized by their scope and reusability:

- **Components**: Reusable UI elements
- **Scenes**: Major UI screens and flows
- **Menu**: Menu bar components and status icon

### Shared

Utilities and extensions that are used across the application:

- **Extensions**: Swift extension methods
- **Protocols**: Common protocol definitions
- **Utils**: Helper functions and utility classes

## Key System Interactions

### Contact Synchronization Flow

1. **Permissions**: Request access to contacts via `PermissionsManager`
2. **Export**: Extract contacts via `ContactsExporter`
3. **Upload**: Send contacts to backend via `ContactsUploader`
4. **Status**: Update UI via `MenuManager` and `StatusIconManager`

### Authentication Flow

1. **OAuth Request**: Initiate web authentication via `WebAuthenticationService`
2. **Token Capture**: Process OAuth callback and extract token
3. **Storage**: Secure token in Keychain via `KeychainManager`
4. **State Update**: Update application state via `AppEnvironment`

## Threading Model

The application follows strict thread safety practices:

1. **MainActor Isolation**: All UI code and most managers are marked with `@MainActor`
2. **Async/Await**: Background work uses structured concurrency with `Task`
3. **Atomic Operations**: Thread-safe primitive values use `Atomic<T>` wrapper
4. **Actor-based isolation**: Long-running operations are isolated with custom actors
5. **Sendable Conformance**: Types that cross actor boundaries are `Sendable`

## Design Decisions

### SwiftUI Integration

The app uses a hybrid approach during the transition to SwiftUI:

- **NSApplicationDelegateAdaptor**: Bridges SwiftUI lifecycle with AppKit
- **Scene Definitions**: Windows are defined as SwiftUI scenes
- **Environment Objects**: Share state through the SwiftUI view hierarchy
- **Notification Bridges**: Allow AppKit and SwiftUI to communicate

### Concurrency Safety

The codebase has been modernized with Swift's concurrency features:

- **System API Callbacks**: All system callbacks properly dispatch to MainActor
- **Sendable Checks**: Types are marked as `Sendable` where appropriate
- **Task Management**: Background work is properly scheduled and canceled
- **Continuation Handling**: Completion handlers are bridged to async/await

## Evolution Roadmap

The architecture is evolving in these directions:

1. **Complete SwiftUI Migration**: Gradually replace AppKit components
2. **Full Concurrency**: Eliminate remaining legacy dispatch patterns
3. **Modularization**: Move toward package-based modules
4. **Enhanced Testing**: Increase unit test coverage with dependency injection

## File Organization Best Practices

When adding new files to the codebase:

1. **Feature-First**: Place files in the appropriate feature module
2. **Consistent Naming**: Follow established naming patterns
3. **Minimal Dependencies**: Avoid unnecessary cross-module dependencies
4. **Protocol-Based Design**: Define protocols in the appropriate module

## Testing Strategy

The testing strategy follows these principles:

1. **Unit Testing**: Services and utilities have unit tests
2. **UI Testing**: Key workflows have UI tests
3. **Mock Services**: Dependencies are mocked for isolated testing
4. **Test Discoverability**: Tests mirror the production code structure

---

This architecture document is maintained alongside the codebase and will be updated as the architecture evolves.
