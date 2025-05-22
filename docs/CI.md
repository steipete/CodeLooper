# Continuous Integration for CodeLooper macOS App

This document covers the CI/CD systems and processes used for building, testing, and distributing the CodeLooper macOS application.

## Table of Contents

- [CI System Overview](#ci-system-overview)
- [GitHub Actions CI](#github-actions-ci)
- [PR Comments and Artifact Links](#pr-comments-and-artifact-links)
- [Build Caching](#build-caching)
- [SwiftLint Integration](#swiftlint-integration)
- [CI Scripts](#ci-scripts)
- [Troubleshooting](#troubleshooting)

## CI System Overview

We use GitHub Actions for building and validating the macOS app:

**GitHub Actions** - Used for PR validation, code quality checks, development feedback, and production builds

GitHub Actions provides integrated CI within the GitHub ecosystem, with direct PR integration and feedback mechanisms.

## GitHub Actions CI

### Workflow Configuration

The main configuration is defined in `.github/workflows/mac-build-notarize.yml`

### Workflow Trigger

The workflow runs on:

- Push to `main`, `mac-*`, `feature/*`, and `fix/*` branches (when files in `mac/` are changed)
- Pull requests to `main` (when files in `mac/` are changed)
- Manual triggering via GitHub UI (workflow_dispatch)

### Environment Setup

The workflow sets up both Swift and JavaScript environments:

1. **Swift Environment**

   - Uses Swift 6.1 via swift-actions/setup-swift@v2
   - Sets strict concurrency checking to complete
   - Ensures Xcode 16.3 compatibility

2. **JavaScript Environment**
   - Uses Node.js 22.x
   - Uses pnpm 10.10.0 for package management
   - Installs project dependencies with pnpm install

### Build Process

The build process includes several stages:

1. **Pre-build Verification**

   - Verifies project structure
   - Validates required files
   - Ensures scripts are executable

2. **Build Execution**

   - Uses specialized `scripts/build.sh` script
   - Provides environment variables for Supabase integration
   - Sets Swift concurrency checking levels
   - Handles dependency resolution with caching

3. **Post-build Verification**

   - Verifies app bundle structure
   - Checks executable exists and is valid
   - Validates bundle contents

4. **Artifact Management**
   - Creates versioned ZIP archives
   - Uploads multiple artifact formats
   - Prepares for GitHub Releases
   - Posts artifact download links to PR comments

## PR Comments and Artifact Links

The CI system now automatically posts detailed build information as PR comments with direct artifact download links.

### Comment Features

- **Real-time Status Updates**: Comments are updated throughout the build process

  - Initial "in progress" status when the build starts
  - Final success or error status when the build completes
  - All updates happen to the same comment instead of creating multiple comments

- **Build Information**: The comment includes detailed information about the build:

  - Build status (success or error with detailed error message)
  - App version and build number
  - Binary size and architecture information
  - DMG file information (when available)
  - Compilation timestamp
  - Notarization status
  - Direct link to GitHub Actions artifacts

- **Error Reporting**: When builds fail, the comment provides:
  - Clear error message describing what failed
  - Link to the full build logs
  - Link to any artifacts that were successfully generated
  - Instructions on how to resolve the error

### Implementation Details

- The system uses the `post-binary-info.sh` script to generate and update comments
- Comments are identified and updated using the GitHub API
- The script automatically detects existing comments with Mac binary information
- Developers can run the script manually with `./mac/scripts/post-binary-info.sh` to test PR comment functionality

### Usage from CI

The comment system is automatically triggered for all PR builds through the GitHub Actions workflow.

### Manual Usage

To manually post build information:

```bash
./mac/scripts/post-binary-info.sh --pr-number <PR_NUMBER> --artifact-url <URL> --version <VERSION>
```

To post an error status:

```bash
./mac/scripts/post-binary-info.sh --pr-number <PR_NUMBER> --artifact-url <URL> --version <VERSION> --error "Error message"
```

## Build Caching

Our CI system implements sophisticated caching to improve build performance.

### What Gets Cached

The following directories and files are cached between builds:

- `mac/.build`: Swift build artifacts
- `mac/.swiftpm`: Swift Package Manager metadata
- `mac/binary`: Final app build output
- `~/Library/Developer/Xcode/DerivedData`: Xcode's derived data
- `~/Library/Caches/SwiftLint`: SwiftLint cache

### Cache Fingerprinting

Cache invalidation is controlled by these fingerprint files:

- `mac/Package.swift`: Dependencies declaration
- `mac/Package.resolved`: Resolved dependencies with versions
- `.swiftlint.yml`: SwiftLint configuration

When these files change, relevant parts of the cache are invalidated.

## SwiftLint Integration

SwiftLint has been integrated into both the local development workflow and CI process:

### CI Integration

SwiftLint checks are run as part of the CI process, but are configured as **non-blocking**:

- SwiftLint runs as a separate CI step before building
- Results are saved as artifacts (`lint-results.txt` and `lint-summary.md`)
- The build continues even if SwiftLint finds issues
- In GitHub Actions, results are posted as PR comments
- Developers can review issues without failing builds

### CI-Specific Configuration

To ensure CI builds don't fail due to linting issues:

- A CI-specific SwiftLint configuration is used: `scripts/ci-swiftlint.yml`
- This configuration uses pattern-based exclusion (e.g., `**/*.bak`) instead of specific file paths
- The `--force-exclude` flag is added in CI environments
- The `ensure-lint-summary.sh` script ensures the PR comment workflow always has a lint summary file

For more detailed information on SwiftLint integration, see [SWIFTLINT.md](SWIFTLINT.md).

## CI Scripts

A unified build script is used for both CI and local development:

### Build Script

- `scripts/build.sh`: Main build script for all environments
- Options:
  ```bash
  ./scripts/build.sh --debug      # Build debug configuration
  ./scripts/build.sh --clean      # Force clean build
  ./scripts/build.sh --analyzer   # Run Swift analyzer with strict checking
  ```

### Build Script Features

- Automatic CI environment detection
- Intelligent caching strategies
- Progressive fallbacks for Swift concurrency checking
- Consistent artifact generation across different environments
- Support for different build types (debug/release)
- SwiftLint and SwiftFormat integration

### Binary Info Script

- `scripts/post-binary-info.sh`: Posts build information to PR comments
- Options:
  ```bash
  ./scripts/post-binary-info.sh --pr-number <NUM>   # Specify PR number
  ./scripts/post-binary-info.sh --artifact-url <URL> # Custom artifact URL
  ./scripts/post-binary-info.sh --version <VERSION>  # Specify app version
  ./scripts/post-binary-info.sh --error "Message"    # Post error status
  ```

## Troubleshooting

### GitHub Actions Issues

1. **Cache Miss**

   - Check if key files have changed
   - Verify cache keys in workflow file
   - Try manual cache clearing in GitHub Actions UI

2. **SwiftLint Failures**

   - SwiftLint is non-blocking, but issues are reported
   - Check PR comments for details
   - Run `./mac/run-swiftlint.sh` locally to verify

3. **Missing lint summary file for PR comments**

   - The `ensure-lint-summary.sh` script creates this file automatically
   - If errors persist, check if the script is being called from `scripts/build.sh`
   - Verify that both files have executable permissions: `chmod +x scripts/ensure-lint-summary.sh`

4. **PR Comment Issues**
   - Ensure GitHub token has proper permissions (needs pull-requests:write scope)
   - Check if the comment is already present - the script attempts to update existing comments
   - Run script manually with `DEBUG=1 ./mac/scripts/post-binary-info.sh` to see debug output
   - Try adding the `--pr-number` flag explicitly if auto-detection fails

For more detailed build information, see [BUILD.md](BUILD.md).
