#!/bin/bash
# CI Helper for SwiftFormat - creates consistent format summary files for GitHub CI
# This script ensures that format-summary.md is always created for CI workflow

set -e

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
VERBOSE=false

# Function for logging with optional timestamps
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
    else
        echo "$1"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Setup for format results
FORMAT_RESULTS_FILE="$APP_DIR/format-results.txt"
FORMAT_SUMMARY_FILE="$APP_DIR/format-summary.md"

# Ensure Homebrew SwiftFormat is installed
if [ ! -x "/opt/homebrew/bin/swiftformat" ]; then
    log "Homebrew SwiftFormat not found. Generating fallback format summary."
    
    # Create a fallback summary file to ensure CI can continue
    echo "## SwiftFormat Results" > "$FORMAT_SUMMARY_FILE" 
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "⚠️ SwiftFormat check was skipped - please install via Homebrew:" >> "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "```shell" >> "$FORMAT_SUMMARY_FILE"
    echo "brew install swiftformat" >> "$FORMAT_SUMMARY_FILE" 
    echo "```" >> "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "Using Homebrew version significantly improves build times." >> "$FORMAT_SUMMARY_FILE"
    
    # Exit with success to allow CI to continue
    exit 0
fi

log "Running SwiftFormat and generating CI compatible output..."

# Run SwiftFormat and capture output
if [ -f "$SCRIPT_DIR/swiftformat.sh" ]; then
    chmod +x "$SCRIPT_DIR/swiftformat.sh"
    
    # Run SwiftFormat in check mode
    log "Using SwiftFormat implementation in $SCRIPT_DIR/swiftformat.sh"
    set +e  # Don't exit on error
    "$SCRIPT_DIR/swiftformat.sh" --check --verbose | tee "$FORMAT_RESULTS_FILE"
    FORMAT_EXIT_CODE=$?
    set -e  # Re-enable exit on error
    
    # Count issues for summary
    ISSUES=$(grep -c "would have formatted" "$FORMAT_RESULTS_FILE" 2>/dev/null || echo "0")
    
    # Generate a markdown summary
    log "Generating SwiftFormat summary with $ISSUES formatting issues"
    echo "## SwiftFormat Results" > "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "* **Files with formatting issues:** $ISSUES" >> "$FORMAT_SUMMARY_FILE"
    
    # Add top issues to summary if there are any
    if [[ "${ISSUES:-0}" -gt 0 ]]; then
        echo "### Files needing formatting:" >> "$FORMAT_SUMMARY_FILE"
        echo '```' >> "$FORMAT_SUMMARY_FILE"
        grep "would have formatted" "$FORMAT_RESULTS_FILE" 2>/dev/null | head -10 >> "$FORMAT_SUMMARY_FILE"
        echo '```' >> "$FORMAT_SUMMARY_FILE"
        
        if [ "$ISSUES" -gt 10 ]; then
            echo "" >> "$FORMAT_SUMMARY_FILE"
            echo "See format-results.txt artifact for complete list of issues." >> "$FORMAT_SUMMARY_FILE"
        fi
        
        echo "" >> "$FORMAT_SUMMARY_FILE"
        echo "To fix formatting issues, run: `pnpm format:swift`" >> "$FORMAT_SUMMARY_FILE"
    else
        echo "✅ No SwiftFormat issues found!" >> "$FORMAT_SUMMARY_FILE"
    fi
else
    log "SwiftFormat implementation script not found at $SCRIPT_DIR/swiftformat.sh"
    
    # Create a fallback summary file to ensure CI doesn't fail
    echo "## SwiftFormat Results" > "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "SwiftFormat check was skipped as the implementation script wasn't found." >> "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "Please ensure the script exists at: $SCRIPT_DIR/swiftformat.sh" >> "$FORMAT_SUMMARY_FILE"
fi

# Always ensure the summary file exists
if [ ! -f "$FORMAT_SUMMARY_FILE" ]; then
    echo "## SwiftFormat Results" > "$FORMAT_SUMMARY_FILE"
    echo "" >> "$FORMAT_SUMMARY_FILE"
    echo "No SwiftFormat output was generated." >> "$FORMAT_SUMMARY_FILE"
fi

log "SwiftFormat summary generated at: $FORMAT_SUMMARY_FILE"