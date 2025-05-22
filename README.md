# CodeLooper

<p align="center">
  <img src="assets/banner.png" alt="CodeLooper Banner">
</p>

A native macOS menubar application for managing and upgrading Cursor IDE installations and related development tools.

## Features

- Menu bar app for easy access and status
- Settings and preferences management
- Launch at login functionality
- Automatic tool management capabilities
- Native macOS integration
- CI/CD pipeline with GitHub Actions

## System Requirements

- **macOS Version**: macOS 14 (Sonoma) or later
- **Architecture**: Universal Binary (Apple Silicon and Intel)
- **Disk Space**: 50MB
- **Memory**: 4GB RAM minimum (8GB recommended)

## Technology Stack

- **Swift 5.10**: Modern language features and concurrency
- **SwiftUI 5.0**: Modern declarative UI where appropriate
- **AppKit**: For system integration and certain UI components
- **Swift Concurrency**: async/await for background operations
- **Swift Observation**: Observable macro for state management

### Core System Integration

- **LoginItems API**: For launch-at-login functionality
- **Notification Center**: For system notifications
- **Menu Bar Integration**: Native macOS menu bar support

## Key Dependencies

- **[Defaults](https://github.com/sindresorhus/Defaults)** - Type-safe user defaults access
- **[LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin)** - Reliable startup at login functionality
- **[SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect)** - SwiftUI introspection capabilities
- **[Swift-log](https://github.com/apple/swift-log)** - Unified logging API

## Development

This app is written in Swift using SwiftUI and AppKit. It targets macOS 14+ (Sonoma) and uses modern Swift concurrency features.

### Getting Started

1. Clone the repository
2. Run the build script to build the app
3. Use the provided scripts for development workflow

### Key Commands

```bash
# Build the app
./build.sh

# Format code and fix Swift code style issues
./lint.sh

# Format Swift code only
./run-swiftformat.sh --format

# Validate Swift code without making changes
./scripts/swift-check.sh
```

## Documentation

For detailed documentation, see:

- [Overview](docs/README.md) - Overview of the macOS app
- [Building Guide](docs/BUILD.md) - How to build the app
- [Dependencies](docs/DEPENDENCIES.md) - External libraries and dependencies
- [CI/CD Systems](docs/CI.md) - Continuous integration and delivery
- [Compatibility](docs/COMPATIBILITY.md) - System requirements and compatibility
- [SwiftLint](docs/SWIFTLINT.md) - Code quality enforcement
- [Menu Best Practices](docs/MENU-BEST-PRACTICES.md) - Menu implementation guidelines
- [Notarization](docs/NOTARIZATION.md) - App notarization process and automation

## License

Copyright © Peter Steinberger. All rights reserved.