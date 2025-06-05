# CodeLooper Release Management Guide

This document provides comprehensive guidance for managing CodeLooper releases, including the advanced beta/pre-release system adapted from VibeMeter's release process.

## Table of Contents

1. [Release System Overview](#release-system-overview)
2. [Quick Start](#quick-start)
3. [Release Types](#release-types)
4. [Version Management](#version-management)
5. [Release Process](#release-process)
6. [Dual-Channel Update System](#dual-channel-update-system)
7. [Scripts Reference](#scripts-reference)
8. [Verification](#verification)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Topics](#advanced-topics)

## Release System Overview

CodeLooper uses a sophisticated dual-channel release system that supports:

- **Stable releases**: Production-ready builds for general users
- **Pre-release builds**: Beta, alpha, and RC builds for testing
- **Automated version bumping**: Semantic versioning with pre-release support
- **Dual appcast feeds**: Separate update channels for stable and pre-release users
- **Build validation**: Comprehensive pre-flight and verification checks
- **GitHub integration**: Automated release creation and asset management

### Key Features

- ✅ **IS_PRERELEASE_BUILD system**: Build-time flag determines update channel behavior
- ✅ **Automatic channel detection**: Apps automatically default to appropriate update channel
- ✅ **User override capability**: Users can manually switch between stable/pre-release channels
- ✅ **Comprehensive validation**: Multi-layer verification ensures release quality
- ✅ **GitHub automation**: Complete CI/CD-ready release pipeline

## Quick Start

### Create a Stable Release

```bash
# 1. Bump version
./scripts/version.sh --patch

# 2. Create stable release
./scripts/release.sh stable
```

### Create a Beta Release

```bash
# 1. Create beta version
./scripts/version.sh --prerelease beta

# 2. Create beta release
./scripts/release.sh beta 1
```

### Verify Your Setup

```bash
# Run comprehensive system verification
./scripts/verify-prerelease-system.sh
```

## Release Types

### Stable Releases

- **Purpose**: Production-ready builds for general users
- **Update Channel**: Stable appcast only (`appcast.xml`)
- **IS_PRERELEASE_BUILD**: `NO`
- **Example**: `2.1.0`

```bash
./scripts/release.sh stable
```

### Beta Releases

- **Purpose**: Feature-complete builds for testing
- **Update Channel**: Pre-release appcast (`appcast-prerelease.xml`)
- **IS_PRERELEASE_BUILD**: `YES`
- **Example**: `2.1.0-beta.1`

```bash
./scripts/release.sh beta 1
./scripts/release.sh beta 2
```

### Alpha Releases

- **Purpose**: Early development builds with new features
- **Update Channel**: Pre-release appcast (`appcast-prerelease.xml`)
- **IS_PRERELEASE_BUILD**: `YES`
- **Example**: `2.1.0-alpha.1`

```bash
./scripts/release.sh alpha 1
./scripts/release.sh alpha 2
```

### Release Candidates (RC)

- **Purpose**: Final testing before stable release
- **Update Channel**: Pre-release appcast (`appcast-prerelease.xml`)
- **IS_PRERELEASE_BUILD**: `YES`
- **Example**: `2.1.0-rc.1`

```bash
./scripts/release.sh rc 1
./scripts/release.sh rc 2
```

## Version Management

### Semantic Versioning

CodeLooper follows semantic versioning (`MAJOR.MINOR.PATCH`):

- **MAJOR**: Breaking changes or significant feature additions
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Bumping

```bash
# Automatic semantic version bumping
./scripts/version.sh --major    # 1.2.3 → 2.0.0
./scripts/version.sh --minor    # 1.2.3 → 1.3.0
./scripts/version.sh --patch    # 1.2.3 → 1.2.4

# Pre-release versions
./scripts/version.sh --prerelease beta   # 1.2.3 → 1.2.3-beta.1
./scripts/version.sh --prerelease alpha  # 1.2.3 → 1.2.3-alpha.1
./scripts/version.sh --prerelease rc     # 1.2.3 → 1.2.3-rc.1

# Build number only
./scripts/version.sh --build     # Increment build number only

# Set specific version
./scripts/version.sh --set "2.0.0"

# Show current version
./scripts/version.sh --current
```

## Release Process

### 7-Step Release Pipeline

The release process follows these automated steps:

1. **Pre-flight Check** (`preflight-check.sh`)
   - Git repository validation
   - Required tools verification
   - Code signing certificates
   - Build number uniqueness

2. **Project Generation** (`generate-xcproj.sh`)
   - Tuist project regeneration
   - Automatic commit of changes

3. **Application Building**
   - Clean build with appropriate flags
   - `IS_PRERELEASE_BUILD` environment variable

4. **Code Signing & Notarization**
   - Developer ID signing
   - Apple notarization process

5. **DMG Creation**
   - Distribution package creation
   - Asset signing

6. **GitHub Release**
   - Release creation with proper metadata
   - Asset upload and tagging

7. **Appcast Update**
   - Dual-channel feed generation
   - EdDSA signature creation

### Example Release Workflow

```bash
# 1. Create new beta version
./scripts/version.sh --prerelease beta
# Output: Updated to 2.1.0-beta.1 (build 45)

# 2. Commit version change
git add Project.swift
git commit -m "Bump version to 2.1.0-beta.1 (45)"

# 3. Create beta release
./scripts/release.sh beta 1
# Output: Complete release pipeline execution

# 4. Verify release
./scripts/verify-app.sh path/to/CodeLooper.app
./scripts/verify-appcast.sh
```

## Dual-Channel Update System

### Channel Architecture

```
┌─────────────────┐    ┌──────────────────────┐
│   Stable Users  │────▶│    appcast.xml       │
│                 │    │  (stable only)       │
└─────────────────┘    └──────────────────────┘

┌─────────────────┐    ┌──────────────────────┐
│ Pre-release     │────▶│ appcast-prerelease   │
│ Users           │    │ .xml (all releases)  │
└─────────────────┘    └──────────────────────┘
```

### Automatic Channel Detection

The `UpdateChannel.swift` system automatically detects the appropriate channel:

1. **Build-time flag check**: `IS_PRERELEASE_BUILD` in Info.plist
2. **Version string analysis**: Keywords like "beta", "alpha", "rc"
3. **Default fallback**: Stable channel for production builds

### User Override

Users can manually switch update channels in the app settings, allowing:
- Beta users to switch back to stable releases
- Stable users to opt into pre-release updates

## Scripts Reference

### Core Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `release.sh` | Main release automation | `./scripts/release.sh <type> [number]` |
| `version.sh` | Version management | `./scripts/version.sh [options]` |
| `preflight-check.sh` | Pre-release validation | `./scripts/preflight-check.sh` |
| `generate-appcast.sh` | Dual appcast generation | `./scripts/generate-appcast.sh` |

### Verification Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `verify-app.sh` | App bundle verification | `./scripts/verify-app.sh <app-path>` |
| `verify-appcast.sh` | Appcast validation | `./scripts/verify-appcast.sh` |
| `verify-prerelease-system.sh` | End-to-end system check | `./scripts/verify-prerelease-system.sh` |

### Legacy Scripts

| Script | Purpose | Status |
|--------|---------|---------|
| `update-appcast.sh` | Simple appcast update | ⚠️ Legacy - use `generate-appcast.sh` |
| `release-local.sh` | Local release testing | ⚠️ Legacy - use `release.sh` |

## Verification

### Pre-Release Verification

Before any release, run the comprehensive verification:

```bash
# System verification
./scripts/verify-prerelease-system.sh

# Pre-flight checks
./scripts/preflight-check.sh

# App verification (after build)
./scripts/verify-app.sh build/CodeLooper.app

# Appcast verification
./scripts/verify-appcast.sh
```

### Verification Checklist

- [ ] All verification scripts pass
- [ ] Build numbers are unique
- [ ] Code signing certificates valid
- [ ] Appcast files are valid XML
- [ ] Download URLs are accessible
- [ ] Pre-release flag correctly set
- [ ] GitHub releases created properly

## Troubleshooting

### Common Issues

#### Build Number Conflicts

```bash
# Error: Build number already exists
# Solution: Increment build number manually
./scripts/version.sh --build
```

#### Code Signing Issues

```bash
# Error: Code signing failed
# Check certificates
security find-identity -v -p codesigning

# Set environment variables for notarization
export APPLE_ID="your-apple-id@example.com"
export APPLE_PASSWORD="app-specific-password"
```

#### Appcast Generation Failures

```bash
# Error: Cannot generate signatures
# Install Sparkle tools
brew install sparkle

# Set private key path
export SPARKLE_PRIVATE_KEY_PATH="$HOME/.sparkle_private_key"
```

#### GitHub API Issues

```bash
# Error: GitHub API authentication failed
# Login to GitHub CLI
gh auth login

# Verify authentication
gh auth status
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable verbose output
export DEBUG=1

# Run with debug information
./scripts/release.sh beta 1
```

## Advanced Topics

### Custom Build Configurations

Override default settings with environment variables:

```bash
# Custom GitHub repository
export GITHUB_REPO="custom-repo"
export GITHUB_USERNAME="custom-user"

# Custom signing configuration
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export CODE_SIGN_IDENTITY="Apple Distribution"

# Custom Sparkle configuration
export SPARKLE_PRIVATE_KEY_PATH="/path/to/private/key"
export KEYCHAIN_KEY_NAME="Custom-Sparkle-Key"
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      release_type:
        description: 'Release type'
        required: true
        type: choice
        options: ['stable', 'beta', 'alpha', 'rc']
      release_number:
        description: 'Release number (for pre-releases)'
        required: false

jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup environment
        run: |
          echo "APPLE_ID=${{ secrets.APPLE_ID }}" >> $GITHUB_ENV
          echo "APPLE_PASSWORD=${{ secrets.APPLE_PASSWORD }}" >> $GITHUB_ENV
          
      - name: Run release
        run: |
          ./scripts/release.sh ${{ inputs.release_type }} ${{ inputs.release_number }}
```

### Custom Appcast Hosting

While GitHub serves the default appcast files, you can host them elsewhere:

1. Update `UpdateChannel.swift` appcast URLs
2. Configure your hosting service
3. Update `generate-appcast.sh` upload destination

### Migration from Single-Channel

If migrating from a single-channel system:

1. Run the verification system: `./scripts/verify-prerelease-system.sh`
2. Generate initial dual appcasts: `./scripts/generate-appcast.sh`
3. Update app to use `UpdateChannel.swift`
4. Test both channels thoroughly

---

## Support

For questions or issues with the release system:

1. Check the verification scripts output
2. Review the troubleshooting section
3. Consult the individual script documentation
4. File an issue on the GitHub repository

---

*This release system was adapted from VibeMeter's advanced release management process and customized for CodeLooper's specific needs.*