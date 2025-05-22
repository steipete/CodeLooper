# Tuist Integration

## Overview

This document describes the Tuist integration for the FriendshipAI macOS application. Tuist is a tool that simplifies the creation, maintenance, and interaction with Xcode projects.

## Project Structure

The macOS app uses a standard structure with sources in their own directory:

```
mac/
├── Sources/
│   ├── Application/      # Core application code (AppDelegate, etc.)
│   ├── Authentication/   # Authentication services
│   ├── Components/       # Reusable UI components
│   ├── Contacts/         # Contact management
│   ├── Diagnostics/      # Logging and diagnostics
│   ├── Permissions/      # Permission handling
│   ├── Settings/         # User settings
│   ├── StatusBar/        # Menu bar and status icon functionality
│   ├── Upload/           # Data upload functionality
│   └── Utilities/        # Shared utilities and extensions
├── Resources/            # Resource files
└── FriendshipAI/         # App bundle resources
    ├── Assets.xcassets/  # Image assets
    ├── Base.lproj/       # Base localization files
    ├── Info.plist        # App info property list
    └── FriendshipAI.entitlements # App entitlements
```

## Setup

The project is configured to use Tuist for improved Xcode project management. Key files include:

- `Project.swift`: Defines the project structure, dependencies, and build settings
- `Tuist.swift`: Contains Tuist-specific configuration options
- `Tuist/ProjectDescriptionHelpers`: Contains helper functions for project description

## Dependencies

The project uses the following Swift Package Manager dependencies:

- KeyboardShortcuts: For handling keyboard shortcuts
- Defaults: For user defaults management
- SwiftUIIntrospect: For SwiftUI view introspection
- Swift-log: For logging
- ArgumentParser: For command-line argument parsing
- KeychainAccess: For secure storage
- LaunchAtLogin: For launch-at-login functionality

## Swift Settings

The project is configured to use Swift 6 with strict concurrency checking:

- `-strict-concurrency=complete`: Ensures complete concurrency checking for Swift 6 compatibility
- Debug builds include additional flags:
  - `-warn-concurrency`: Warns about potential concurrency issues
  - `-enable-actor-data-race-checks`: Enables runtime checking for actor data races

## Swift 6 Sendable Compatibility

Swift 6 introduces strict Sendable checking that requires careful handling of Info.plist values. The project uses a specialized script to fix Sendable compliance issues in Tuist-generated files:

### Common Issues and Fixes

1. **Dictionary Type Safety**: Tuist-generated `Info.plist` constants use `[String: Any]` types which are not Sendable-compliant.

   - Error: "Static property is not concurrency-safe because non-'Sendable' type '[String: Any]' may have shared mutable state"
   - Solution: The `generate-xcproj.sh` script automatically converts:
     - `[String: Any]` → `[String: Bool]` for `NSAppTransportSecurity`
     - `[[String: Any]]` → `[[String: String]]` for `CFBundleURLTypes`

2. **ResourceLoader Compatibility**: The `ResourceLoader` class is updated to use the typed dictionaries.
   - Generic methods like `getAppTransportSecurityValue<T>` are replaced with type-specific versions like `getAppTransportSecurityBoolValue`
   - This avoids "Cannot explicitly specialize static method" errors in Swift 6

### Generating Project with Sendable Fixes

Always use the provided script to generate the Xcode project:

```bash
cd mac
./scripts/generate-xcproj.sh
```

This script:

1. Runs `tuist generate` to create the Xcode project
2. Automatically patches the generated `TuistPlists+FriendshipAI.swift` file
3. Updates the `ResourceLoader.swift` file to work with the new type-safe dictionaries

## Usage

### Generating Project Files

To generate the Xcode project files with Sendable compatibility fixes:

```bash
cd mac
./scripts/generate-xcproj.sh
```

### Opening the Project

After generating the project, open the workspace:

```bash
open FriendshipAI.xcworkspace
```

## Maintaining the Configuration

### Adding New Dependencies

To add a new dependency:

1. Add it to the `packages` array in `Project.swift`
2. Add it to the target's `dependencies` array if needed
3. Ensure the same dependency is added to `Package.swift` for Swift Package Manager compatibility

### Adding New Info.plist Keys

When adding new Info.plist keys that use dictionary values:

1. Update `InfoKey.swift` to add the new key definitions
2. Modify `generate-xcproj.sh` if the key uses non-Sendable dictionary types
3. Add appropriate accessor methods in `ResourceLoader.swift` that handle the type correctly

### Updating Configurations

If you need to update build settings or other configurations, modify the appropriate sections in `Project.swift`.

## Platform Requirements

The project targets macOS 14.0 or later to support the latest Swift features and macOS APIs like the native SwiftUI Settings framework.

## Benefits of Tuist

- Consistent project generation
- Simplified dependency management
- Improved project organization
- Better collaboration through standard project structure
- Reduced merge conflicts in Xcode project files
- Automated handling of Swift 6 Sendable compatibility issues

## Troubleshooting

If you encounter issues with Tuist:

1. Make sure Tuist is installed correctly: `brew install tuist`
2. Try cleaning the Tuist cache: `tuist clean`
3. Regenerate the project with the script: `./scripts/generate-xcproj.sh`

For common Swift 6 Sendable issues:

- If you see "not concurrency-safe because non-'Sendable' type" errors:
  - Check if the script properly patched the generated files
  - Look for dictionary types that need to be more strictly typed
  - Make sure the appropriate accessor methods use the specific types

## Additional Resources

- [Tuist Documentation](https://docs.tuist.io/documentation)
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [Swift Documentation on Sendable Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency#Sendable-Types)
