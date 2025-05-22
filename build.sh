#!/bin/bash
# Build script for CodeLooper Mac App
# This script delegates to the main implementation in scripts/build.sh

set -euo pipefail

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Error: Failed to change directory to $SCRIPT_DIR"; exit 1; }

# Main build logic is in scripts/build.sh
# Run the main script with all arguments passed to this script
./scripts/build.sh "$@"