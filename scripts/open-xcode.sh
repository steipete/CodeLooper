#!/bin/bash
# open-xcode.sh - Opens the FriendshipAI Mac app in Xcode
#
# This script resolves dependencies if needed and opens the Swift Package Manager
# workspace in Xcode for development and debugging.

set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Log helper function with timestamp
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

log "Opening FriendshipAI Mac app in Xcode"

# Resolve dependencies if needed
if [ ! -d ".swiftpm" ]; then
  log "First-time setup: Resolving dependencies..."
  swift package resolve
  
  if [ $? -ne 0 ]; then
    log "Error: Failed to resolve dependencies. Please check your internet connection and try again."
    exit 1
  fi
  
  log "Dependencies resolved successfully"
fi

# Check if the workspace exists
WORKSPACE=".swiftpm/xcode/package.xcworkspace"
if [ ! -d "$WORKSPACE" ]; then
  log "Error: Xcode workspace not found at $WORKSPACE"
  log "Trying to regenerate workspace..."
  
  # Force regeneration of the workspace
  rm -rf .swiftpm/xcode
  swift package generate-xcodeproj
  
  if [ ! -d "$WORKSPACE" ]; then
    log "Error: Failed to generate Xcode workspace. Try running 'swift package generate-xcodeproj' manually."
    exit 1
  fi
  
  log "Workspace regenerated successfully"
fi

# Directly open the workspace
if ! open "$WORKSPACE"; then
  log "Error: Failed to open Xcode workspace. Please open it manually."
  exit 1
fi

log "Successfully opened Swift Package Manager workspace in Xcode"
log "Location: $WORKSPACE"
