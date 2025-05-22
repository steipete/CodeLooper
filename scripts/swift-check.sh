#!/bin/bash
set -e

# Script to validate Swift code without making changes
# This performs a full check of Swift code style and formatting in check-only mode

echo "🔍 Running full Swift code check (lint + format)..."

# Ensure we're in the right directory
script_dir="$(dirname "$0")"
if ! cd "$script_dir"; then
    echo "Error: Failed to change directory to $script_dir"
    exit 1
fi

# Make scripts executable
chmod +x ./run-swiftlint.sh ./run-swiftformat.sh 2>/dev/null || true

# Check if scripts exist
if [ ! -x "./run-swiftlint.sh" ]; then
    echo "Error: run-swiftlint.sh not found or not executable"
    exit 1
fi

if [ ! -x "./run-swiftformat.sh" ]; then
    echo "Error: run-swiftformat.sh not found or not executable"
    exit 1
fi

# Run SwiftLint in check mode first
echo "Step 1/2: Running SwiftLint..."
./run-swiftlint.sh --check
swiftlint_exit_code=$?

# Run SwiftFormat in lint-only mode (no changes)
echo "Step 2/2: Running SwiftFormat in check mode..."
./run-swiftformat.sh --check
swiftformat_exit_code=$?

# Check overall exit code
if [ $swiftlint_exit_code -eq 0 ] && [ $swiftformat_exit_code -eq 0 ]; then
    echo "✅ Swift code check passed! No issues found."
    exit 0
else
    echo "❌ Swift code check failed."
    echo "   To fix SwiftLint issues: pnpm lint:swift:fix"
    echo "   To fix formatting issues: pnpm format:swift"
    echo "   To fix all issues: pnpm lint:fix && pnpm format"
    exit 1
fi