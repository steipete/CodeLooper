#!/bin/bash

# Script to view DocC documentation for CodeLooper modules

set -e

echo "🔨 Building documentation..."

# Build documentation for each module
echo "Building AXorcist documentation..."
xcodebuild docbuild -scheme AXorcist -destination 'platform=macOS' > /dev/null 2>&1

echo "Building DesignSystem documentation..."
xcodebuild docbuild -scheme DesignSystem -destination 'platform=macOS' > /dev/null 2>&1

# Find the generated documentation
DERIVED_DATA_PATH=$(xcodebuild -showBuildSettings -scheme AXorcist | grep BUILD_DIR | head -1 | sed 's/.*= //')
DOCS_PATH="$DERIVED_DATA_PATH/../Products/Debug"

echo "📚 Opening documentation..."

# Open the documentation in Xcode
if [ -d "$DOCS_PATH/AXorcist.doccarchive" ]; then
    echo "Opening AXorcist documentation..."
    open "$DOCS_PATH/AXorcist.doccarchive"
fi

if [ -d "$DOCS_PATH/DesignSystem.doccarchive" ]; then
    echo "Opening DesignSystem documentation..."
    open "$DOCS_PATH/DesignSystem.doccarchive"
fi

echo "✅ Documentation opened in Xcode"
echo ""
echo "📁 Documentation archives are located at:"
echo "   AXorcist: $DOCS_PATH/AXorcist.doccarchive"
echo "   DesignSystem: $DOCS_PATH/DesignSystem.doccarchive"
echo ""
echo "📚 Documentation coverage includes:"
echo "   • AXorcist Framework - Complete API documentation"
echo "   • Element types and accessibility wrappers"
echo "   • Command types and batch operations"
echo "   • Response and error handling"
echo "   • Notification and observer patterns"
echo "   • DesignSystem Framework - UI components and design tokens"
echo "   • CodeLooper Application - Monitoring and supervision"