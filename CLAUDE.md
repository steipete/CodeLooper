# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeLooper is a macOS menubar application that monitors Cursor IDE instances and automatically handles stuck states, connection errors, and other interruptions to maintain productive AI-assisted coding sessions. The project uses Swift 6 with strict concurrency checking, SwiftUI/AppKit hybrid architecture, and integrates with the AXorcist accessibility framework for UI automation.

## Essential Commands

### Building and Running

```bash
# Generate Xcode project (CRITICAL: Always use this script, not 'tuist generate' directly)
./scripts/generate-xcproj.sh

# Open in Xcode
./scripts/open-xcode.sh

# Build with xcodebuild (after regenerating if files were added/removed)
xcodebuild -workspace CodeLooper.xcworkspace -scheme CodeLooper -configuration Debug build

# Run the app from command line
./scripts/run-app.sh

# Build AXorcist tools
cd AXorcist && swift build
```

### Code Quality and Linting

```bash
# Run SwiftLint (preserves self. references for Swift 6)
./run-swiftlint.sh

# Run SwiftFormat
./run-swiftformat.sh

# Run both linting and formatting
./lint.sh
```

### Testing

```bash
# Run Swift tests
swift test

# Run AXorcist tests
cd AXorcist && ./run_tests.sh

# Test AXorcist CLI
./AXorcist/.build/debug/axorc --debug '{"command_id":"test","command":"ping"}'
```

## High-Level Architecture

### Project Structure

The project uses a hybrid build system:
- **Tuist**: Project generation and workspace management (Project.swift)
- **Swift Package Manager**: Dependency management (Package.swift)
- **Swift 6**: Strict concurrency checking enabled throughout

### Key Architectural Components

1. **Application Layer** (`Sources/Application/`)
   - `AppDelegate.swift`: Legacy AppKit delegate for system integration
   - `CodeLooperApp.swift`: SwiftUI app entry point
   - `WindowManager.swift`: Window lifecycle management
   - Thread-safe with `@MainActor` isolation

2. **Supervision System** (`Sources/Supervision/`)
   - `CursorMonitor.swift`: Monitors Cursor IDE instances
   - `CursorInterventionEngine.swift`: Handles intervention logic
   - `GitRepositoryMonitor.swift`: Tracks git repository states
   - `WindowAIDiagnosticsManager.swift`: AI-powered window analysis
   - Uses heuristics to detect stuck states and error conditions

3. **AXorcist Integration** (`AXorcist/`)
   - Accessibility framework for macOS UI automation
   - JSON-based command interface via `axorc` CLI
   - Synchronous, main-thread-only C-API (no async in AXorcist)
   - Handles deep Electron accessibility tree traversal

4. **Settings & UI** (`Sources/Settings/`, `Sources/Components/`)
   - SwiftUI-based settings interface
   - `@MainActor` isolated ViewModels
   - Environment objects for state sharing

5. **Diagnostics** (`Sources/Diagnostics/`)
   - Structured logging with categories
   - File-based and session logging
   - Thread-safe logger implementations

### Concurrency Model

- **Swift 6 Strict Concurrency**: Complete checking enabled
- **@MainActor**: All UI code and most managers
- **Explicit self.**: Required in closures for capture semantics
- **Sendable Compliance**: Custom types marked appropriately
- **Actor Isolation**: Long-running operations use custom actors

## Critical Development Notes

### Tuist and Swift 6 Sendable Compliance

**ALWAYS use `./scripts/generate-xcproj.sh` instead of `tuist generate`**

The script performs critical patches for Swift 6 compatibility:
1. Fixes Tuist-generated `TuistPlists+CodeLooper.swift` for Sendable compliance
2. Converts `[String: Any]` to type-safe alternatives
3. Updates `ResourceLoader.swift` to handle typed dictionaries

### AXorcist and Electron Apps

When working with Cursor (Electron app) accessibility:
- Electron limits accessibility tree depth (~30-40 nodes)
- Use focus-based queries for deep elements
- The `debugloop.mdc` file contains extensive learnings about Cursor UI traversal
- Key flags: `--scan-all`, `--no-stop-first`, `--timeout`

### SwiftLint Configuration

- `redundant_self` rule is **disabled** - preserve all `self.` references
- Required for Swift 6 concurrency compliance
- Never remove `self.` in closures

## Common Development Patterns

### Adding New Features

1. Place code in appropriate `Sources/` subdirectory
2. Follow existing MVVM patterns for UI
3. Use `@MainActor` for UI-related code
4. Add appropriate logging with `Logger(category:)`
5. Regenerate Xcode project if files added/removed

### Working with Accessibility

```swift
// Use AXorcist for UI automation
import AXorcist

// JSON command for axorc CLI
let command = """
{
  "command_id": "test",
  "command": "query",
  "application": "com.todesktop.230313mzl4w4u92",
  "locator": {"criteria": {"AXRole": "AXButton"}}
}
"""
```

### Logging Pattern

```swift
import Diagnostics

private let logger = Logger(category: .supervision)

logger.info("Starting supervision cycle")
logger.error("Failed to connect: \(error)")
```

## Dependencies

Key dependencies managed via Swift Package Manager:
- **Defaults**: User preferences management
- **LaunchAtLogin**: Launch at login functionality
- **Sparkle**: Auto-update system
- **AXorcist**: Accessibility automation (local package)
- **AXpector**: Accessibility inspector (local package)
- **DesignSystem**: UI components (local package)

## Security and Permissions

- Requires Accessibility permissions for UI automation
- Requires Screen Recording permissions for AI analysis
- Use Keychain for sensitive data storage
- Never commit API keys or secrets

## Tips from Cursor Rules

- Use `jq` for analyzing large JSON files
- When debugging loops fail, use Claude Code tool for complex analysis
- Pipe verbose logs to files for easier reading
- Use AppleScript to test MCP integrations
- Refactor properly - no backward compatibility needed
- The project uses Swift 6 for all CLI tools