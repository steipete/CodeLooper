#!/bin/bash
# build.sh - Main build script for CodeLooper Mac App
#
# This script handles building the CodeLooper Mac application with Swift Package Manager,
# providing options for different build types, cleanliness levels, and compiler flags.

# Enable fail-fast behavior to catch errors early
set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)" 
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
BUILD_TYPE="release"
FORCE_CLEAN=false
SWIFT_FLAGS=""
XCBEAUTIFY=false # Disabled by default for CI builds
RUN_ANALYZER=false
SKIP_LINTING=false
SIGN_APP=true
P12_FILE_ARG=""
P12_PASSWORD_ARG=""

# Log helper function with timestamp
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Print usage information
print_usage() {
    echo "Build Script for CodeLooper Mac App"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --debug           Build debug configuration instead of release"
    echo "  --clean           Force clean build artifacts and resolve dependencies"
    echo "  --analyzer        Run Swift analyzer with strict checking during build"
    echo "  --no-xcbeautify   Skip xcbeautify formatting of build output"
    echo "  --skip-lint       Skip SwiftLint code quality checks"
    echo "  --skip-signing    Skip app bundle code signing"
    echo "  --p12-file PATH   Path to the .p12 file for signing with rcodesign (required if signing)"
    echo "  --p12-password PASS Password for the .p12 file (required if signing)"
    echo "  --build-path      Specify custom build path for Swift package manager"
    echo "  -Xswiftc <flag>   Pass additional flags to the Swift compiler"
    echo "  --help            Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --clean)
            FORCE_CLEAN=true
            shift
            ;;
        --analyzer)
            RUN_ANALYZER=true
            shift
            ;;
        --no-xcbeautify)
            XCBEAUTIFY=false
            shift
            ;;
        --skip-lint)
            SKIP_LINTING=true
            shift
            ;;
        --skip-signing)
            SIGN_APP=false
            shift
            ;;
        --p12-file)
            P12_FILE_ARG="$2"
            shift 2
            ;;
        --p12-password)
            P12_PASSWORD_ARG="$2"
            shift 2
            ;;
        -Xswiftc)
            SWIFT_FLAGS="$SWIFT_FLAGS -Xswiftc $2"
            shift 2
            ;;
        --build-path)
            BUILD_PATH="$2"
            shift 2
            ;;
        -Xswiftc\ -build-path=*)
            # Handle combined build path format
            BUILD_PATH="${1#*=}"
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            # Pass through any unknown arguments to Swift build command
            SWIFT_FLAGS="$SWIFT_FLAGS $1"
            shift
            ;;
    esac
done

log "Building CodeLooper Mac App for macOS..."

# Check Xcode version
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | grep 'Xcode' | awk '{print $2}')
    log "Using Xcode $XCODE_VERSION"
else
    log "Warning: Xcode not found. This may cause build issues."
fi

# Verify Swift version
log "Checking Swift version..."
SWIFT_VERSION=$(swift --version | head -n 1)
log "Using $SWIFT_VERSION"

# Set Swift major version
SWIFT_MAJOR=6

# Prepare build environment
log "Preparing build environment..."

# Clean build artifacts if requested
if [ "$FORCE_CLEAN" = true ]; then
    log "Force cleaning build artifacts..."
    rm -rf .build
    rm -rf binary
    swift package clean
fi

# Create output directory
mkdir -p binary

# Build configuration
CONFIG_FLAGS=""
if [ "$BUILD_TYPE" = "debug" ]; then
    CONFIG_FLAGS="--configuration debug"
    log "Building in DEBUG mode"
else
    CONFIG_FLAGS="--configuration release"
    log "Building in RELEASE mode"
fi

# Add Swift 6 concurrency flags
SWIFT_FLAGS="$SWIFT_FLAGS -Xswiftc -strict-concurrency=complete"

# Add analyzer flags if requested
if [ "$RUN_ANALYZER" = true ]; then
    log "Enabling Swift static analyzer..."
    SWIFT_FLAGS="$SWIFT_FLAGS -Xswiftc -Xanalyzer -Xswiftc -analyzer-checker=core,swift"
fi

# Build the app
log "Building CodeLooper with Swift Package Manager..."
BUILD_COMMAND="swift build $CONFIG_FLAGS $SWIFT_FLAGS"

log "Executing: $BUILD_COMMAND"
if [ "$XCBEAUTIFY" = true ] && command -v xcbeautify &> /dev/null; then
    eval "$BUILD_COMMAND" | xcbeautify
else
    eval "$BUILD_COMMAND"
fi

# Get the built executable path
EXECUTABLE_PATH="$(swift build $CONFIG_FLAGS $SWIFT_FLAGS --show-bin-path)/CodeLooper"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    log "Error: Built executable not found at $EXECUTABLE_PATH"
    exit 1
fi

log "✅ Build completed successfully"
log "Executable: $EXECUTABLE_PATH"

# Create app bundle
log "Creating CodeLooper.app bundle..."
APP_BUNDLE="binary/CodeLooper.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/CodeLooper"

# Copy Info.plist
cp "CodeLooper/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy resources
if [ -d "Resources" ]; then
    cp -R "Resources"/* "$APP_BUNDLE/Contents/Resources/"
fi

# Copy assets
if [ -d "CodeLooper/Assets.xcassets" ]; then
    cp -R "CodeLooper/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"
fi

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/CodeLooper"

log "✅ App bundle created at $APP_BUNDLE"

# Code signing if requested
if [ "$SIGN_APP" = true ]; then
    log "Code signing CodeLooper.app..."
    
    # Source signing configuration if available
    CODESIGN_CONFIG="$APP_DIR/.codesign-config"
    if [ -f "$CODESIGN_CONFIG" ]; then
        source "$CODESIGN_CONFIG"
        log "📋 Loaded signing configuration from $CODESIGN_CONFIG"
    fi
    
    if [ -n "$P12_FILE_ARG" ] && [ -n "$P12_PASSWORD_ARG" ]; then
        log "Using P12 certificate for signing..."
        if ! command -v rcodesign &> /dev/null; then
            log "Error: rcodesign not found. Please install it or use --skip-signing"
            exit 1
        fi
        
        rcodesign sign \
            --p12-file "$P12_FILE_ARG" \
            --p12-password "$P12_PASSWORD_ARG" \
            --code-signature-flags runtime \
            "$APP_BUNDLE"
    else
        log "Using system keychain for signing..."
        # Use Apple Development certificate for development builds to maintain consistent TCC permissions
        # This prevents TCC database thrashing that occurs with ad-hoc or changing signatures
        if [ "$BUILD_TYPE" = "debug" ]; then
            SIGNING_IDENTITY="${DEVELOPMENT_SIGNING_IDENTITY:-Apple Development: Peter Steinberger (2ZAC4GM7GD)}"
            log "Using Apple Development certificate for debug build..."
        else
            SIGNING_IDENTITY="${DISTRIBUTION_SIGNING_IDENTITY:-Developer ID Application}"
            log "Using Developer ID certificate for release build..."
        fi
        codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
    fi
    
    log "✅ Code signing completed"
else
    log "⚠️  Skipping code signing (--skip-signing flag used)"
fi

log "✅ CodeLooper build process completed successfully!"
log "App bundle location: $APP_BUNDLE"