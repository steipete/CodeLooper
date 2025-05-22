#!/bin/bash
# Simple utility to create an empty lint summary file
# This ensures CI workflows never fail due to missing lint-summary.md

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"

LINT_SUMMARY_FILE="$APP_DIR/lint-summary.md"

echo "## SwiftLint Results" > "$LINT_SUMMARY_FILE"
echo "" >> "$LINT_SUMMARY_FILE"
echo "⚠️ This is a fallback lint summary file." >> "$LINT_SUMMARY_FILE"
echo "" >> "$LINT_SUMMARY_FILE"
echo "The actual SwiftLint process was not run or did not complete successfully." >> "$LINT_SUMMARY_FILE"

echo "Created fallback lint summary at $LINT_SUMMARY_FILE"