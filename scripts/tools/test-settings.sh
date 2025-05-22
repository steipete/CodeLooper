#!/bin/bash

# Test script for the macOS app with new settings UI
# This script builds the app and runs it for testing

# Exit on errors
set -e

echo "========================================="
echo "Building FriendshipAI macOS app for testing"
echo "========================================="

# Move to the mac directory
cd "$(dirname "$0")"

# Build the app using swiftc directly
echo "Building app..."
swift build --product FriendshipAI

# Check if the build succeeded
if [ $? -eq 0 ]; then
  echo "Build successful!"
  
  # Kill any existing instances
  echo "Killing any existing instances..."
  pkill -f FriendshipAI || true
  
  # Wait a moment for the app to close
  sleep 1
  
  # Run the app
  echo "Running app for testing..."
  .build/debug/FriendshipAI &
  
  echo "App launched. You can test the settings menu now."
  echo "Press Ctrl+C when finished testing."
  
  # Wait for user to press Ctrl+C
  trap "echo 'Stopping test...'; pkill -f FriendshipAI || true" INT
  wait
else
  echo "Build failed."
  exit 1
fi