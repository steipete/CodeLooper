#!/bin/bash

# Script to generate app icons for macOS app
# Requires source logo.png - should be at least 1024x1024 for best quality

set -e

# Directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
SOURCE_LOGO="$PROJECT_ROOT/Resources/logo.png"
OUTPUT_DIR="$PROJECT_ROOT/CodeLooper/Assets.xcassets/AppIcon.appiconset"

# Check if source logo exists
if [ ! -f "$SOURCE_LOGO" ]; then
    echo "Error: Source logo not found at $SOURCE_LOGO"
    exit 1
fi

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory not found at $OUTPUT_DIR"
    exit 1
fi

# Create icons in all required sizes
echo "Generating app icons from $SOURCE_LOGO..."

# Array of sizes needed
SIZES=(16 32 64 128 256 512 1024)

for size in "${SIZES[@]}"; do
    output_file="$OUTPUT_DIR/logo_$size.png"
    echo "Creating $size x $size icon..."
    sips -z $size $size "$SOURCE_LOGO" --out "$output_file"
done

echo "App icons generated successfully in $OUTPUT_DIR"
echo "You may need to refresh the Xcode project for changes to appear"