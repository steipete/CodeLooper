#!/bin/bash
# SwiftFormat Implementation Script for FriendshipAI Mac App
# Core implementation for running SwiftFormat that is called by wrapper scripts

set -e

# Get script directory and ensure we're in the right location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"

# Initialize variables with defaults
MODE="check"         # Default mode: just check, don't fix
TARGET="$APP_DIR/Sources"     # Default target: all Sources
VERBOSE=false        # Default: non-verbose output
CONTINUE_ON_ERROR=false  # Default: exit with error if SwiftFormat fails
CONFIG="$APP_DIR/.swiftformat"    # Config file path

# Print usage information
print_usage() {
    echo "SwiftFormat Implementation Script for FriendshipAI Mac App"
    echo ""
    echo "Usage: $0 [options] [file_or_directory]"
    echo ""
    echo "Options:"
    echo "  --format             Format code (automatically fix style issues)"
    echo "  --check              Only check for format issues without fixing (default)"
    echo "  --strict             Exit with error code if format issues are found"
    echo "  --continue           Continue build even if format issues are found"
    echo "  --config <path>      Use a custom SwiftFormat configuration file"
    echo "  --verbose            Show detailed output"
    echo "  --help               Display this help message"
    echo ""
    echo "If no file or directory is specified, the entire 'Sources' directory will be formatted."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            MODE="format"
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
            if [ -f "$2" ]; then
                CONFIG="$2"
                shift 2
            else
                echo "Error: Config file '$2' does not exist or is not a file"
                exit 1
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

# Ensure SwiftFormat is available
ensure_swiftformat() {
    log "Checking for SwiftFormat..."
    
    # First check for Homebrew-installed SwiftFormat (preferred)
    if [ -x "/opt/homebrew/bin/swiftformat" ]; then
        SWIFT_FORMAT="/opt/homebrew/bin/swiftformat"
        SWIFTFORMAT_VERSION=$($SWIFT_FORMAT --version)
        log "Using Homebrew-installed SwiftFormat $SWIFTFORMAT_VERSION"
        return
    fi
    
    # Then check if SwiftFormat is in PATH
    if command -v swiftformat &> /dev/null; then
        SWIFT_FORMAT="swiftformat"
        SWIFTFORMAT_VERSION=$($SWIFT_FORMAT --version)
        log "Using system installed SwiftFormat $SWIFTFORMAT_VERSION"
        return
    fi
    
    # If SwiftFormat is not found, show error message with installation instructions
    log "ERROR: SwiftFormat not found! Please install it using Homebrew:"
    log "  brew install swiftformat"
    exit 1
}

# Verify the target exists
verify_target() {
    if [ ! -e "$TARGET" ]; then
        log "Error: Target '$TARGET' does not exist"
        exit 1
    fi
    
    if [ -f "$TARGET" ]; then
        log "Formatting single file: $TARGET"
    else
        log "Formatting directory: $TARGET"
    fi
}

# Run SwiftFormat in the specified mode
run_swiftformat() {
    local swiftformat_cmd="$SWIFT_FORMAT --config $CONFIG"
    local exit_code=0
    
    # Run in appropriate mode
    if [ "$MODE" = "format" ]; then
        log "Running SwiftFormat in formatting mode..."
        $swiftformat_cmd "$TARGET" || {
            exit_code=$?
            log "SwiftFormat failed with exit code $exit_code"
            
            if [ "$CONTINUE_ON_ERROR" = true ]; then
                log "Continuing as requested despite errors"
                return 0
            else
                return $exit_code
            fi
        }
    else
        log "Running SwiftFormat in lint-only mode (no changes)..."
        $swiftformat_cmd --lint "$TARGET" || {
            exit_code=$?
            log "SwiftFormat check found issues with exit code $exit_code"
            
            if [ "$CONTINUE_ON_ERROR" = true ]; then
                log "SwiftFormat found issues, but continuing as requested"
                return 0
            else
                log "SwiftFormat found issues, exiting with error code $exit_code"
                return $exit_code
            fi
        }
    fi
    
    log "SwiftFormat completed successfully"
    return 0
}

# Main execution
main() {
    log "Starting SwiftFormat for FriendshipAI Mac App"
    
    # Detect if we're running in CI
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        log "Detected CI environment, enabling 'continue on error' mode"
        CONTINUE_ON_ERROR=true
    fi
    
    # Ensure SwiftFormat is available
    ensure_swiftformat
    
    # Verify the target exists
    verify_target
    
    # Run SwiftFormat
    run_swiftformat || {
        exit_code=$?
        if [ "$CONTINUE_ON_ERROR" = true ]; then
            log "SwiftFormat exited with code $exit_code, but continuing as we're in CI mode"
            exit 0
        else
            log "SwiftFormat exited with code $exit_code"
            exit $exit_code
        fi
    }
    
    log "SwiftFormat process completed"
}

# Run the main function
main