# Changelog

All notable changes to CodeLooper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-06-10

### 🎨 Major UI Overhaul - Native Menu Bar Implementation

This release represents a complete reimplementation of the menu bar interface, transitioning from SwiftUI's MenuBarExtra to a native AppKit implementation for superior control and visual refinement.

### Added

#### Menu Bar & Status Display
- **Custom Status Bar Implementation**: Created `StatusBarController` as a singleton managing NSStatusItem directly
- **Visual Status Indicators**: New `StatusIndicators` and `StatusBadge` SwiftUI components showing:
  - 🟢 Green play icons with counts for running/generating instances
  - 🔴 Red stop icons with counts for stopped/errored instances
  - Gray idle indicator when no instances are active
- **Dynamic Icon Rendering**: Uses ImageRenderer to convert SwiftUI views to NSImage for menu bar display
- **Adaptive Tinting**: Menu bar icon adapts to effective appearance (light/dark backgrounds)

#### Native Popover Window
- **Custom Menu Window**: Implemented `CustomMenuWindow` using NSPanel for precise control
- **Visual Effects**: NSVisualEffectView with `.popover` material for authentic macOS appearance
- **Rounded Corners**: Proper 10pt corner radius with masksToBounds for clean edges
- **Native Borders**: Uses NSColor.separatorColor for adaptive border styling
- **Click-Outside Dismissal**: Event monitoring for proper popover behavior
- **Highlight State**: NSStatusBarButton shows pressed state when popover is active

#### UI Components
- **DSIconButton**: New design system component for icon-only buttons
- **WindowScreenshotPopover**: Functional screenshot viewer for debugging window states
- **Refined Color Palette**: Toned down status badge colors for professional appearance:
  - Green: RGB(0.3, 0.65, 0.3) - more subtle than before
  - Red: RGB(0.7, 0.35, 0.35) - less harsh on the eyes

### Changed

#### Architecture Improvements
- **Removed MenuBarExtra**: Eliminated SwiftUI's MenuBarExtra in favor of direct NSStatusItem control
- **Singleton Pattern**: StatusBarController manages all menu bar interactions as a centralized singleton
- **State Preservation**: Menu bar highlight state properly maintained during icon updates
- **Async Dispatch**: Used DispatchQueue for proper timing of UI updates

#### Settings Window
- **Single Implementation**: Removed duplicate settings window implementations
- **NativeToolbarSettingsWindow**: Kept only the native toolbar-based settings window
- **WindowGroup Removal**: Eliminated SwiftUI WindowGroup for settings in CodeLooperApp

### Fixed

#### Visual Issues
- **Rounded Corners**: Fixed missing rounded corners on popover window
- **Highlight State**: Menu bar button now properly shows highlighted background when active
- **Color Intensity**: Reduced overly bright colors in status badges
- **Popover Positioning**: Window appears correctly below menu bar item, not in screen center

#### Technical Issues
- **Settings Duplication**: Resolved issue where two settings windows would appear
- **Build Errors**: Fixed "ambiguous use of logger" and other Swift 6 compilation issues
- **Thread Safety**: All UI updates now properly dispatched to main thread
- **Memory Management**: Proper cleanup of event monitors and observers

### Technical Details

#### Implementation Architecture
- **StatusBarController.swift**: Main controller managing NSStatusItem lifecycle
- **CustomMenuWindow.swift**: NSPanel subclass with visual effects and event handling
- **StatusIndicators.swift**: Reusable SwiftUI components for status display
- **MenuBarStatusView.swift**: Container view for menu bar content composition

#### Key Technologies
- NSStatusItem & NSStatusBarButton for menu bar integration
- NSVisualEffectView for native macOS materials
- ImageRenderer for SwiftUI → NSImage conversion
- NSPanel with borderless style mask for custom windows
- Event monitors for click-outside detection
- Effective appearance detection for adaptive UI

### Developer Experience

#### Code Quality
- Removed unnecessary comments explaining temporary code
- Consistent use of design system components
- Proper Swift 6 concurrency patterns throughout
- Clear separation of concerns between UI layers

