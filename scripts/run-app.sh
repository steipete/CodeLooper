#!/bin/bash
# run-app.sh - Builds and runs the CodeLooper Mac app
#
# This script builds the application using Swift Package Manager and then
# runs it directly from the build directory for quick testing.

set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
BUILD_TYPE="debug"
VERBOSE=false
RUN_IMMEDIATELY=true

# Log helper function with timestamp
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Print usage information
print_usage() {
    echo "Run Script for CodeLooper Mac App"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --release           Build in release mode (default is debug)"
    echo "  --no-run            Build only, don't run the app"
    echo "  --verbose           Show verbose build output"
    echo "  --help              Display this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --no-run)
            RUN_IMMEDIATELY=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Build the app
log "Building CodeLooper macOS app in $BUILD_TYPE mode..."

# Prepare build command
BUILD_CMD="swift build --package-path . -c $BUILD_TYPE"
if [ "$VERBOSE" = true ]; then
    BUILD_CMD="$BUILD_CMD -v"
    log "Using verbose build output"
fi

# Execute build command
log "Running: $BUILD_CMD"
if ! eval "$BUILD_CMD"; then
    log "Error: Build failed"
    exit 1
fi

log "Build completed successfully"

# Define paths
BUILD_DIR=".build/$BUILD_TYPE"
EXECUTABLE_PATH="$BUILD_DIR/CodeLooper"

# Check if the executable exists
if [ ! -f "$EXECUTABLE_PATH" ]; then
    log "Error: Executable not found at $EXECUTABLE_PATH"
    exit 1
fi

# Set executable permissions
chmod +x "$EXECUTABLE_PATH"

# Run the app if requested
if [ "$RUN_IMMEDIATELY" = true ]; then
    log "Running CodeLooper macOS app..."
    "$EXECUTABLE_PATH"
else
    log "App built successfully at: $EXECUTABLE_PATH"
    log "Run manually with: $EXECUTABLE_PATH"
fi
