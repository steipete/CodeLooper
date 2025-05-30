#!/bin/bash

# Script to identify which test file causes the infinite loop

TEST_DIR="Tests"
PROBLEMATIC_FILES=""

echo "Starting test file isolation..."

# Get list of all test files
TEST_FILES=$(find "$TEST_DIR" -name "*Tests.swift" -type f | sort)

# Temporarily move all test files
mkdir -p Tests.disabled
for file in $TEST_FILES; do
    mv "$file" "$file.disabled"
done

# Test each file individually
for file in $TEST_FILES; do
    echo "===================="
    echo "Testing: $file"
    echo "===================="
    
    # Move this file back
    mv "$file.disabled" "$file"
    
    # Try to build and run tests
    if timeout 30 xcodebuild test -workspace CodeLooper.xcworkspace -scheme CodeLooper -destination 'platform=macOS,arch=arm64' -quiet 2>&1 | grep -q "TEST SUCCEEDED"; then
        echo "✅ $file - PASSED"
    else
        echo "❌ $file - FAILED or TIMEOUT"
        PROBLEMATIC_FILES="$PROBLEMATIC_FILES\n$file"
    fi
    
    # Move it back to disabled
    mv "$file" "$file.disabled"
done

# Restore all files
for file in $TEST_FILES; do
    mv "$file.disabled" "$file"
done

echo "===================="
echo "Summary:"
echo "===================="
echo "Problematic files:"
echo -e "$PROBLEMATIC_FILES"