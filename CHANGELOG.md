# Changelog

All notable changes to CodeLooper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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