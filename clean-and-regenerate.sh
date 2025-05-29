#!/bin/bash
# Clean and Regenerate Script for CodeLooper Mac App
# This script delegates to the implementation in scripts/clean-and-regenerate.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CLEAN_SCRIPT="$SCRIPT_DIR/scripts/clean-and-regenerate.sh"

# Check if the implementation script exists
if [ ! -f "$CLEAN_SCRIPT" ]; then
    echo "Error: Clean and regenerate implementation script not found at $CLEAN_SCRIPT"
    exit 1
fi

# Make sure the script is executable
chmod +x "$CLEAN_SCRIPT"

# Execute the implementation script with all passed arguments
exec "$CLEAN_SCRIPT" "$@"