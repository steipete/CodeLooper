#!/bin/bash
# SwiftFormat Script for CodeLooper Mac App
# This script is a wrapper that delegates to the implementation in scripts/swiftformat.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$SCRIPT_DIR"
SWIFTFORMAT_SCRIPT="$APP_DIR/scripts/swiftformat.sh"

# Check if the implementation script exists
if [ ! -f "$SWIFTFORMAT_SCRIPT" ]; then
    echo "Error: SwiftFormat implementation script not found at $SWIFTFORMAT_SCRIPT"
    exit 1
fi

# Make the implementation script executable
chmod +x "$SWIFTFORMAT_SCRIPT"

# Forward all arguments to the implementation script
"$SWIFTFORMAT_SCRIPT" "$@"