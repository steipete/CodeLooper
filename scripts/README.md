# CodeLooper Mac App Scripts

This directory contains scripts for building, linting, formatting, and managing the CodeLooper Mac application.

## Script Organization

Scripts are organized as follows:

- **Root directory scripts** (`/mac`): Core scripts and wrappers for essential functionality
- **Scripts directory** (`/mac/scripts`): Core implementations and specialized scripts
- **Utils** (`/mac/scripts/utils`): Utility scripts for special tasks
- **Fix** (`/mac/scripts/fix`): Scripts for fixing specific issues
- **Tools** (`/mac/scripts/tools`): Development and testing tools

## Core Scripts

### In Root Directory (Wrappers)

These scripts in the root directory provide a consistent interface but delegate to the implementations in the scripts directory:

- `build.sh` - Main build script for the application
- `build-and-notarize.sh` - Complete workflow to build, sign, and notarize the app for distribution
- `clean-and-regenerate.sh` - Clean build artifacts and regenerate Xcode project
- `lint.sh` - Code quality and formatting checks
- `run-swiftformat.sh` - Swift code formatting
- `run-swiftlint.sh` - Swift code linting
- `swift-check.sh` - Validation without making changes

### Implementation Scripts

- `scripts/build.sh` - Main build script implementation
- `scripts/clean-and-regenerate.sh` - Clean and regenerate implementation
- `scripts/swiftlint.sh` - SwiftLint implementation
- `scripts/swiftformat.sh` - SwiftFormat implementation
- `scripts/swift-check.sh` - Validation implementation
- `scripts/inject-keys.sh` - API key injection for builds

## Utility Scripts

- `scripts/utils/copy-symbol-icons.sh` - Copy symbol icons to the correct locations

## Fix Scripts

- `scripts/fix-spm-caching.sh` - Fix Swift Package Manager caching issues

## Tool Scripts

- `scripts/tools/setup-plugins.sh` - Set up development plugins
- `scripts/tools/test-settings.sh` - Test application settings

## CI Scripts

- `scripts/ci-swiftlint.sh` - CI-specific SwiftLint wrapper
- `scripts/ci-swiftformat.sh` - CI-specific SwiftFormat wrapper
- `scripts/create-lint-summary.sh` - Create lint summary for CI
- `scripts/ensure-lint-summary.sh` - Ensure lint summary exists for CI

## Development Scripts

- `scripts/open-xcode.sh` - Open project in Xcode
- `scripts/run-app.sh` - Build and run the app
- `scripts/test-version.sh` - Test version information

## Distribution Scripts

- `scripts/sign-and-notarize.sh` - Comprehensive script to sign the app with hardened runtime and submit to Apple's notarization service
- `/scripts/codesign.sh` - Project-wide script that handles code signing for both macOS and Electron apps using zsign

## Script Execution

All scripts should have executable permissions. If not, you can set them with:

```bash
chmod +x scripts/**/*.sh
```

## Best Practices

1. **Use wrappers in the root directory** for core functionality that delegates to the implementation in the scripts directory
2. **Add proper error handling** to all scripts
3. **Include descriptive comments** at the top of each script
4. **Use consistent parameter handling** across scripts
5. **Keep implementation details** in the scripts directory
