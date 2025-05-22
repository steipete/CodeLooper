# macOS Compatibility Information

## System Requirements

### Current Version Requirements

- **macOS Version**: macOS 14 (Sonoma) or later
- **Architecture**: Universal Binary (Apple Silicon and Intel)
- **Minimum Hardware**: Any Mac capable of running macOS 14
- **Free Disk Space**: 50MB
- **Memory**: 4GB RAM minimum (8GB recommended)

### Version Support Timeline

- **Current support**: macOS 14 (Sonoma) and later
- **Previous version**: v2.5 - Last version to support macOS 13 (Ventura)
- **Legacy versions**: v2.0 and earlier - Supported macOS 12 (Monterey)

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

- **Contacts Framework**: For accessing the user's contact book
- **AuthenticationServices**: For secure OAuth flows
- **KeychainServices**: For secure credential storage
- **LoginItems API**: For launch-at-login functionality
- **Notification Center**: For system notifications

## Known Compatibility Issues

### macOS 14.0 (Initial Sonoma Release)

- Contact access dialog may appear twice on some systems
- Menu bar icon can appear with incorrect color in dark mode

### macOS 15 Beta

- Currently testing compatibility with early developer previews
- Some UI adjustments may be needed for final release

## Accessibility Support

- VoiceOver compatible
- Supports dynamic type for text resizing
- Full keyboard navigation
- Respects system accent color preferences
- Compatible with Light/Dark mode switching
