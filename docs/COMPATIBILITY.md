# macOS Compatibility Information

## System Requirements

### Current Version Requirements

- **macOS Version**: macOS 15 (Sequoia) or later
- **Architecture**: Universal Binary (Apple Silicon and Intel)
- **Minimum Hardware**: Any Mac capable of running macOS 15
- **Free Disk Space**: 50MB
- **Memory**: 4GB RAM minimum (8GB recommended)

### Version Support Timeline

- **Current support**: macOS 15 (Sequoia) and later
- **Previous version**: Targeting macOS 15 for initial release
- **Future versions**: Will maintain compatibility with supported macOS versions

## Technology Stack

The CodeLooper macOS application utilizes modern Apple technologies:

### UI Frameworks

- **SwiftUI 5.0**: Modern declarative UI framework
- **AppKit**: Used for system integration and certain UI components
- **SF Symbols 5**: For consistent iconography

### Swift Features

- **Swift 5.10**: Modern language features
- **Swift Concurrency**: async/await for background operations
- **Swift Observation**: Observable macro for state management
- **SwiftData**: For local data persistence (where applicable)

### System Integration

- **Accessibility APIs**: For interacting with Cursor's UI elements
- **AXorcist Library**: For reliable UI element detection and interaction
- **NSRunningApplication**: For monitoring Cursor processes
- **LoginItems API**: For launch-at-login functionality
- **Notification Center**: For system notifications
- **Sparkle Framework**: For automatic updates

## Known Compatibility Issues

### macOS 15.0 (Initial Sequoia Release)

- Accessibility permission dialog may need to be granted multiple times
- Menu bar icon animations may be affected by system performance settings

### Future macOS Versions

- Will maintain compatibility testing with beta releases
- UI adjustments may be needed for major system updates

## Accessibility Support

- Requires Accessibility permissions to function (for Cursor supervision)
- VoiceOver compatible UI elements
- Supports dynamic type for text resizing
- Full keyboard navigation
- Respects system accent color preferences
- Compatible with Light/Dark mode switching
- Privacy-focused with minimal system access requirements
