# CodeLooper macOS Documentation

This directory contains comprehensive documentation for the CodeLooper macOS application.

## Documentation Index

### Core Documentation

- [Build Guide](BUILD.md) - How to build and run the app
- [Dependencies](DEPENDENCIES.md) - External libraries and their usage
- [Compatibility](COMPATIBILITY.md) - System requirements and compatibility information
- [CI/CD](CI.md) - Continuous Integration information
- [Notarization](NOTARIZATION.md) - App notarization with Apple

### Technical Implementation

- [Analyzer](ANALYZER.md) - Code quality enforcement and static analysis
- [SwiftLint](SWIFTLINT.md) - Code style standardization
- [SPM Caching](SPM-CACHING.md) - Swift Package Manager caching improvements
- [Menu Best Practices](MENU-BEST-PRACTICES.md) - Menu implementation guidelines
- [SwiftUI App Conversion](SWIFTUI-APP-CONVERSION.md) - SwiftUI lifecycle adoption
- [Scripts Documentation](SCRIPTS/README.md) - Build, lint, and utility scripts

## About CodeLooper macOS App

The CodeLooper macOS app is a native menu bar application that supervises Cursor AI editor instances, automatically resolving common interruptions and stuck states. It also assists with configuring Model Context Protocol (MCP) servers for enhanced AI development workflows.

### Key Features

- **Cursor Supervision**: Automatically detects and resolves "Connection Issues," "Cursor Stops," and "Force-Stopped" states
- **Menu Bar Integration**: Lightweight, unobtrusive menu bar app with status-indicating icons
- **MCP Server Management**: Easy setup and configuration of Claude Code, macOS Automator, and XcodeBuild MCP servers
- **Accessibility Integration**: Uses AXorcist library for reliable UI element detection and interaction
- **Privacy-Focused**: Local operation with clear permissions model and secure data handling

## Development Quick Start

1. Clone the repository
2. Open the Xcode project or workspace
3. Build and run the app

Key commands:

```bash
# Build the app
./scripts/run-app.sh

# Format and lint code
./lint.sh

# Run SwiftLint checks only
./run-swiftlint.sh

# Generate Xcode project
./scripts/generate-xcproj.sh

# Post binary information to a PR
./scripts/post-binary-info.sh --pr-number <PR_NUMBER>
```

## CI Features

- **Automated builds** on PRs and main branch commits
- **PR comments with artifact links** for easy testing of builds
- **Build status updates** directly in PR comments (success/failure)
- **Notarization status reporting** for production builds

For full CI/CD details, see [CI.md](CI.md).

## Logging and Diagnostics

The app uses Apple's swift-log framework for structured logging with multiple log levels. Logs are written to both console and rotating log files in the application support directory for troubleshooting.

## License

Copyright © CodeLooper, Inc. All rights reserved.