#### Debugging Support
- Screenshot popover for visual debugging
- Comprehensive logging for status bar operations
- State tracking for menu visibility
- Clear error messages for common issues

## [1.0.0] - 2025-06-02

### 🎉 First Production Release

This is the first stable production release of CodeLooper with full notarization and auto-update support.

### Added
- ✅ **Complete Sparkle Integration**: Fully working auto-update system from v0.9.0 → v1.0.0
- 🔒 **Full App Notarization**: Complete hardened runtime with deep signing of all components
- 🏗️ **Production Build Pipeline**: Automated build, sign, and release workflow
- 📦 **Professional DMG Distribution**: Clean installer with no security warnings
- 🔄 **Seamless Updates**: One-click update installation via Sparkle framework

### Enhanced
- 🚀 **Cursor Monitoring**: Robust AI-assisted coding session supervision
- 🤖 **AI-Powered Diagnostics**: Intelligent intervention and error recovery
- ⚙️ **Advanced Settings**: Comprehensive configuration and preferences
- 📊 **Session Analytics**: Detailed monitoring and reporting capabilities

### Technical
- Swift 6 strict concurrency throughout entire codebase
- Complete XPC services signing for Sparkle framework
- Hardened runtime with proper entitlements configuration
- Professional code signing with Developer ID certificates

### Security
- Apple notarization with zero Gatekeeper warnings
- Cryptographic EdDSA signing for all updates
- Secure update delivery via HTTPS
- Tamper-proof update verification

---

## [0.9.0] - 2025-06-02

### 🧪 Testing Release

Beta release for testing Sparkle auto-update functionality and notarization workflow.

### Added
- 🔬 **Update Testing**: Release specifically for testing v0.9.0 → v1.0.0 updates
- 🔐 **Notarization Validation**: Confirms complete notarization pipeline works
- 📋 **Release Notes Testing**: Validates Sparkle UI and release note display

### Fixed
- ✅ Resolved all notarization errors and Gatekeeper warnings
- ✅ Complete signing of Sparkle framework components
- ✅ Proper hardened runtime configuration

---

## [2025.5.29] - 2025-05-29

### Added
- 🚀 **GitHub Releases Integration**: Complete setup for automated releases via GitHub
- 🔄 **Sparkle Auto-Updates**: Integrated Sparkle framework for automatic app updates
- 📦 **Release Automation**: Added scripts for building, signing, and publishing releases
- 🔐 **EdDSA Signing**: Secure update verification with cryptographic signatures
- 📡 **Appcast Generation**: Automated appcast.xml generation for update feeds
- 🎨 **Modern Updates UI**: Redesigned settings with Obsidian-inspired update interface
- 📋 **Changelog**: Added this changelog to track all releases

### Enhanced
- 🔧 **Build System**: Improved Tuist configuration with proper Swift 6 support
- 📝 **Documentation**: Enhanced setup guides and architectural documentation
- 🛠️ **Development Workflow**: Streamlined build and release processes

### Technical
- Swift 6 strict concurrency compliance throughout the project
- Sparkle 2.0+ integration with modern security features
- GitHub Actions ready for CI/CD (scripts prepared)
- Automated DMG creation and notarization support

### Security
- EdDSA cryptographic signing for all updates
- Secure key management with gitignore protection
- Hardened Runtime enabled for App Store distribution readiness

---

## [Previous Versions]

### [2025.5.2] - 2025-05-02
- Initial development versions
- Core monitoring and intervention features
- Basic UI and accessibility integration

---

## Release Notes Template

For future releases, include:

### Added
- New features and capabilities

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future versions

### Removed
- Features that have been removed

### Fixed
- Bug fixes and corrections

### Security
- Security improvements and vulnerability fixes

---

## Contributing

When contributing to CodeLooper:

1. Update this changelog with your changes
2. Follow the existing format and categorization
3. Include relevant issue/PR numbers where applicable
4. Ensure version numbers follow semantic versioning

## Links

- [GitHub Releases](https://github.com/steipete/CodeLooper/releases)
- [Issues](https://github.com/steipete/CodeLooper/issues)
- [Contributing Guidelines](CONTRIBUTING.md)