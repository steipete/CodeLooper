#!/bin/bash
set -e

# Script to format and lint Swift code in the codebase
# Now runs both SwiftFormat and SwiftLint for a complete code quality check

echo "Running Swift format and lint on FriendshipAI macOS app..."

# Ensure we're in the right directory
script_dir="$(dirname "$0")"
if ! cd "$script_dir"; then
    echo "Error: Failed to change directory to $script_dir"
    exit 1
fi

# Make sure scripts are executable
chmod +x ./run-swiftlint.sh ./run-swiftformat.sh 2>/dev/null || true

# Verify scripts exist
if [ ! -x "./run-swiftlint.sh" ]; then
    echo "Error: run-swiftlint.sh not found or not executable"
    exit 1
fi

if [ ! -x "./run-swiftformat.sh" ]; then
    echo "Error: run-swiftformat.sh not found or not executable" 
    exit 1
fi

# First run SwiftFormat to format the code
echo "Step 1/2: Running SwiftFormat..."
./run-swiftformat.sh --format
format_exit_code=$?

# Then run SwiftLint with fix mode and continue flag
echo "Step 2/2: Running SwiftLint..."
if [ $# -eq 0 ]; then
    # Default to fix mode with continue flag if no arguments are provided
    ./run-swiftlint.sh --fix --continue
else
    # Pass all arguments to run-swiftlint.sh
    ./run-swiftlint.sh "$@"
fi

# Check exit code
swiftlint_exit_code=$?

# Check overall exit code
if [ $format_exit_code -eq 0 ] && [ $swiftlint_exit_code -eq 0 ]; then
    echo "✅ Swift formatting and linting completed successfully!"
    exit 0
else
    echo "⚠️ Swift format/lint completed with warnings."
    echo "   Some issues may require manual fixes."
    # We still exit with 0 since the --continue flag was used
    exit 0
fi