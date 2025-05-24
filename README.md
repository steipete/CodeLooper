# CodeLooper 🔄

<p align="center">
  <img src="assets/banner.png" alt="CodeLooper Banner">
</p>

**A macOS menubar app that keeps your Cursor IDE in the loop** 🔄

CodeLooper is a native macOS application that sits in your menubar, constantly looping through checks on Cursor IDE's behavior. When Cursor breaks out of its productive loop – getting stuck generating code, dropping connections, or hitting errors – CodeLooper loops back in to restore the flow using macOS accessibility APIs:

- **🔄 Loop-breaking detection**: Spots when code generation gets stuck in an endless loop
- **🔄 Connection loop restoration**: Automatically resumes dropped connections to keep the loop alive  
- **🔄 Error loop interruption**: Dismisses dialogs that break your development loop
- **🔄 Process loop recovery**: Restarts stuck processes to get back in the loop
- **🔄 UI loop monitoring**: Continuously loops through accessibility element checks

The app runs its own monitoring loop in the background, ready to jump in whenever Cursor falls out of its productive loop – keeping you looped in and flowing smoothly.

## Key Features 🌟

- **🔄 Loop Intelligence**: Smart detection when Cursor breaks out of its productive development loop
- **⚡ Loop Recovery**: Instantly jumps back into action to restore broken workflows  
- **🎯 Loop Precision**: Only intervenes when the loop is genuinely broken, staying in the background otherwise
- **📊 Loop Status**: Shows your current loop health and recent loop-fixing actions in the menubar
- **🔧 Multi-Loop Support**: Handles various loop breaks - generation loops, connection loops, error loops
- **👁️ Loop Watching**: Continuously monitors the loop state using accessibility APIs

## Core Features

- **Menu Bar Integration**: Quick access to loop status and controls
- **Accessibility Automation**: Remote control Cursor IDE through system APIs  
- **Smart Monitoring**: Detects when Cursor needs assistance
- **Launch at Login**: Starts automatically to maintain continuous supervision
- **Settings Management**: Fine-tune your supervision preferences
- **Native macOS**: Built specifically for Mac with system-level integration

## System Requirements

- **macOS Version**: macOS 14 (Sonoma) or later
- **Architecture**: Universal Binary (Apple Silicon and Intel)
- **Accessibility**: Requires accessibility permissions for IDE automation

## Technology Stack

- **Swift 5.10**: Modern language features and concurrency
- **SwiftUI 5.0**: Modern declarative UI where appropriate
- **AppKit**: For system integration and certain UI components
- **Accessibility APIs**: For remote control and automation
- **Swift Concurrency**: async/await for background monitoring
- **Swift Observation**: Observable macro for state management

### Core System Integration

- **Accessibility Framework**: For automated IDE interaction
- **LoginItems API**: For launch-at-login functionality
- **Notification Center**: For system notifications
- **Menu Bar Integration**: Native macOS menu bar support

## Key Dependencies

- **[Defaults](https://github.com/sindresorhus/Defaults)** - Type-safe user defaults access
- **[LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin)** - Reliable startup at login functionality
- **[SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect)** - SwiftUI introspection capabilities
- **[Swift-log](https://github.com/apple/swift-log)** - Unified logging API

## Development

This app is written in Swift using SwiftUI and AppKit. It targets macOS 14+ (Sonoma) and uses modern Swift concurrency features for seamless background operation.

### Getting Started

1. Clone the repository
2. Run the build script to build the app
3. Grant accessibility permissions when prompted
4. Watch CodeLooper keep your Cursor IDE in the loop!

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