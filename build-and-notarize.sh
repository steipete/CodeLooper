#!/bin/bash
# build-and-notarize.sh - Combined script to build, sign, and notarize the FriendshipAI Mac app
# This script provides a single command to go from source code to notarized app

set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Error: Failed to change directory to $SCRIPT_DIR"; exit 1; }

# Log helper functions with timestamp
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

error() {
    log "❌ ERROR: $1"
    return 1
}

warning() {
    log "⚠️ WARNING: $1"
}

success() {
    log "✅ $1"
}

# Process command line arguments
SKIP_BUILD=false
SKIP_NOTARIZE=false
VERBOSE=false
SHOW_HELP=false
SIGN_IDENTITY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --identity)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            SHOW_HELP=true
            shift
            ;;
        *)
            warning "Unknown option: $1"
            SHOW_HELP=true
            shift
            ;;
    esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    cat << EOF
FriendshipAI Mac App Build and Notarization Script

Usage: $(basename "$0") [options]

Options:
  --skip-build         Skip the build step (use existing binary)
  --skip-notarize      Skip the notarization step
  --identity STRING    Use specific signing identity (defaults to environment APPLE_IDENTITY)
  --verbose            Enable verbose output
  --help               Show this help message

Environment Variables (can be used instead of command line arguments):
  APPLE_ID             Apple ID email for notarization
  APPLE_PASSWORD       App-specific password for the Apple ID
  APPLE_TEAM_ID        Apple Developer Team ID
  APPLE_IDENTITY       Developer ID certificate to use for signing
  
Example:
  ./build-and-notarize.sh
  ./build-and-notarize.sh --skip-build --identity "Developer ID Application: Your Name (TEAM_ID)"
  
Environment file:
  You can also provide these variables in a .env.notarize file in the mac directory
EOF
    exit 0
fi

# Track start time for reporting
START_TIME=$(date +%s)

log "Starting FriendshipAI Mac app build and notarization process..."

# Set identity if provided
if [ -n "$SIGN_IDENTITY" ]; then
    export APPLE_IDENTITY="$SIGN_IDENTITY"
    log "Using signing identity: $SIGN_IDENTITY"
fi

# Step 1: Build the app
if [ "$SKIP_BUILD" = false ]; then
    log "Building FriendshipAI Mac app..."
    if [ "$VERBOSE" = true ]; then
        ./build.sh
    else
        ./build.sh > /dev/null
    fi
    
    if [ $? -ne 0 ]; then
        error "Build failed. Please check the build output for errors."
        exit 1
    fi
    
    success "Build completed successfully"
else
    log "Skipping build step as requested"
fi

# Step 2: Code sign the app
log "Code signing the app with hardened runtime..."
CODESIGN_ARGS=""
if [ "$VERBOSE" = true ]; then
    CODESIGN_ARGS="--verbose"
fi

if [ -n "${APPLE_IDENTITY:-}" ]; then
    CODESIGN_ARGS="$CODESIGN_ARGS --identity \"$APPLE_IDENTITY\""
fi

CODESIGN_CMD="./scripts/codesign-app.sh $CODESIGN_ARGS"
if ! eval "$CODESIGN_CMD"; then
    error "Code signing failed. Please check the output for errors."
    exit 1
fi

success "Code signing completed successfully"

# Step 3: Notarize the app (if not skipped)
if [ "$SKIP_NOTARIZE" = false ]; then
    log "Notarizing the app..."
    
    # Build notarization arguments
    NOTARIZE_ARGS=""
    
    # Add any additional arguments for notarization
    if [ "$VERBOSE" = true ]; then
        NOTARIZE_ARGS="$NOTARIZE_ARGS --verbose"
    fi
    
    if [ -n "${APPLE_IDENTITY:-}" ]; then
        NOTARIZE_ARGS="$NOTARIZE_ARGS --sign-identity \"$APPLE_IDENTITY\""
    fi
    
    # Run the notarization script with the built arguments
    if ! ./scripts/notarize-mac.sh $NOTARIZE_ARGS; then
        error "Notarization failed. Please check the output for errors."
        exit 1
    fi
    
    success "Notarization completed successfully"
else
    log "Skipping notarization step as requested"
fi

# Calculate and show elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

success "Build and notarization process completed in ${MINUTES}m ${SECONDS}s"
log "Summary:"
log "- App bundle: binary/FriendshipAI.app"
log "- Distributable ZIP: binary/FriendshipAI-notarized.zip"
log ""
log "The app is now ready for distribution!"