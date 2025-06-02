# Changelog

All notable changes to CodeLooper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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