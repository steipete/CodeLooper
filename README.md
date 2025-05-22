# CodeLooper 🔄

<p align="center">
  <img src="assets/banner.png" alt="CodeLooper Banner">
</p>

**The ultimate Cursor IDE Aufpasser** – A native macOS menubar app that keeps your Cursor IDE in the loop, baby! 🚀

CodeLooper runs quietly in the background, watching over Cursor IDE like a digital guardian angel. When Cursor gets lazy, stuck, or needs a gentle nudge, CodeLooper springs into action using macOS accessibility APIs to press buttons, type commands, and keep your development workflow flowing smoothly.

*It's all about the loop* – CodeLooper ensures your coding never stops, your AI never sleeps, and your productivity stays in perpetual motion.

## What Makes CodeLooper Special? 🌟

- **🔄 Loop Master**: Keeps Cursor IDE running smoothly in an endless productive loop
- **👁️ Aufpasser Mode**: German for "watchdog" – CodeLooper supervises your IDE like a loyal companion  
- **🤖 Smart Intervention**: Uses accessibility APIs to automatically unstick frozen processes
- **⚡ Background Guardian**: Runs silently, intervening only when needed
- **🎯 Spec-Driven**: Helps implement whatever you want when you have a specification
- **🔧 Auto-Nudging**: Gently pokes Cursor when it gets sluggish or unresponsive

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
- **Disk Space**: 50MB
- **Memory**: 4GB RAM minimum (8GB recommended)
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