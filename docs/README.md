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

The CodeLooper macOS app is a native menubar application that securely syncs your contacts with the CodeLooper service. It runs in the background, providing easy access to sync status and settings through a menu bar icon.

### Key Features

- **Contact Export & Sync**: Securely exports contacts from macOS Contacts app and syncs with CodeLooper
- **Menu Bar Integration**: Lightweight, unobtrusive menu bar app for status and control
- **Automatic Background Sync**: Configurable sync frequency with battery-aware operation
- **Secure Authentication**: OAuth-based secure authentication with Keychain integration
- **Privacy-Focused**: Clear permissions model and secure data handling

## Development Quick Start

1. Clone the repository
2. Run `pnpm install` from the project root to set up the project
3. Navigate to the `mac` directory
4. Run `./build.sh` to build the app

Key commands:

```bash
# Build the app
./build.sh

# Format and lint code
./lint.sh

# Run SwiftLint checks only
./run-swiftlint.sh

# Post binary information to a PR
./scripts/post-binary-info.sh --pr-number <PR_NUMBER>

# Set up git hooks (including pre-commit linting)
./setup-hooks.sh
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
