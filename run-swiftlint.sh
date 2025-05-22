#!/bin/bash
# SwiftLint Script for CodeLooper Mac App
# This script is a wrapper that delegates to the implementation in scripts/swiftlint.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$SCRIPT_DIR"
SWIFTLINT_SCRIPT="$APP_DIR/scripts/swiftlint.sh"

# Check if the implementation script exists
if [ ! -f "$SWIFTLINT_SCRIPT" ]; then
    echo "Error: SwiftLint implementation script not found at $SWIFTLINT_SCRIPT"
    exit 1
fi

# Make the implementation script executable
chmod +x "$SWIFTLINT_SCRIPT"

# Forward all arguments to the implementation script
"$SWIFTLINT_SCRIPT" "$@"