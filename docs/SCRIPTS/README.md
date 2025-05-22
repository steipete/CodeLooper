# CodeLooper Mac App Scripts

This document provides an overview of scripts used for building, testing, and maintaining the CodeLooper Mac application.

## Build Scripts

### build.sh

Main build script that handles building the CodeLooper Mac application with Swift Package Manager.

**Usage:**

```bash
./scripts/build.sh [options]
```

**Options:**

- `--debug` - Build debug configuration instead of release
- `--clean` - Force clean build artifacts and resolve dependencies
- `--analyzer` - Run Swift analyzer with strict checking during build
- `--no-xcbeautify` - Skip xcbeautify formatting of build output
- `--skip-lint` - Skip SwiftLint code quality checks
- `-Xswiftc <flag>` - Pass additional flags to the Swift compiler
- `--help` - Show help message

## Lint Scripts

### run-swiftlint.sh

Unified SwiftLint script that provides various modes and options for code quality checks.

**Usage:**

```bash
../run-swiftlint.sh [options] [file_or_directory]
```

**Options:**

- `--fix` - Fix lint issues automatically when possible
- `--check` - Only check for lint issues (default)
- `--strict` - Exit with error code if lint issues are found
- `--continue` - Continue build even if lint issues are found
- `--format <format>` - Output format: default, json, or github
- `--verbose` - Show detailed output
- `--help` - Display help message

If no file or directory is specified, the entire 'Sources' directory will be linted.

This script is located in the main mac directory.

## SwiftLint CI Scripts

### swiftlint.sh

Main SwiftLint runner script that performs code quality checks.

```bash
./scripts/swiftlint.sh [--fix] [--check] [--format <format>] [path]
```

Options:

- `--fix`: Auto-fix supported issues
- `--check`: Only check for issues (default)
- `--format`: Output format (default, json, github)
- `path`: Path to lint (default: Sources)

### ci-swiftlint.sh

CI-specific wrapper for SwiftLint that ensures proper output files are created for GitHub Actions.

```bash
./scripts/ci-swiftlint.sh [--verbose] [--format <format>]
```

This script:

- Runs SwiftLint and captures output
- Creates `lint-results.txt` with full output
- Generates `lint-summary.md` for GitHub PR comments
- Won't fail the build even if linting has warnings or errors

### create-lint-summary.sh

Utility to create a fallback lint summary file when needed.

```bash
./scripts/create-lint-summary.sh
```

This script creates a simple `lint-summary.md` file to ensure the CI workflow never fails due to a missing summary file.

## Utility Scripts

### inject-keys.sh

Script to inject API keys into the Swift build environment from environment variables.

```bash
../inject-keys.sh
```

This script is located in the main mac directory and is called by the build scripts. It doesn't need direct invocation in most cases.

## Development Scripts

### open-xcode.sh

Opens the CodeLooper Mac app in Xcode.

**Usage:**

```bash
./scripts/open-xcode.sh
```

### run-app.sh

Builds and runs the CodeLooper Mac app directly from the build directory.

**Usage:**

```bash
./scripts/run-app.sh [options]
```

**Options:**

- `--release` - Build in release mode (default is debug)
- `--no-run` - Build only, don't run the app
- `--verbose` - Show verbose build output
- `--help` - Display help message

## Script Execution Permissions

All scripts should have executable permissions. If not, you can set them with:

```bash
chmod +x scripts/**/*.sh
```

## Common Workflows

### Clean Build

For a completely clean build:

```bash
./scripts/build.sh --clean
```

### Quick Run for Development

Build and run for quick testing:

```bash
./scripts/run-app.sh
```

### Open in Xcode

To open the project in Xcode:

```bash
./scripts/open-xcode.sh
```

### CI Build

For GitHub Actions environment:

```bash
./scripts/build.sh --platform github
```

## Error Handling

All scripts include proper error handling and will exit with appropriate error codes when issues are encountered. Check the script output for detailed error messages.
