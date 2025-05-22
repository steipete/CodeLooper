# Building the CodeLooper macOS App

This document provides comprehensive instructions for building the CodeLooper macOS application.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Building Methods](#building-methods)
  - [Building via pnpm (Recommended)](#building-via-pnpm-recommended)
  - [Manual Building (Advanced)](#manual-building-advanced)
- [Build Script Options](#build-script-options)
- [How the Build System Works](#how-the-build-system-works)
- [Authentication Flow](#authentication-flow)
- [Versioning](#versioning)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later
- Swift Package Manager (included with Xcode)

## Building Methods

### Building via Scripts (Recommended)

The recommended way to build the macOS app is using the provided build scripts.

#### Build Commands

From the repository root:

```bash
# Standard build using the run script
./scripts/run-app.sh

# Or build directly
./scripts/generate-xcproj.sh
# Then open CodeLooper.xcodeproj and build
```

### Manual Building (Advanced)

If you need more control over the build process, you can build the macOS app directly.

#### Step 1: Clone the Repository

```bash
git clone https://github.com/steipete/CodeLooper.git
cd CodeLooper
```

#### Step 2: Generate Xcode Project

```bash
./scripts/generate-xcproj.sh
```

#### Step 3: Build the App

```bash
# Option 1: Use the run script
./scripts/run-app.sh

# Option 2: Open in Xcode and build
open CodeLooper.xcodeproj
```

## Build Script Options

The project provides several build and development scripts:

### Available Scripts

- `./scripts/run-app.sh`: Build and run the app
- `./scripts/generate-xcproj.sh`: Generate Xcode project from Package.swift
- `./scripts/open-xcode.sh`: Open the project in Xcode
- `./lint.sh`: Run code linting and formatting
- `./run-swiftlint.sh`: Run SwiftLint checks
- `./run-swiftformat.sh`: Format code with SwiftFormat

### Build Modes

1. **Development Build** (recommended for development):

   ```bash
   ./scripts/run-app.sh
   ```

2. **Xcode Build** (for debugging and development):

   ```bash
   ./scripts/generate-xcproj.sh
   open CodeLooper.xcodeproj
   ```

## How the Build System Works

The build process follows these steps:

1. **Project Generation**: The `generate-xcproj.sh` script creates an Xcode project from the Swift Package Manager manifest (`Package.swift`)
2. **Build Process**:
   - Uses Swift Package Manager for dependency resolution
   - Builds the app using Xcode or swift build
   - Creates an application bundle
3. **CI/CD Integration**:
   - GitHub Actions automatically builds on PR and main branch commits
   - Binary information is collected and posted to PRs
   - Notarization and code signing for distribution builds

### Script Behavior

- The script automatically uses the latest Swift features and compatibility flags
- Preserves build artifacts for faster incremental builds by default
- Only performs full cleanup when `--clean` is explicitly requested
- Uses complete concurrency checking for strict Swift concurrency safety
- Includes multiple fallback strategies to recover from build failures
- Creates the final application bundle in `binary/CodeLooper.app`
- Targets macOS 14.0 with the latest development tools

## Accessibility Permissions

CodeLooper requires accessibility permissions to interact with Cursor's UI elements:

1. On first launch, the app will prompt for accessibility permissions
2. The user will be directed to System Settings > Privacy & Security > Accessibility
3. Add CodeLooper to the list of allowed applications
4. The app uses the AXorcist library for reliable UI element detection and interaction

## Versioning

The CodeLooper macOS app follows a `YY.MM.PATCH` versioning scheme:

- `YY`: Two-digit year (e.g., 24 for 2024)
- `MM`: Month (1-12)
- `PATCH`: Incremental patch number starting at 0

For example:

- `24.5.0` = May 2024, initial release
- `24.5.1` = May 2024, first patch
- `24.6.0` = June 2024, initial release

This version number is stored in the app's Info.plist as `CFBundleShortVersionString` and is dynamically read at runtime.

## PR Comments with Binary Information

When a Mac build is completed in CI, the system automatically posts a comment to the associated PR with detailed information about the binary:

- Binary size (both raw bytes and human-readable format)
- App bundle size
- Compilation date and time
- Architecture information
- MD5 checksum for verification
- Download link to the binary in CI artifacts

This feature helps reviewers quickly assess the impact of changes on the binary size and provides easy access to the compiled app for testing.

### Manual Comment Generation

You can also manually generate a PR comment with binary information by running:

```bash
# From the repository root
./mac/scripts/post-binary-info.sh

# Or with specific PR number
PR_NUMBER=123 ./mac/scripts/post-binary-info.sh
```

This is useful for local testing or when you want to share binary information outside of the normal CI flow.

## Troubleshooting

### Build Fails with Missing Dependencies

Ensure you have the required dependencies by running:

```bash
./scripts/generate-xcproj.sh
```

### Accessibility Permission Issues

1. Verify CodeLooper has accessibility permissions in System Settings
2. Restart the app after granting permissions
3. Check that Cursor is running and accessible

### Swift Build Errors

If you encounter Swift build errors:

```bash
# Try regenerating the Xcode project
./scripts/generate-xcproj.sh

# Or clean Swift Package Manager cache
rm -rf .build Package.resolved
swift package reset
```

For more information on CI/CD systems, see [CI.md](CI.md).
