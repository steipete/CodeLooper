#!/bin/bash

set -e

echo "🧹 Cleaning build artifacts and cache..."

# Delete Package.resolved if it exists
if [ -f "Package.resolved" ]; then
    echo "Deleting Package.resolved..."
    rm Package.resolved
else
    echo "Package.resolved not found, skipping..."
fi

# Delete Tuist cache directory
TUIST_CACHE_DIRS=(
    "$HOME/.tuist/Cache"
    "$HOME/.cache/tuist"
    "$HOME/Library/Caches/tuist"
)

echo "Cleaning Tuist cache..."
for cache_dir in "${TUIST_CACHE_DIRS[@]}"; do
    if [ -d "$cache_dir" ]; then
        echo "Deleting $cache_dir..."
        rm -rf "$cache_dir"
    fi
done

# Instruct user to manually clear Xcode DerivedData
echo ""
echo "⚠️  Please manually clear Xcode DerivedData from ~/Library/Developer/Xcode/DerivedData/"
echo "   You can do this by running: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo ""

# Run the generate script
echo "🔄 Regenerating Xcode project..."
./scripts/generate-xcproj.sh

echo "✅ Clean and regenerate complete!"