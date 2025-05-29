#!/bin/bash

# Appcast.xml Update Script
set -euo pipefail

VERSION="$1"
BUILD_NUMBER="$2"
DMG_PATH="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📡 Updating appcast.xml for version $VERSION"

# Calculate file size and SHA256
DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
DMG_FILENAME=$(basename "$DMG_PATH")

# Get current date in RFC 2822 format
RELEASE_DATE=$(date -R)

# GitHub release URL
GITHUB_USERNAME="${GITHUB_USERNAME:-steipete}"
DOWNLOAD_URL="https://github.com/$GITHUB_USERNAME/CodeLooper/releases/download/v$VERSION/$DMG_FILENAME"

# Create or update appcast.xml
cat > "$PROJECT_ROOT/appcast.xml" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>CodeLooper Updates</title>
        <link>https://github.com/$GITHUB_USERNAME/CodeLooper</link>
        <description>CodeLooper automatic updates feed</description>
        <language>en</language>
        
        <item>
            <title>CodeLooper $VERSION</title>
            <link>$DOWNLOAD_URL</link>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>CodeLooper $VERSION</h2>
                <p>Latest version of CodeLooper with new features and improvements.</p>
                <ul>
                    <li>Enhanced monitoring capabilities</li>
                    <li>Improved intervention strategies</li>
                    <li>Bug fixes and performance improvements</li>
                </ul>
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url="$DOWNLOAD_URL"
                length="$DMG_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="SIGNATURE_PLACEHOLDER"
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "✅ Appcast.xml updated"
echo "⚠️  Remember to sign the DMG with your Sparkle private key and update the signature"
echo "⚠️  Command: sign_update '$DMG_PATH' /path/to/sparkle_private_key"
