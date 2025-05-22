#!/bin/bash
# SwiftLint Script for CodeLooper Mac App
# This script provides a unified interface for running SwiftLint in different modes

set -e

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
cd "$APP_DIR" || { echo "Error: Failed to change directory to $APP_DIR"; exit 1; }

# Initialize variables with defaults
MODE="check"         # Default mode: just check, don't fix
TARGET="Sources"     # Default target: all Sources
VERBOSE=false        # Default: non-verbose output
CONTINUE_ON_ERROR=false  # Default: exit with error if SwiftLint fails
FORMAT="default"     # Default output format
CONFIG_FILE=""       # Default to no explicit config file

# Print usage information
print_usage() {
    echo "SwiftLint Script for CodeLooper Mac App"
    echo ""
    echo "Usage: $0 [options] [file_or_directory]"
    echo ""
    echo "Options:"
    echo "  --fix                Fix lint issues automatically when possible"
    echo "  --check              Only check for lint issues (default)"
    echo "  --strict             Exit with error code if lint issues are found"
    echo "  --continue           Continue build even if lint issues are found"
    echo "  --config <path>      Path to a SwiftLint configuration file"
    echo "  --format <format>    Output format: default, json, or github"
    echo "  --verbose            Show detailed output"
    echo "  --help               Display this help message"
    echo ""
    echo "If no file or directory is specified, the entire 'Sources' directory will be linted."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            MODE="fix"
            shift
            ;;
        --check)
            MODE="check"
            shift
            ;;
        --strict)
            CONTINUE_ON_ERROR=false
            shift
            ;;
        --continue)
            CONTINUE_ON_ERROR=true
            shift
            ;;
        --config)
            if [[ -z "$2" || "$2" == "" ]]; then
                echo "Error: --config requires a configuration file path"
                exit 1
            else
                CONFIG_FILE="$2"
                shift 2
            fi
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
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # If it's not an option, it must be the target
            TARGET="$1"
            shift
            ;;
    esac
done

# Function for logging with optional timestamps
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
    else
        echo "$1"
    fi
}

# Ensure SwiftLint is available
ensure_swiftlint() {
    log "Checking for SwiftLint..."
    
    # First check for Homebrew-installed SwiftLint (preferred)
    if [ -x "/opt/homebrew/bin/swiftlint" ]; then
        SWIFT_LINT="/opt/homebrew/bin/swiftlint"
        SWIFTLINT_VERSION=$($SWIFT_LINT version)
        log "Using Homebrew-installed SwiftLint $SWIFTLINT_VERSION"
        return
    fi
    
    # Then check if SwiftLint is in PATH
    if command -v swiftlint &> /dev/null; then
        SWIFT_LINT="swiftlint"
        SWIFTLINT_VERSION=$($SWIFT_LINT version)
        log "Using system installed SwiftLint $SWIFTLINT_VERSION"
        return
    fi
    
    # If SwiftLint is not found, show error message with installation instructions
    log "ERROR: SwiftLint not found! Please install it using Homebrew:"
    log "  brew install swiftlint"
    log ""
    log "Using Homebrew version significantly improves build times."
    exit 1
}

# Verify the target exists
verify_target() {
    if [ ! -e "$TARGET" ]; then
        log "Error: Target '$TARGET' does not exist"
        exit 1
    fi
    
    if [ -f "$TARGET" ]; then
        log "Linting single file: $TARGET"
    else
        log "Linting directory: $TARGET"
    fi
}

# Run SwiftLint in the specified mode
run_swiftlint() {
    local swiftlint_cmd="$SWIFT_LINT"
    local exit_code=0
    
    # Set output format - explicitly check to ensure valid format
    # Default to standard reporter if format is invalid or empty
    if [[ "$FORMAT" == "json" ]]; then
        swiftlint_cmd="$swiftlint_cmd --reporter json"
    elif [[ "$FORMAT" == "github" ]]; then
        swiftlint_cmd="$swiftlint_cmd --reporter github-actions"
    else
        # Use default reporter (no need for explicit option)
        log "Using default SwiftLint reporter format"
    fi
    
    # Add configuration file if specified
    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            log "Using custom SwiftLint configuration file: $CONFIG_FILE"
            swiftlint_cmd="$swiftlint_cmd --config $CONFIG_FILE"
        else
            log "Warning: Configuration file '$CONFIG_FILE' not found, using default config"
        fi
    fi
    
    # Run in appropriate mode
    if [ "$MODE" = "fix" ]; then
        log "Running SwiftLint in auto-fix mode..."
        # Quote the target properly for path with spaces
        ${swiftlint_cmd} --fix "${TARGET}"
        fix_exit_code=$?
        if [ $fix_exit_code -ne 0 ]; then
            log "SwiftLint auto-fix failed"
            return $fix_exit_code
        fi
        
        if [ $fix_exit_code -eq 0 ]; then
            log "SwiftLint auto-fix completed successfully"
        else
            log "SwiftLint auto-fix completed with issues"
        fi
        
        # Run again to report remaining issues
        log "Checking for remaining issues after auto-fix..."
        ${swiftlint_cmd} "${TARGET}"
        exit_code=$?
    else
        log "Running SwiftLint in check-only mode..."
        ${swiftlint_cmd} "${TARGET}"
        exit_code=$?
    fi
    
    # Handle the exit code
    if [ $exit_code -ne 0 ]; then
        if [ "$CONTINUE_ON_ERROR" = true ]; then
            log "SwiftLint found issues, but continuing as requested"
            return 0
        else
            log "SwiftLint found issues, exiting with error code"
            return $exit_code
        fi
    else
        log "SwiftLint completed successfully with no issues"
        return 0
    fi
}

# Main execution
main() {
    log "Starting SwiftLint for CodeLooper Mac App"
    
    # Ensure SwiftLint is available
    ensure_swiftlint
    
    # Verify the target exists
    verify_target
    
    # Run SwiftLint
    run_swiftlint
    
    log "SwiftLint process completed"
}

# Run the main function
main