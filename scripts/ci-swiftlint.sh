#!/bin/bash
# CI Helper for SwiftLint - creates consistent lint summary files for GitHub CI
# This script ensures that lint-summary.md is always created for CI workflow

set -e

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
VERBOSE=false
FORMAT="default"

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
        --format)
            if [[ -z "$2" || "$2" == "" ]]; then
                # Empty format value defaults to "default"
                FORMAT="default"
                shift 2
            elif [[ "$2" =~ ^(default|json|github)$ ]]; then
                FORMAT="$2"
                shift 2
            else
                echo "Warning: Invalid format '$2'. Using default format instead."
                FORMAT="default"
                shift 2
            fi
            ;;
        *)
            shift
            ;;
    esac
done

# Setup for lint results
LINT_RESULTS_FILE="$APP_DIR/lint-results.txt"
LINT_SUMMARY_FILE="$APP_DIR/lint-summary.md"

# Ensure Homebrew SwiftLint is installed
if [ ! -x "/opt/homebrew/bin/swiftlint" ]; then
    log "Homebrew SwiftLint not found. Generating fallback lint summary."
    
    # Create a fallback summary file to ensure CI can continue
    echo "## SwiftLint Results" > "$LINT_SUMMARY_FILE" 
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "⚠️ SwiftLint check was skipped - please install via Homebrew:" >> "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "```shell" >> "$LINT_SUMMARY_FILE"
    echo "brew install swiftlint" >> "$LINT_SUMMARY_FILE" 
    echo "```" >> "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "Using Homebrew version significantly improves build times." >> "$LINT_SUMMARY_FILE"
    
    # Exit with error since SwiftLint is not available
    exit 1
fi

log "Running SwiftLint and generating CI compatible output..."

# Run SwiftLint and capture output
if [ -f "$APP_DIR/run-swiftlint.sh" ]; then
    chmod +x "$APP_DIR/run-swiftlint.sh"
    
    # Run SwiftLint with the CI-specific config file if it exists
    CI_CONFIG="$SCRIPT_DIR/ci-swiftlint.yml"
    if [ -f "$CI_CONFIG" ]; then
        log "Using CI-specific SwiftLint configuration"
        set +e  # Don't exit on error
        if [ "$FORMAT" != "default" ]; then
            "$APP_DIR/run-swiftlint.sh" --config "$CI_CONFIG" --format "$FORMAT" | tee "$LINT_RESULTS_FILE"
        else
            "$APP_DIR/run-swiftlint.sh" --config "$CI_CONFIG" | tee "$LINT_RESULTS_FILE"
        fi
        LINT_EXIT_CODE=$?
        set -e  # Re-enable exit on error
    else
        log "Using default SwiftLint configuration"
        set +e  # Don't exit on error
        if [ "$FORMAT" != "default" ]; then
            "$APP_DIR/run-swiftlint.sh" --format "$FORMAT" | tee "$LINT_RESULTS_FILE"
        else
            "$APP_DIR/run-swiftlint.sh" | tee "$LINT_RESULTS_FILE"
        fi
        LINT_EXIT_CODE=$?
        set -e  # Re-enable exit on error
    fi
    
    # Count issues for summary
    WARNINGS=$(grep -c "warning:" "$LINT_RESULTS_FILE" 2>/dev/null || echo "0")
    ERRORS=$(grep -c "error:" "$LINT_RESULTS_FILE" 2>/dev/null || echo "0")
    
    # Clean up the warning and error counts to ensure they're just single numbers
    # First ensure variables contain numeric values
    if [[ ! "$WARNINGS" =~ ^[0-9]+$ ]]; then
        WARNINGS=0
    fi
    if [[ ! "$ERRORS" =~ ^[0-9]+$ ]]; then
        ERRORS=0
    fi
    
    # Then format and process the values
    WARNINGS=$(echo "$WARNINGS" | tr -d '\n' | sed 's/^0*//' || echo "0")
    ERRORS=$(echo "$ERRORS" | tr -d '\n' | sed 's/^0*//' || echo "0")
    
    # If after removing leading zeros we get empty strings, set them to 0
    if [[ -z "$WARNINGS" ]]; then
        WARNINGS=0
    fi
    if [[ -z "$ERRORS" ]]; then
        ERRORS=0
    fi
    
    # Generate a markdown summary
    log "Generating SwiftLint summary with $WARNINGS warnings and $ERRORS errors"
    echo "## SwiftLint Results" > "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "* **Warnings:** $WARNINGS" >> "$LINT_SUMMARY_FILE"
    echo "* **Errors:** $ERRORS" >> "$LINT_SUMMARY_FILE"
    
    # Add top issues to summary if there are any
    if [[ $WARNINGS -gt 0 || $ERRORS -gt 0 ]]; then
        echo "### Top Issues:" >> "$LINT_SUMMARY_FILE"
        echo '```' >> "$LINT_SUMMARY_FILE"
        grep -E "warning:|error:" "$LINT_RESULTS_FILE" 2>/dev/null | head -10 >> "$LINT_SUMMARY_FILE"
        echo '```' >> "$LINT_SUMMARY_FILE"
        
        if [ "$WARNINGS" -gt 10 ] || [ "$ERRORS" -gt 10 ]; then
            echo "" >> "$LINT_SUMMARY_FILE"
            echo "See lint-results.txt artifact for complete list of issues." >> "$LINT_SUMMARY_FILE"
        fi
    else
        echo "✅ No SwiftLint issues found!" >> "$LINT_SUMMARY_FILE"
    fi
else
    log "SwiftLint script not found at $APP_DIR/run-swiftlint.sh"
    
    # Create a fallback summary file to ensure CI doesn't fail
    echo "## SwiftLint Results" > "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "SwiftLint check was skipped as the script wasn't found." >> "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "Please ensure the runner script exists at: $APP_DIR/run-swiftlint.sh" >> "$LINT_SUMMARY_FILE"
fi

# Always ensure the summary file exists
if [ ! -f "$LINT_SUMMARY_FILE" ]; then
    echo "## SwiftLint Results" > "$LINT_SUMMARY_FILE"
    echo "" >> "$LINT_SUMMARY_FILE"
    echo "No SwiftLint output was generated." >> "$LINT_SUMMARY_FILE"
fi

log "SwiftLint summary generated at: $LINT_SUMMARY_FILE"

# Exit with appropriate code based on SwiftLint results
if [ "${LINT_EXIT_CODE:-0}" -ne 0 ]; then
    log "SwiftLint found issues (exit code: $LINT_EXIT_CODE)"
    exit "$LINT_EXIT_CODE"
else
    log "SwiftLint completed successfully"
    exit 0
fi