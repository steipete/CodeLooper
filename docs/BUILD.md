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

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Node.js v22.14.0 or later
- pnpm v10.10.0
- Supabase account and API credentials

## Building Methods

### Building via pnpm (Recommended)

The recommended way to build the macOS app is using the project's pnpm scripts from the repository root. This method automatically handles environment variables and credential management.

#### Setup Environment Variables

```bash
# Option 1: Set for current shell session only
export SUPABASE_URL=https://api.friendship.ai
export SUPABASE_ANON_KEY=your_supabase_anon_key_here

# Option 2: Set just for the build command
SUPABASE_URL=https://api.friendship.ai SUPABASE_ANON_KEY=your_key_here pnpm build:mac
```

> ⚠️ **Security Warning**: Never commit your Supabase keys to version control.

#### Build Commands

From the repository root:

```bash
# Standard build
pnpm build:mac

# Debug build
pnpm build:mac -- --debug

# Clean build (forces clean build artifacts)
pnpm build:mac -- --clean
```

### Manual Building (Advanced)

If you need more control over the build process, you can build the macOS app directly.

#### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/CodeLooper.git
cd CodeLooper
```

#### Step 2: Set Up Environment Variables

Create an `.env` file in the project root with your Supabase credentials:

```
SUPABASE_URL=https://api.friendship.ai
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

#### Step 3: Build the App

```bash
cd mac
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY ./build.sh
```

## Build Script Options

The `build.sh` script provides various options to customize the build process:

```bash
./build.sh [options]
```

### Available Options

- `--debug`: Build debug configuration instead of release
- `--clean`: Force clean build artifacts and resolve dependencies
- `--analyzer`: Run Swift analyzer with strict checking during build
- `--no-xcbeautify`: Skip xcbeautify formatting of build output
- `-Xswiftc <flag>`: Pass additional flags to the Swift compiler
- `--help`: Show help message

### Build Modes

1. **Standard Build** (default): Full-featured build with error recovery

   ```bash
   ./build.sh
   ```

2. **Clean Build** (resolves dependency issues):

   ```bash
   ./build.sh --clean
   ```

3. **Debug Build** (for development and debugging):

   ```bash
   ./build.sh --debug
   ```

4. **Analyzer Build** (finds potential issues with stricter checks):
   ```bash
   ./build.sh --analyzer
   ```

## How the Build System Works

The build process follows these steps:

1. The `pnpm build:mac` command runs `scripts/mac-build-with-env.js`
2. This script:

   - Validates Supabase credentials are present in environment variables
   - Passes these credentials to the macOS build script
   - Invokes the macOS build script with any additional flags

3. The macOS build script (`mac/build.sh`):
   - Injects the Supabase credentials into `Constants.swift` via `inject-keys.sh`
   - Builds the app using Swift Package Manager
   - Creates an application bundle
   - Cleans up temporary files and restores original source files
4. When running in CI (GitHub Actions):
   - The binary information is collected (size, date, checksum)
   - A detailed comment is posted to the PR with this information
   - Download links to the binary are provided in the PR comment

### Script Behavior

- The script automatically uses the latest Swift features and compatibility flags
- Preserves build artifacts for faster incremental builds by default
- Only performs full cleanup when `--clean` is explicitly requested
- Uses complete concurrency checking for strict Swift concurrency safety
- Includes multiple fallback strategies to recover from build failures
- Creates the final application bundle in `binary/CodeLooper.app`
- Targets macOS 14.0 with the latest development tools

## Authentication Flow

The macOS app uses ASWebAuthenticationSession with a custom URL scheme for authentication:

1. App opens web auth session to `/api/auth/desktop?client=macos`
2. User authenticates via Supabase in a web browser
3. After successful authentication, the web app redirects to `codelooper://auth?token=xxx`
4. The macOS app receives this callback and extracts the token
5. Token is stored in the macOS Keychain for persistent authentication

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

### Build Fails with "No Supabase Credentials"

Ensure you've set both `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables.

### Authentication Failure

1. Verify your Supabase anon key is correct
2. Check that the macOS app has the correct URL scheme registered
3. Verify the web API endpoint is working correctly

### Swift Build Errors

If you encounter Swift build errors:

```bash
# Try a clean build
pnpm build:mac -- --clean

# Or manually:
cd mac
rm -rf .build Package.resolved
swift package reset
./build.sh
```

For more information on CI/CD systems, see [CI.md](CI.md).
