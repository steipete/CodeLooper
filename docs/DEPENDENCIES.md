# External Dependencies

This document provides details about the external dependencies used in the FriendshipAI macOS application.

## Table of Contents

- [Overview](#overview)
- [SwiftLint](#swiftlint)
- [KeychainAccess](#keychainaccess)
- [LaunchAtLogin](#launchatlogin)
- [Defaults](#defaults)
- [Swift-log](#swift-log)
- [Adding New Dependencies](#adding-new-dependencies)

## Overview

The FriendshipAI macOS app uses several carefully selected dependencies to enhance functionality, improve code quality, and provide better user experience. All dependencies are managed via Swift Package Manager (SPM) and defined in `Package.swift`.

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

## KeychainAccess

**GitHub**: [kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

KeychainAccess is a simple Swift wrapper around the Keychain API, providing a more convenient and reliable way to handle secure credential storage.

### Implementation

- Primary Manager: `KeychainManager` in `Sources/Helpers/KeychainManager.swift`
- Auth Extension: `KeychainManager+AuthToken.swift` for authentication tokens
- Thread Safety: `@MainActor` annotations for thread-safe operations

### Features

- **Simplified API**: Clean, Swift-friendly API for Keychain operations
- **Error Handling**: Proper error handling and propagation
- **Security**: Industry-standard security practices
- **Thread Safety**: Thread-safe operations
- **Logging**: Comprehensive logging for debugging and audit trails
- **Type Safety**: Strong type safety with Swift's error handling mechanisms

### Usage Examples

```swift
// Store data
try KeychainManager.shared.saveToKeychain(key: "myKey", value: "mySecretValue")

// Retrieve data
if let value = try KeychainManager.shared.getFromKeychain(key: "myKey") {
    // Use the value
}

// Check authentication
if KeychainManager.shared.hasValidAuthToken() {
    // User is authenticated
}
```

For more detailed information on secure credential storage, refer to the KeychainManager implementation in the source code.

## LaunchAtLogin

**GitHub**: [sindresorhus/LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin)

LaunchAtLogin provides an easy way to add and manage "Launch at Login" functionality for macOS applications, which is essential for a menubar app.

### Implementation

- Manager: `LoginItemManager` in `Sources/Helpers/LoginItemManager.swift`
- UI Integration: Toggle in `SettingsView.swift`

### Features

- **Simple API**: Boolean property to toggle launch-at-login
- **System Integration**: Uses macOS's native launch services APIs
- **Reliable Behavior**: Avoids common pitfalls in launch-at-login implementations
- **Modern Swift**: Full SwiftUI compatibility with observable properties
- **Cross-Compatibility**: Works on all modern macOS versions

### Usage Examples

```swift
// Toggle the status
LaunchAtLogin.isEnabled.toggle()

// Check current status
if LaunchAtLogin.isEnabled {
    // App is set to launch at login
}

// SwiftUI integration
Toggle("Launch at login", isOn: $launchAtLogin)
    .onChange(of: launchAtLogin) { newValue in
        LaunchAtLogin.isEnabled = newValue
    }
```

For more detailed information on launch-at-login functionality, refer to the LoginItemManager implementation in the source code.

## Defaults

**GitHub**: [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults)

Defaults is a type-safe, SwiftUI-friendly library for working with UserDefaults, providing better ergonomics and compile-time checks.

### Implementation

- Configuration: `DefaultsKeys` in `Sources/Helpers/DefaultsKeys.swift`
- Manager: `DefaultsManager` in `Sources/Core/DefaultsManager.swift`
- UI Integration: Through `PreferencesManager` in settings views

### Features

- **Type Safety**: Strong typing for all default values
- **SwiftUI Integration**: Seamless integration with SwiftUI's property wrappers
- **Observation**: Reactive updates to UI when preferences change
- **Defaults Suite Support**: Support for app and shared containers
- **Defaultable Protocol**: Extended to support custom types

### Usage Examples

```swift
// Define keys
extension DefaultsKeys {
    static let syncFrequency = Key<Int>("syncFrequency", default: 60)
    static let lastSyncDate = Key<Date?>("lastSyncDate", default: nil)
}

// Access values
let syncFrequency = Defaults[.syncFrequency]

// Update values
Defaults[.syncFrequency] = 120

// Observe changes
Defaults.observe(.syncFrequency) { change in
    print("Sync frequency changed from \(change.oldValue) to \(change.newValue)")
}

// SwiftUI integration
struct SettingsView: View {
    @Default(.syncFrequency) var syncFrequency

    var body: some View {
        Stepper("Sync every \(syncFrequency) minutes", value: $syncFrequency, in: 15...1440, step: 15)
    }
}
```

## Swift-log

**GitHub**: [apple/swift-log](https://github.com/apple/swift-log)

Swift-log is Apple's official logging API for Swift, providing a unified logging system with support for various log levels and handlers.

### Implementation

- Core Implementation: `LogManager` in `Sources/Diagnostics/LogManager.swift`
- Categories: `LogCategory` in `Sources/Diagnostics/LogCategory.swift`
- File Logging: `FileLogger` in `Sources/Diagnostics/FileLogger.swift`
- Context: `DiagnosticContext` in `Sources/Diagnostics/DiagnosticContext.swift`

### Features

- **Structured Logging**: Supports structured, categorized logging
- **Multiple Log Levels**: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical`
- **Multiple Handlers**: Console and file logging
- **Context-Aware**: Supports passing context information
- **File Rotation**: Automatic log file rotation for file handler
- **Thread Safety**: Thread-safe logging operations

### Usage Examples

```swift
// Create a logger
private let logger = LogManager.shared.getLogger(category: .contacts)

// Log messages at different levels
logger.trace("Detailed trace information")
logger.debug("Debug information")
logger.info("General information")
logger.warning("Warning message")
logger.error("Error message")

// Log with metadata
logger.info("User authenticated", metadata: ["user_id": "\(userId)", "method": "oauth"])

// Log errors with context
do {
    try someRiskyOperation()
} catch {
    logger.error("Operation failed: \(error.localizedDescription)", metadata: ["error": "\(error)"])
}
```

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
    .target(name: "FriendshipAI", dependencies: ["NewDependency"])
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
