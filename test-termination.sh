#!/bin/bash

# Test script to verify CodeLooper doesn't auto-terminate
# This script launches the app and monitors if it stays running

echo "Building CodeLooper..."
xcodebuild -workspace CodeLooper.xcworkspace -scheme CodeLooper -configuration Debug build

echo "Finding built app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CodeLooper.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built CodeLooper.app"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Kill any existing CodeLooper instances
echo "Killing any existing CodeLooper instances..."
pkill -f CodeLooper || true
sleep 1

# Launch the app
echo "Launching CodeLooper..."
open "$APP_PATH"

# Monitor if it stays running
echo "Monitoring app for 5 seconds..."
for i in {1..5}; do
    sleep 1
    if pgrep -f CodeLooper > /dev/null; then
        echo "[$i/5] CodeLooper is still running ✓"
    else
        echo "[$i/5] CodeLooper has terminated ✗"
        exit 1
    fi
done

echo "Success! CodeLooper stayed running for 5 seconds."
echo "Killing test instance..."
pkill -f CodeLooper || true