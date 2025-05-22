# External Dependencies

This document provides details about the external dependencies used in the CodeLooper macOS application.

## Table of Contents

- [Overview](#overview)
- [AXorcist](#axorcist)
- [Sparkle](#sparkle)
- [SwiftLint](#swiftlint)
- [Adding New Dependencies](#adding-new-dependencies)

## Overview

The CodeLooper macOS app uses several carefully selected dependencies to enhance functionality, improve code quality, and provide better user experience. All dependencies are managed via Swift Package Manager (SPM) and defined in `Package.swift`.

## AXorcist

**Repository**: Local Swift Package (submodule)

AXorcist is a Swift accessibility library that provides reliable UI element detection and interaction capabilities for automating other applications.

### Implementation

- Primary Usage: Cursor supervision and automation
- Integration: Direct Swift Package dependency
- Manager: `AXorcistClient` for handling UI interactions

### Features

- **UI Element Detection**: Reliable detection of UI elements in target applications
- **Action Execution**: Performing clicks, typing, and other UI interactions
- **Accessibility API**: Uses macOS Accessibility APIs for system integration
- **Thread Safety**: MainActor-based API for safe UI interaction
- **Error Handling**: Comprehensive error reporting for failed interactions

### Usage Examples

```swift
// Create AXorcist instance
let axController = AXorcist()

// Query for UI elements
let response = await MainActor.run {
    axController.handleQuery(command: queryCommand)
}

// Perform actions on elements
let actionResponse = await MainActor.run {
    axController.handlePerformAction(locator: buttonLocator, actionName: kAXPressAction)
}
```

## Sparkle

**GitHub**: [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle)

Sparkle provides automatic update functionality for the CodeLooper app, allowing users to receive updates seamlessly.

### Implementation

- Configuration: `Info.plist` with update feed URL and public key
- Integration: `SPUStandardUpdaterController` in `AppDelegate`
- UI: Update prompts and settings in the app preferences

### Features

- **Automatic Updates**: Background checking and downloading of updates
- **Security**: EdDSA signature verification for secure updates
- **User Control**: User-configurable update preferences
- **Silent Updates**: Option for silent background updates
- **Rollback Protection**: Prevents installation of older versions

### Usage Examples

```swift
// Initialize updater in AppDelegate
private let updaterController = SPUStandardUpdaterController()

// Check for updates programmatically
updaterController.updater.checkForUpdates()

// Configure automatic checks
updaterController.updater.automaticallyChecksForUpdates = true
```

## SwiftLint

**GitHub**: [realm/SwiftLint](https://github.com/realm/SwiftLint)

SwiftLint is a tool for enforcing Swift style and conventions based on a set of customizable rules. It helps maintain consistent code quality across the codebase.

### Implementation

- Configuration file: `.swiftlint.yml` in the project root
- Integration scripts: `lint.sh` and `run-swiftlint.sh`
- CI integration: Non-blocking lint checks in GitHub Actions

### Usage

To run SwiftLint locally:

```bash
./lint.sh
```

To set up Git pre-commit hooks for automatic linting:

```bash
./setup-git-hooks.sh
```

### Features

- **Customizable Rules**: Tailored rule set defined in `.swiftlint.yml`
- **Build Integration**: Runs automatically during builds
- **CI Integration**: Results included in PR comments
- **Error Reporting**: Clear, actionable error messages
- **Auto-correct**: Can fix some issues automatically

For detailed information on SwiftLint rules and configuration, see [SWIFTLINT.md](SWIFTLINT.md).


## Adding New Dependencies

When adding a new dependency to the project:

1. **Evaluate Necessity**: Consider whether the dependency is truly needed
2. **Check License**: Ensure the license is compatible with our project
3. **Update Package.swift**: Add the dependency to `Package.swift`
4. **Document Usage**: Add documentation to explain how the dependency is used
5. **Create Integration Files**: Create appropriate wrapper classes to abstract the dependency
6. **Update CI**: Ensure the CI systems can handle the new dependency

### Process

```swift
// 1. Add to Package.swift
dependencies: [
    .package(url: "https://github.com/example/new-dependency.git", from: "1.0.0")
],
targets: [
    .target(name: "CodeLooper", dependencies: ["NewDependency"])
]

// 2. Create a wrapper class to abstract the dependency
struct DependencyManager {
    static let shared = DependencyManager()

    func performOperation() {
        // Use the dependency here
    }
}

// 3. Document the dependency in DEPENDENCIES.md
```
