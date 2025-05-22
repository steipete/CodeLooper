#!/bin/bash

# Script to copy symbol icons to the app bundle's Resources directory

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="${SCRIPT_DIR}/Resources"
OUTPUT_DIR="${SCRIPT_DIR}/.build/debug/CodeLooper-Mac_CodeLooper-Mac.bundle/Contents/Resources"

# Ensure Resources directory exists
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Copy icons from Resources to the app bundle
echo "Copying symbol icons to app bundle..."

# Copy the symbol icons
cp "${RESOURCES_DIR}/symbol.png" "${OUTPUT_DIR}/symbol.png" 2>/dev/null || true
cp "${RESOURCES_DIR}/symbol-dark.png" "${OUTPUT_DIR}/symbol-dark.png" 2>/dev/null || true
cp "${RESOURCES_DIR}/symbol-light.png" "${OUTPUT_DIR}/symbol-light.png" 2>/dev/null || true

# Verify the files are in place
if [ -f "${OUTPUT_DIR}/symbol.png" ]; then
  echo "✅ symbol.png copied to app bundle."
else
  echo "❌ Failed to copy symbol.png to app bundle."
fi

if [ -f "${OUTPUT_DIR}/symbol-dark.png" ]; then
  echo "✅ symbol-dark.png copied to app bundle."
else
  echo "❌ Failed to copy symbol-dark.png to app bundle."
fi

if [ -f "${OUTPUT_DIR}/symbol-light.png" ]; then
  echo "✅ symbol-light.png copied to app bundle."
else
  echo "❌ Failed to copy symbol-light.png to app bundle."
fi

echo "Done copying symbol icons."